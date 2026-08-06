//
//  LMAgenticCoachingLoop.swift
//  processor
//
//  Manual-step agentic coaching: one perceive→plan→decide round per runOnce invocation.
//

import UIKit

/// UI and score callbacks for agentic coaching loop.
struct LMAgenticLoopCallbacks {
    var onState: (@Sendable (LMAgentState) -> Void)?
    var onRound: (@Sendable (Int) -> Void)?
    var onStreamingReasoning: (@Sendable (String) -> Void)?
    var onStreamingAction: (@Sendable (String) -> Void)?
    var onFinalText: (@Sendable (String) -> Void)?
    var onFinalAction: (@Sendable (String) -> Void)?
    var onError: (@Sendable (String) -> Void)?
    var onScore: (@Sendable (LMCompositionScore) -> Void)?
    var onExecuteAction: (
        @Sendable (String, LMCompositionScore, LMExecutionSystemState, LMFinishCause?) -> Void
    )?
    var onFinishCause: (@Sendable (LMFinishCause) -> Void)?
}

/// Result of one agentic LLM coaching round.
struct LMAgenticRunResult: Sendable {
    let httpCode: Int
    let finalAction: String
    let rawOutput: String
    let reasoningFull: String
    let answerFull: String
    let finishCause: LMFinishCause?
    let errorBody: String?
    let ttfbMs: Int64
}

/// Manual-step agentic coaching loop.
final class LMAgenticCoachingLoop: @unchecked Sendable {
    private let analyzer: LMCompositionAnalyzer
    private let configProvider: () -> LMAppConfig
    private let policy: LMCoachingPolicyConfig
    private let chatClient: LMDashScopeChatClient
    private let session: LMCoachingSession
    private let promptBuilder: LMPromptBuilder
    private let arbiter: LMArbiter
    private let queue = DispatchQueue(label: "com.framaist.agenticCoachingLoop", qos: .userInitiated)

    private var roundTask: Task<Void, Never>?
    private var roundCounter = 0
    private var scoreBeforeRound: Float = 0
    private var state: LMAgentState = .idle

    var coachingSession: LMCoachingSession { session }
    var currentState: LMAgentState { state }

    init(
        analyzer: LMCompositionAnalyzer = .shared,
        configProvider: @escaping () -> LMAppConfig = { LMConfigRepository.shared.get() },
        policy: LMCoachingPolicyConfig = .default,
        chatClient: LMDashScopeChatClient = LMDashScopeChatClient()
    ) {
        self.analyzer = analyzer
        self.configProvider = configProvider
        self.policy = policy
        self.chatClient = chatClient
        self.session = LMCoachingSession(maxSize: policy.maxHistorySize, policy: policy)
        self.promptBuilder = LMPromptBuilder(policy: policy)
        self.arbiter = LMArbiter(policy: policy)
    }

    /// Resets session memory, planning gate, and round counter for a new reference image window.
    func resetWindow() {
        stop()
        session.reset()
        promptBuilder.resetGate()
        roundCounter = 0
        scoreBeforeRound = 0
        state = .idle
    }

    /// Soft-resets instruct session for agent re-enable on the same reference.
    func softResetSession() {
        stop()
        session.reset()
        promptBuilder.resetGate()
        roundCounter = 0
        scoreBeforeRound = 0
        state = .idle
    }

    /// Runs a single agentic round (user-triggered via shutter instruct action).
    func runOnce(
        frameProvider: @escaping @Sendable () -> UIImage?,
        referenceProvider: @escaping @Sendable () -> UIImage?,
        referenceBboxProvider: @escaping @Sendable () -> CGRect?,
        lineArtReadyProvider: @escaping @Sendable () -> Bool,
        recentScoreProvider: @escaping @Sendable () -> LMCachedCompositionScoreSnapshot?,
        callbacks: LMAgenticLoopCallbacks
    ) {
        guard roundTask == nil else { return }
        guard state != .finished else { return }

        roundTask = Task { [weak self] in
            guard let self else { return }
            await self.setState(.running, callbacks: callbacks)
            do {
                try await self.runSingleRound(
                    frameProvider: frameProvider,
                    referenceProvider: referenceProvider,
                    referenceBboxProvider: referenceBboxProvider,
                    lineArtReadyProvider: lineArtReadyProvider,
                    recentScoreProvider: recentScoreProvider,
                    callbacks: callbacks
                )
            } catch {
                await self.setState(.error, callbacks: callbacks)
                callbacks.onError?(error.localizedDescription)
            }
            self.roundTask = nil
            if self.state == .running {
                await self.setState(.idle, callbacks: callbacks)
            }
        }
    }

