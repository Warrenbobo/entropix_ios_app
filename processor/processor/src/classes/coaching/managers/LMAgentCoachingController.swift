//
//  LMAgentCoachingController.swift
//  processor
//
//  Coordinates composition score loop and agentic coaching loop.
//

import UIKit

/// Coordinates live composition scoring and agentic coaching for the camera page.
final class LMAgentCoachingController: NSObject, @unchecked Sendable {
    private let analyzer: LMCompositionAnalyzer
    private let policy: LMCoachingPolicyConfig
    private let scoreLoop: LMCompositionScoreLoop
    private let agentLoop: LMAgenticCoachingLoop
    private let actionExecutor: LMActionExecutor
    private let skipReevaluationEvaluator: LMSkipReevaluationEvaluator

    private var referenceImage: UIImage?
    private var referenceBbox: CGRect?
    private var lineArtReady = false
    private var latestCachedScore: LMCachedCompositionScoreSnapshot?
    private var isPaused = false
    private var cameraReady = true
    private var lastSemanticAction = ""
    private(set) var coachingIsFinal = false
    private let streamingLock = NSLock()
    private var isLlmStreaming = false

    weak var uiDelegate: LMAgentCoachingUIDelegate? {
        didSet { actionExecutor.updateDelegate(uiDelegate) }
    }

    var agentState: LMAgentState { agentLoop.currentState }
    var latestScore: LMCompositionScore? { scoreLoop.latestScore }
    var coachingSession: LMCoachingSession { agentLoop.coachingSession }
    var skipEnabled: Bool { policy.skipEnabled }

    init(
        analyzer: LMCompositionAnalyzer = .shared,
        policy: LMCoachingPolicyConfig = .default,
        uiDelegate: LMAgentCoachingUIDelegate? = nil
    ) {
        self.analyzer = analyzer
        self.policy = policy
        self.scoreLoop = LMCompositionScoreLoop(analyzer: analyzer)
        self.agentLoop = LMAgenticCoachingLoop(analyzer: analyzer, policy: policy)
        let toolRouter = LMExecutionToolRouter(policy: policy)
        self.actionExecutor = LMActionExecutor(delegate: uiDelegate, toolRouter: toolRouter)
        self.skipReevaluationEvaluator = LMSkipReevaluationEvaluator(policy: policy)
        super.init()
        self.uiDelegate = uiDelegate
        scoreLoop.delegate = self
    }

    /// Sets the reference image without running Core ML warmup (Stage B owns warmup).
    func setReferenceImage(_ image: UIImage?, bbox: CGRect? = nil) {
        referenceImage = image
        referenceBbox = bbox
        if image == nil {
            analyzer.clearReferenceCache()
            agentLoop.resetWindow()
        }
    }

