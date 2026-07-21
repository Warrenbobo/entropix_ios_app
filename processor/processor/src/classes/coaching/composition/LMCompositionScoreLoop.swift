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

    private var frameProvider: (() -> UIImage?)?
    private var referenceProvider: (() -> UIImage?)?
    private var isPausedProvider: (() -> Bool)?
    private var cameraReadyProvider: (() -> Bool)?
    private var intervalProvider: (() -> TimeInterval)?

    private(set) var latestScore: LMCompositionScore?

    static let defaultInterval: TimeInterval = 1.0
    static let llmStreamingInterval: TimeInterval = 2.0

    init(analyzer: LMCompositionAnalyzer = .shared) {
        self.analyzer = analyzer
    }

    /// Starts the loop; the first scoring run begins immediately, then waits `intervalProvider` after each publish.
    func start(
        frameProvider: @escaping () -> UIImage?,
        referenceProvider: @escaping () -> UIImage?,
        isPausedProvider: @escaping () -> Bool = { false },
        cameraReadyProvider: @escaping () -> Bool = { true },
        intervalProvider: @escaping () -> TimeInterval = { LMCompositionScoreLoop.defaultInterval }
    ) {
        stop()
        self.frameProvider = frameProvider
        self.referenceProvider = referenceProvider
        self.isPausedProvider = isPausedProvider
        self.cameraReadyProvider = cameraReadyProvider
        self.intervalProvider = intervalProvider
        scheduleNextTick(after: 0)
    }

    /// Stops the scoring loop and cancels any pending tick.
    func stop() {
        scheduledWork?.cancel()
        scheduledWork = nil
        frameProvider = nil
        referenceProvider = nil
        isPausedProvider = nil
        cameraReadyProvider = nil
        intervalProvider = nil
        latestScore = nil
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.compositionScoreLoop(self, didUpdate: nil)
        }
    }

    private func scheduleNextTick(after delay: TimeInterval) {
        scheduledWork?.cancel()
        guard frameProvider != nil else { return }
        let work = DispatchWorkItem { [weak self] in
            self?.tick()
        }
        scheduledWork = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func tick() {
        guard let referenceProvider, let frameProvider else { return }

        guard let reference = referenceProvider() else {
            publishScore(nil)
            return
        }
        guard cameraReadyProvider?() ?? true else {
            publishScore(nil)
            return
        }
        if isPausedProvider?() ?? false {
            scheduleNextTick(after: currentInterval())
            return
        }
        if isScoring {
            scheduleNextTick(after: 0.1)
            return
        }

        guard let camFrame = frameProvider() else {
            scheduleNextTick(after: currentInterval())
            return
        }

        scoringLock.lock()
        guard !isScoring else {
            scoringLock.unlock()
            scheduleNextTick(after: 0.1)
            return
        }
        isScoring = true
        scoringLock.unlock()

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
        scoringLock.unlock()

        publishScore(scored)
    }

    private func publishScore(_ score: LMCompositionScore?) {
        latestScore = score
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.compositionScoreLoop(self, didUpdate: score)
        }
        scheduleNextTick(after: currentInterval())
    }

    private func currentInterval() -> TimeInterval {
        intervalProvider?() ?? Self.defaultInterval
    }
}