    /// Delivers finish without LLM (planning gate or skip re-evaluation).
    func deliverFinish(
        cause: LMFinishCause,
        scores: LMCompositionScore,
        callbacks: LMAgenticLoopCallbacks,
        systemState: LMExecutionSystemState,
        llmMessage: String? = nil
    ) async {
        let historyMessage = llmMessage ?? LMFinishCopy.display(cause)
        let action = #"finish(message="\#(historyMessage)")"#
        let display = LMFinishCopy.display(cause)
        await MainActor.run {
            callbacks.onFinishCause?(cause)
            callbacks.onFinalText?(display)
            callbacks.onExecuteAction?(action, scores, systemState, cause)
        }
        await setState(.finished, callbacks: callbacks)
        session.push(LMRoundRecord(
            round: max(roundCounter, 1),
            action: action,
            scoreBefore: scoreBeforeRound,
            scoreAfter: scores.overallScore,
            timestamp: currentTimestampMs(),
            isSkipped: false
        ))
        scoreBeforeRound = scores.overallScore
    }

    /// Cancels an in-flight round.
    func stop() {
        roundTask?.cancel()
        roundTask = nil
        if state == .running {
            state = .idle
        }
    }

    private func runSingleRound(
        frameProvider: @escaping @Sendable () -> UIImage?,
        referenceProvider: @escaping @Sendable () -> UIImage?,
        referenceBboxProvider: @escaping @Sendable () -> CGRect?,
        lineArtReadyProvider: @escaping @Sendable () -> Bool,
        recentScoreProvider: @escaping @Sendable () -> LMCachedCompositionScoreSnapshot?,
        callbacks: LMAgenticLoopCallbacks
    ) async throws {
        guard let reference = referenceProvider() else {
            callbacks.onError?("Reference image is not ready.")
            return
        }
        guard let camFrame = frameProvider() else {
            callbacks.onError?("Could not capture camera frame.")
            return
        }

        roundCounter += 1
        callbacks.onRound?(roundCounter)

        let nowMs = currentTimestampMs()
        let cachedScore = recentScoreProvider()
        let reuseScore = cachedScore.map {
            nowMs - $0.analyzedAtMs <= policy.instructReuseScoreMaxAgeMs
        } ?? false

        let scores: LMCompositionScore
        if reuseScore, let cachedScore {
            LMLogger.log("AGENT_SCORE_REUSE ageMs=\(nowMs - cachedScore.analyzedAtMs)")
            scores = cachedScore.score
        } else {
            let fresh = await Task.detached { [analyzer] in
                analyzer.analyze(ref: reference, cam: camFrame)
            }.value
            callbacks.onScore?(fresh)
            scores = fresh
        }

        let systemState = LMExecutionSystemState(
            referenceBbox: referenceBboxProvider(),
            lineArtReady: lineArtReadyProvider()
        )

        if promptBuilder.shouldSkipLlm(scores: scores) {
            LMLogger.log("AGENT_GATE_FINISH overall=\(scores.overallScore)")
            await deliverFinish(cause: .scoreImplied, scores: scores, callbacks: callbacks, systemState: systemState)
            return
        }

        let forbidden = LMForbiddenActionsBuilder.build(scores: scores, policy: policy, session: session)
        let userPrompt = promptBuilder.buildUserPrompt(
            scores: scores,
            session: session,
            forbiddenActions: forbidden
        )

        let baseConfig = configProvider()
        let runConfig = baseConfig.withSystemPrompt(buildEffectiveSystemPrompt(base: baseConfig.systemPrompt, session: session))

        LMAgentRequestLogRecorder.recordInstructRequest(
            round: roundCounter,
            orientation: LMDeviceOrientationManager.shared.currentOrientation,
            reference: reference,
            cameraView: camFrame,
            config: runConfig,
            userPrompt: userPrompt,
            compositionScore: scores
        )

        let result = try await runLlmRound(
            config: runConfig,
            reference: reference,
            cameraView: camFrame,
            userPrompt: userPrompt,
            currentScores: scores,
            callbacks: callbacks
        )

        guard (200...299).contains(result.httpCode) else {
            LMAgentRequestLogRecorder.recordInstructResponse(round: roundCounter, result: result)
            await setState(.error, callbacks: callbacks)
            return
        }

        LMAgentRequestLogRecorder.recordInstructResponse(round: roundCounter, result: result)

        await MainActor.run {
            if let finishCause = result.finishCause, result.finalAction.contains("finish") {
                callbacks.onFinishCause?(finishCause)
            }
            callbacks.onExecuteAction?(result.finalAction, scores, systemState, result.finishCause)
            callbacks.onFinalAction?(result.finalAction)
        }

        session.push(LMRoundRecord(
            round: roundCounter,
            action: result.finalAction,
            scoreBefore: scoreBeforeRound,
            scoreAfter: scores.overallScore,
            timestamp: currentTimestampMs(),
            isSkipped: false
        ))
        scoreBeforeRound = scores.overallScore

        if result.finalAction.contains("finish") {
            await setState(.finished, callbacks: callbacks)
        }
    }