    func setLineArtReady(_ ready: Bool) {
        lineArtReady = ready
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    func setCameraReady(_ ready: Bool) {
        cameraReady = ready
    }

    /// Starts the composition score loop (1s between publishes; 2s while LLM is streaming).
    func startScoreLoop(frameProvider: @escaping () -> UIImage?) {
        scoreLoop.start(
            frameProvider: frameProvider,
            referenceProvider: { [weak self] in self?.referenceImage },
            isPausedProvider: { [weak self] in self?.isPaused ?? false },
            cameraReadyProvider: { [weak self] in self?.cameraReady ?? false },
            intervalProvider: { [weak self] in
                guard let self else { return LMCompositionScoreLoop.defaultInterval }
                return self.isLlmStreamingActive
                    ? LMCompositionScoreLoop.llmStreamingInterval
                    : LMCompositionScoreLoop.defaultInterval
            }
        )
    }

    /// Releases analyzer, human-perception, and controller-held composition resources.
    /// Heavy Core ML unload runs off the main thread so leave/back UI stays responsive.
    func releaseCompositionResources() {
        stopCoachingForLeave()
        unloadCompositionModelsAsync()
    }

    /**
     Light leave path: stop loops / clear controller refs on the calling thread.

     Does **not** clear analyzer cache or unload Core ML — those can block on an
     in-flight `analyze` lock. Call `unloadCompositionModelsAsync()` after UI returns.
     */
    func stopCoachingForLeave() {
        setLlmStreaming(false)
        stopAll()
        setReferenceImage(nil)
        referenceBbox = nil
        lineArtReady = false
        latestCachedScore = nil
    }

    /**
     Clears caches and unloads on-device composition models on a background queue.

     `clearReferenceCache()` waits for any in-flight analyze off the main thread.
     Provider `unload()` methods are lock-guarded.
     */
    func unloadCompositionModelsAsync() {
        DispatchQueue.global(qos: .utility).async {
            LMHumanUnderstandingService.shared.invalidateReference()
            LMHumanUnderstandingService.shared.invalidateLive()
            LMCompositionAnalyzer.shared.clearReferenceCache()
            LMEVA02ModelProvider.unload()
            LMDepthEstimationService.shared.unload()
            LMPidinetModelProvider.shared.unload()
            LMU2NetpModelProvider.shared.unload()
            LMCompositionModelPreloader.shared.markUnloaded()
            LMLogger.log("Composition models unloaded off main thread")
        }
    }

    private var isLlmStreamingActive: Bool {
        streamingLock.lock()
        defer { streamingLock.unlock() }
        return isLlmStreaming
    }

    private func setLlmStreaming(_ active: Bool) {
        streamingLock.lock()
        isLlmStreaming = active
        streamingLock.unlock()
    }

    /// Stops the composition score loop.
    func stopScoreLoop() {
        scoreLoop.stop()
        latestCachedScore = nil
    }

    /// Runs one agent coaching round (typically on shutter instruct tap).
    func runAgentRound(frameProvider: @escaping () -> UIImage?) {
        markCoachingFinal(false)
        setLlmStreaming(false)
        let callbacks = makeLoopCallbacks()

        agentLoop.runOnce(
            frameProvider: frameProvider,
            referenceProvider: { [weak self] in self?.referenceImage },
            referenceBboxProvider: { [weak self] in self?.referenceBbox },
            lineArtReadyProvider: { [weak self] in self?.lineArtReady ?? false },
            recentScoreProvider: { [weak self] in self?.latestCachedScore },
            callbacks: callbacks
        )
    }

    /// Marks whether the current coaching instruction is final (eligible for Skip).
    func markCoachingFinal(_ isFinal: Bool) {
        coachingIsFinal = isFinal
    }

    /// Handles user skip of the current coaching suggestion.
    func onSkipSuggestion(currentInstruction: String?) {
        guard policy.skipEnabled else { return }
        guard let scores = latestCachedScore?.score ?? latestScore else { return }

        let action = lastSemanticAction.isEmpty ? (currentInstruction ?? "") : lastSemanticAction
        guard !action.isEmpty, !action.contains("finish") else { return }

        let category = LMActionClassifier.categoryOf(action)
        coachingSession.skipCategory(category)
        coachingSession.push(LMRoundRecord(
            round: max(agentLoop.currentState == .finished ? 1 : 1, 1),
            action: action,
            scoreBefore: scores.overallScore,
            scoreAfter: scores.overallScore,
            timestamp: Int64(Date().timeIntervalSince1970 * 1000),
            isSkipped: true
        ))

        switch skipReevaluationEvaluator.evaluate(scores: scores, skippedCategory: category) {
        case .finish(_, let cause):
            dispatchUI { [weak self] in
                self?.uiDelegate?.agentCoaching(didSetExecutionTool: .none, instruction: nil)
            }
            let systemState = LMExecutionSystemState(
                referenceBbox: referenceBbox,
                lineArtReady: lineArtReady
            )
            Task {
                await self.agentLoop.deliverFinish(
                    cause: cause,
                    scores: scores,
                    callbacks: self.makeLoopCallbacks(),
                    systemState: systemState
                )
            }
        case .continuePlanning:
            markCoachingFinal(true)
            let skipMessage = String(
                format: LMText.camera.agentSkipRememberedFormat,
                category.displayName
            )
            dispatchUI { [weak self] in
                self?.uiDelegate?.agentCoaching(
                    didUpdateAction: skipMessage,
                    isFinal: true
                )
            }
        }
    }

    /// Skips a suggestion category for the current session.
    func skipCategory(_ category: LMSuggestionCategory) {
        coachingSession.skipCategory(category)
    }

    /// Ensures coaching HUD updates always run on the main thread.
    private func dispatchUI(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    private func makeLoopCallbacks() -> LMAgenticLoopCallbacks {
        LMAgenticLoopCallbacks(
            onState: { [weak self] state in
                LMLogger.log("Agent state: \(state)")
                self?.dispatchUI {
                    self?.uiDelegate?.agentCoaching(didUpdateAgentState: state)
                }
            },
            onRound: { round in
                LMLogger.log("Agent round: \(round)")
            },
            onStreamingReasoning: { [weak self] text in
                self?.setLlmStreaming(true)
                self?.markCoachingFinal(false)
                self?.dispatchUI {
                    self?.uiDelegate?.agentCoaching(didUpdateReasoning: text)
                }
            },
            onStreamingAction: { [weak self] preview in
                let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                self?.setLlmStreaming(true)
                self?.markCoachingFinal(false)
                self?.dispatchUI {
                    self?.uiDelegate?.agentCoaching(didUpdateAction: trimmed, isFinal: false)
                }
            },
            onFinalText: { [weak self] text in
                self?.setLlmStreaming(false)
                self?.markCoachingFinal(true)
                let display = LMActionExtractor.extractDisplayText(text)
                self?.dispatchUI {
                    self?.uiDelegate?.agentCoaching(didUpdateAction: display, isFinal: true)
                }
            },
            onFinalAction: { action in
                LMLogger.log("Agent final action: \(action)")
            },
            onError: { [weak self] message in
                self?.setLlmStreaming(false)
                LMLogger.log("❌ Agent error: \(message)")
                self?.markCoachingFinal(false)
                self?.dispatchUI {
                    self?.uiDelegate?.agentCoaching(didUpdateAction: message, isFinal: false)
                    self?.uiDelegate?.agentCoaching(didUpdateAgentState: .error)
                }
            },
            onScore: { [weak self] score in
                self?.latestCachedScore = LMCachedCompositionScoreSnapshot(
                    score: score,
                    analyzedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
                )
            },
            onScoreModuleDone: { [weak self] phase in
                self?.dispatchUI {
                    self?.uiDelegate?.agentCoaching(didCompleteScoreModule: phase)
                }
            },
            onEnterThinking: { [weak self] in
                self?.dispatchUI {
                    self?.uiDelegate?.agentCoachingDidEnterThinking()
                }
            },
            onExecuteAction: { [weak self] semanticAction, scores, systemState, finishCause in
                guard let self else { return }
                self.setLlmStreaming(false)
                self.lastSemanticAction = semanticAction
                self.markCoachingFinal(true)
                self.actionExecutor.execute(
                    semanticAction: semanticAction,
                    scores: scores,
                    session: self.agentLoop.coachingSession,
                    systemState: systemState,
                    finishCause: finishCause
                )
            },
            onFinishCause: { cause in
                LMLogger.log("Agent finish cause: \(cause)")
            }
        )
    }

    /// Resets agent session for a new reference window.
    func resetAgentWindow() {
        agentLoop.resetWindow()
        lastSemanticAction = ""
        coachingIsFinal = false
    }

    /// Soft-resets agent session while keeping reference cache.
    func softResetAgentSession() {
        agentLoop.softResetSession()
        lastSemanticAction = ""
        coachingIsFinal = false
    }

    /// Stops all coaching activity.
    func stopAll() {
        setLlmStreaming(false)
        stopScoreLoop()
        agentLoop.stop()
    }
}

extension LMAgentCoachingController: LMCompositionScoreLoopDelegate {
    func compositionScoreLoop(_ loop: LMCompositionScoreLoop, didUpdate score: LMCompositionScore?) {
        if let score {
            latestCachedScore = LMCachedCompositionScoreSnapshot(
                score: score,
                analyzedAtMs: Int64(Date().timeIntervalSince1970 * 1000)
            )
        }
        DispatchQueue.main.async { [weak self] in
            guard let delegate = self?.uiDelegate as? LMCameraPage else { return }
            delegate.scoreDonutOverlayView?.apply(score: score)
        }
        LMAgentRequestLogStore.shared.updateLatestScore(score)
    }
}
