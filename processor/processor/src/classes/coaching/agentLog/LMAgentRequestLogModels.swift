//
//  LMAgentRequestLogModels.swift
//  processor
//

import UIKit

/// Source of a captured agent request log entry.
enum LMAgentRequestLogSource: String, Sendable {
    case instruct = "INSTRUCT"
    case liveCapture = "LIVE_CAPTURE"
}

/// One agent LLM request snapshot for the in-app request log.
struct LMAgentRequestLogSnapshot: Sendable {
    let recordedAtMs: Int64
    let round: Int?
    let source: LMAgentRequestLogSource
    let deviceOrientation: String
    let rawReferenceSize: String
    let rawCameraViewSize: String
    let submittedReferenceSize: String
    let submittedCameraViewSize: String
    let referenceImage: UIImage
    let cameraViewImage: UIImage
    let systemPrompt: String
    let userPrompt: String
    let requestJsonPreview: String
    let compositionScore: LMCompositionScore?
    var llmResponse: LMAgentLlmResponseRecord?
}

/// LLM response fields paired with a snapshot.
struct LMAgentLlmResponseRecord: Sendable {
    let completedAtMs: Int64
    let httpCode: Int
    let ttfbMs: Int64?
    let reasoningFull: String
    let answerFull: String
    let rawOutputFull: String
    let llmActionExtracted: String
    let arbiterFinalAction: String
    let errorBody: String?
}

/// Raw Inspire Me preview frame captured for the request log.
struct LMInspireMeLogFrame: Sendable {
    let capturedAtMs: Int64
    let rawSize: String
    let image: UIImage
    let orientationNote: String
}

/// EVA02 embedding summary shown in the request log.
struct LMInspireMeEva02LogInfo: Sendable {
    let computedAtMs: Int64
    let vectorDim: Int
    let l2Norm: Float
    let vectorPreview: String
}