    private func runLlmRound(
        config: LMAppConfig,
        reference: UIImage,
        cameraView: UIImage,
        userPrompt: String,
        currentScores: LMCompositionScore,
        callbacks: LMAgenticLoopCallbacks
    ) async throws -> LMAgenticRunResult {
        guard !config.apiKey.isEmpty else {
            callbacks.onError?("Set AppConfigs.AgentLLM.apiKey")
            return LMAgenticRunResult(
                httpCode: 0, finalAction: "", rawOutput: "", reasoningFull: "", answerFull: "",
                finishCause: nil, errorBody: "Missing api_key", ttfbMs: 0
            )
        }

        let refDataUrl = imageDataUrl(reference, config: config)
        let camDataUrl = imageDataUrl(cameraView, config: config)
        let requestBody: Data
        do {
            requestBody = try LMChatRequestBuilder.buildJSONData(
                config: config,
                referenceDataUrl: refDataUrl,
                cameraViewDataUrl: camDataUrl,
                userPrompt: userPrompt
            )
        } catch {
            callbacks.onError?("Failed to encode LLM request: \(error.localizedDescription)")
            return LMAgenticRunResult(
                httpCode: 0, finalAction: "", rawOutput: "", reasoningFull: "", answerFull: "",
                finishCause: nil, errorBody: "Request encode failed", ttfbMs: 0
            )
        }

        var reasoningAccumulator = ""
        var answerAccumulator = ""
        let uiThrottler = LMStreamingUiThrottler()

        let streamResult = await chatClient.streamChatCompletion(
            baseUrl: config.baseUrl,
            apiKey: config.apiKey,
            requestBody: requestBody
        ) { delta in
            if let reasoning = delta.reasoningContent {
                reasoningAccumulator += reasoning
            }
            if let content = delta.content {
                answerAccumulator += content
            }
            let actionPreview = LMActionExtractor.extractDisplayTextPartial(answerAccumulator)
            uiThrottler.onDelta(
                reasoningText: reasoningAccumulator,
                actionPreview: actionPreview,
                onReasoning: { callbacks.onStreamingReasoning?($0) },
                onAction: { callbacks.onStreamingAction?($0) }
            )
        }

        uiThrottler.flush(
            reasoningText: reasoningAccumulator,
            actionPreview: LMActionExtractor.extractDisplayTextPartial(answerAccumulator),
            onReasoning: { callbacks.onStreamingReasoning?($0) },
            onAction: { callbacks.onStreamingAction?($0) }
        )

        guard (200...299).contains(streamResult.httpCode) else {
            callbacks.onError?("HTTP \(streamResult.httpCode): \(streamResult.errorBody ?? "Request failed")")
            return LMAgenticRunResult(
                httpCode: streamResult.httpCode,
                finalAction: "",
                rawOutput: "",
                reasoningFull: reasoningAccumulator,
                answerFull: answerAccumulator,
                finishCause: nil,
                errorBody: streamResult.errorBody,
                ttfbMs: streamResult.ttfbMs ?? 0
            )
        }

        let rawOutput = streamResult.fullText.isEmpty
            ? reasoningAccumulator + answerAccumulator
            : streamResult.fullText
        let arbitrated = arbiter.arbitrate(
            llmOutput: rawOutput,
            currentScores: currentScores,
            history: session.getAll(),
            session: session
        )

        return LMAgenticRunResult(
            httpCode: streamResult.httpCode,
            finalAction: arbitrated.action,
            rawOutput: rawOutput,
            reasoningFull: reasoningAccumulator,
            answerFull: answerAccumulator,
            finishCause: arbitrated.finishCause,
            errorBody: nil,
            ttfbMs: streamResult.ttfbMs ?? 0
        )
    }

    private func imageDataUrl(_ image: UIImage, config: LMAppConfig) -> String {
        let resized = resizeLongEdge(image, maxEdge: 512)
        let quality = CGFloat(config.imageDataUrlQuality) / 100.0
        let data = resized.jpegData(compressionQuality: quality) ?? Data()
        let base64 = data.base64EncodedString()
        return "data:\(config.imageDataUrlMime);base64,\(base64)"
    }

    private func resizeLongEdge(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let longSide = max(size.width, size.height)
        guard longSide > maxEdge else { return image }
        let scale = maxEdge / longSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    @MainActor
    private func setState(_ newState: LMAgentState, callbacks: LMAgenticLoopCallbacks) {
        state = newState
        callbacks.onState?(newState)
    }

    private func currentTimestampMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
