//
//  LMCoachingPolicyConfig.swift
//  processor
//
//  Thresholds and strategy constants for the agentic coaching loop.
//

import Foundation

/// Thresholds for absolute composition strategy classification.
struct LMCompositionStrategyPolicyConfig: Sendable {
    var shotExtremeCloseUp: Float = 0.90
    var shotCloseUp: Float = 0.70
    var shotMediumClose: Float = 0.50
    var shotMediumShot: Float = 0.20
    var shotFullShot: Float = 0.10
    var dominanceSubjectArea: Float = 0.30
    var dominanceSubjectNegative: Float = 0.30
    var dominanceEnvironmentArea: Float = 0.10
    var dominanceEnvironmentNegative: Float = 0.50
    var dominanceEnvironmentAreaAlt: Float = 0.20
    var thirdsXTolerance: Float = 0.12
    var centerTolerance: Float = 0.13
    var ruleSymmetrical: Float = 0.75
    var ruleLeadingLines: Float = 0.60
    var ruleFramedDepth: Float = 0.70
    var negativeSpaceHigh: Float = 0.60
    var negativeSpaceOffset: Float = 0.40
    var guidanceEnvironmentAreaMax: Float = 0.10
    var guidanceSubjectAreaMin: Float = 0.30
}

/// Thresholds and strategy constants for the agentic coaching loop.
struct LMCoachingPolicyConfig: Sendable {
    let thresholdFinishOverall: Float
    let finishConsecutiveRounds: Int
    let globalExtremeLow: Float
    let dimLow: Float
    let subDimLow: Float
    let suggestFinishOverall: Float
    let suggestFinishCoreDim: Float
    let thresholdCoreDim: Float
    let oscillationWindow: Int
    let deferExposureBelowOverall: Float
    let forceFinishAboveOverall: Float
    let maxHistorySize: Int
    let historyPromptRounds: Int
    let historyEffectiveUp: Float
    let historyEffectiveDown: Float
    let oscillationStagnationEps: Float
    let executionToolsBoxAlignHoldMs: Int64
    let executionToolsLineArtAutoDismissMs: Int64
    let executionToolsPreferBoxWhenLinesBelow: Float
    let executionToolsPreferLineArtWhenScaleBelow: Float
    let skipEnabled: Bool
    let skipArbiterFallback: String
    let skipReevaluationEnabled: Bool
    let skipFinishOverall: Float
    let skipFinishCoreDim: Float
    let skipFinishSubjectCenter: Float
    let instructReuseScoreMaxAgeMs: Int64
    let compositionStrategy: LMCompositionStrategyPolicyConfig

    static let `default` = LMCoachingPolicyConfig(
        thresholdFinishOverall: 0.85,
        finishConsecutiveRounds: 2,
        globalExtremeLow: 0.2,
        dimLow: 0.65,
        subDimLow: 0.5,
        suggestFinishOverall: 0.82,
        suggestFinishCoreDim: 0.75,
        thresholdCoreDim: 0.70,
        oscillationWindow: 3,
        deferExposureBelowOverall: 0.7,
        forceFinishAboveOverall: 0.80,
        maxHistorySize: 5,
        historyPromptRounds: 3,
        historyEffectiveUp: 0.02,
        historyEffectiveDown: -0.02,
        oscillationStagnationEps: 0.03,
        executionToolsBoxAlignHoldMs: 3_000,
        executionToolsLineArtAutoDismissMs: 60_000,
        executionToolsPreferBoxWhenLinesBelow: 0.5,
        executionToolsPreferLineArtWhenScaleBelow: 0.5,
        skipEnabled: true,
        skipArbiterFallback: "finish",
        skipReevaluationEnabled: true,
        skipFinishOverall: 0.80,
        skipFinishCoreDim: 0.75,
        skipFinishSubjectCenter: 0.50,
        instructReuseScoreMaxAgeMs: 2_000,
        compositionStrategy: LMCompositionStrategyPolicyConfig()
    )
}

/// Piecewise mapping from EVA02 raw cosine to displayed S_global.
struct LMGlobalStructureCalibration: Sendable {
    let tNeg: Float
    let tLo: Float
    let tHi: Float
    let sNeg: Float
    let sLo: Float
    let sHi: Float
    let aboveHiTau: Float
    let sameSceneGamma: Float

    static let `default` = LMConfigRepository.defaultGlobalStructureCalibration
}

/// Runtime configuration loaded from bundled JSON assets.
struct LMAppConfig: Sendable {
    let baseUrl: String
    let apiKey: String
    let modelName: String
    /// Whether to send top-level `enable_thinking` on chat completions.
    let enableThinking: Bool
    let thinkingBudget: Int
    let temperature: Double
    let maxTokens: Int
    let imageDataUrlMime: String
    let imageDataUrlQuality: Int
    let systemPrompt: String
    let userPrompt: String
    let globalStructureCalibration: LMGlobalStructureCalibration

    func withSystemPrompt(_ prompt: String) -> LMAppConfig {
        LMAppConfig(
            baseUrl: baseUrl,
            apiKey: apiKey,
            modelName: modelName,
            enableThinking: enableThinking,
            thinkingBudget: thinkingBudget,
            temperature: temperature,
            maxTokens: maxTokens,
            imageDataUrlMime: imageDataUrlMime,
            imageDataUrlQuality: imageDataUrlQuality,
            systemPrompt: prompt,
            userPrompt: userPrompt,
            globalStructureCalibration: globalStructureCalibration
        )
    }
}
