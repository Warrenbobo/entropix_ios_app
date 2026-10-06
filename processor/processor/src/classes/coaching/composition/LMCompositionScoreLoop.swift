//
//  LMCompositionScoreLoop.swift
//  processor
//
//  Auto-refresh loop: capture preview frame, score against reference, emit result.
//

import UIKit

/// Callbacks for live composition score updates.
protocol LMCompositionScoreLoopDelegate: AnyObject {
    func compositionScoreLoop(_ loop: LMCompositionScoreLoop, didUpdate score: LMCompositionScore?)
}

/// Auto-refresh loop: scores ref/cam after each publish, then waits `intervalProvider` before the next run.
final class LMCompositionScoreLoop: @unchecked Sendable {
    weak var delegate: LMCompositionScoreLoopDelegate?

    private let analyzer: LMCompositionAnalyzer
    private let queue = DispatchQueue(label: "com.framaist.compositionScoreLoop", qos: .userInitiated)
    private var scheduledWork: DispatchWorkItem?
    private let scoringLock = NSLock()
    private var isScoring = false
    /// `true` while the loop should keep scheduling ticks.
    private var isActive = false
    /// Bumped on hard `stop()` so in-flight `analyze` results are discarded.
    private var generation: UInt64 = 0

    private var frameProvider: (() -> UIImage?)?
    private var referenceProvider: (() -> UIImage?)?
    private var isPausedProvider: (() -> Bool)?
    private var cameraReadyProvider: (() -> Bool)?
    private var intervalProvider: (() -> TimeInterval)?

    private(set) var latestScore: LMCompositionScore?

    static let defaultInterval: TimeInterval = 1.0

    /// Whether the loop is active (scheduling ticks). Safe to call `start` again while active.
    var isRunning: Bool {
        scoringLock.lock()
        defer { scoringLock.unlock() }
        return isActive
    }

    init(analyzer: LMCompositionAnalyzer = .shared) {
        self.analyzer = analyzer
    }

    /**
     Starts or refreshes the loop without tearing down an already-running schedule.

     Calling `start` again while active only updates providers — it does **not** bump
     `generation` or cancel the in-flight tick (avoids discarding every live score).
     */
    func start(
        frameProvider: @escaping () -> UIImage?,
        referenceProvider: @escaping () -> UIImage?,
        isPausedProvider: @escaping () -> Bool = { false },
        cameraReadyProvider: @escaping () -> Bool = { true },
        intervalProvider: @escaping () -> TimeInterval = { LMCompositionScoreLoop.defaultInterval }
    ) {
        scoringLock.lock()
        let alreadyActive = isActive
        self.frameProvider = frameProvider
        self.referenceProvider = referenceProvider
        self.isPausedProvider = isPausedProvider
        self.cameraReadyProvider = cameraReadyProvider
        self.intervalProvider = intervalProvider
        isActive = true
        scoringLock.unlock()

        if alreadyActive {
            return
        }
        scheduleNextTick(after: 0)
    }

    /**
     Stops the scoring loop and cancels any pending tick.

     In-flight `analyze` may still finish on the score queue, but its result is
     discarded via `generation` so UI / donut are not updated after leave.

     - Parameter clearDisplayedScore: When `true` (leave / hard stop), clears
       `latestScore` and publishes `nil` so the donut shows `--`. When `false`,
       keeps the last score for sticky display.
     */
    func stop(clearDisplayedScore: Bool = true) {
        scoringLock.lock()
        isActive = false
        generation &+= 1
        scoringLock.unlock()

        scheduledWork?.cancel()
        scheduledWork = nil
        frameProvider = nil
        referenceProvider = nil
        isPausedProvider = nil
        cameraReadyProvider = nil
        intervalProvider = nil

        scoringLock.lock()
        isScoring = false
        scoringLock.unlock()

        guard clearDisplayedScore else { return }

        latestScore = nil
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.compositionScoreLoop(self, didUpdate: nil)
        }
    }

    private func scheduleNextTick(after delay: TimeInterval) {
        scheduledWork?.cancel()
        scoringLock.lock()
        let active = isActive
        scoringLock.unlock()
        guard active else { return }

        let work = DispatchWorkItem { [weak self] in
            self?.tick()
        }
        scheduledWork = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func tick() {
        scoringLock.lock()
        let active = isActive
        let tickGeneration = generation
        let referenceProvider = self.referenceProvider
        let frameProvider = self.frameProvider
        scoringLock.unlock()

        guard active else { return }

        // Providers missing while still active — retry (never drop the schedule).
        guard let referenceProvider, let frameProvider else {
            scheduleNextTick(after: currentInterval(), generation: tickGeneration)
            return
        }

        guard let reference = referenceProvider() else {
            scheduleNextTick(after: currentInterval(), generation: tickGeneration)
            return
        }
        guard cameraReadyProvider?() ?? true else {
            scheduleNextTick(after: currentInterval(), generation: tickGeneration)
            return
        }
        if isPausedProvider?() ?? false {
            // Sticky: keep last published score while paused (Tips / background).
            scheduleNextTick(after: currentInterval(), generation: tickGeneration)
            return
        }

        scoringLock.lock()
        if isScoring {
            scoringLock.unlock()
            scheduleNextTick(after: 0.1, generation: tickGeneration)
            return
        }
        isScoring = true
        scoringLock.unlock()

        guard let camFrame = frameProvider() else {
            scoringLock.lock()
            isScoring = false
            scoringLock.unlock()
            scheduleNextTick(after: currentInterval(), generation: tickGeneration)
            return
        }

        let startMs = Int64(Date().timeIntervalSince1970 * 1000)
        let result = analyzer.analyze(ref: reference, cam: camFrame)
        let wallMs = Int64(Date().timeIntervalSince1970 * 1000) - startMs
        let scored = LMCompositionScore(
            overallScore: result.overallScore,
            globalStructure: result.globalStructure,
            geometric: result.geometric,
            humanScene: result.humanScene,
            lines: result.lines,
            rule: result.rule,
            subjectCenter: result.subjectCenter,
            negativeSpace: result.negativeSpace,
            humanPos: result.humanPos,
            humanScale: result.humanScale,
            humanDepth: result.humanDepth,
            elapsedMs: wallMs
        )

        scoringLock.lock()
        isScoring = false
        let stillCurrent = isActive && (generation == tickGeneration)
        scoringLock.unlock()

        guard stillCurrent else {
            LMLogger.log("ScoreLoop discarded stale analyze generation=\(tickGeneration)")
            // Loop may still be active under a newer generation — that generation owns scheduling.
            return
        }

        publishScore(scored, generation: tickGeneration)
    }

    private func publishScore(_ score: LMCompositionScore?, generation tickGeneration: UInt64) {
        scoringLock.lock()
        let stillCurrent = isActive && (generation == tickGeneration)
        scoringLock.unlock()
        guard stillCurrent else { return }

        latestScore = score
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scoringLock.lock()
            let current = self.isActive && self.generation == tickGeneration
            self.scoringLock.unlock()
            guard current else { return }
            self.delegate?.compositionScoreLoop(self, didUpdate: score)
        }
        scheduleNextTick(after: currentInterval(), generation: tickGeneration)
    }

    private func scheduleNextTick(after delay: TimeInterval, generation tickGeneration: UInt64) {
        scoringLock.lock()
        let stillCurrent = isActive && (generation == tickGeneration)
        scoringLock.unlock()
        guard stillCurrent else { return }
        scheduleNextTick(after: delay)
    }

    private func currentInterval() -> TimeInterval {
        intervalProvider?() ?? Self.defaultInterval
    }
}
