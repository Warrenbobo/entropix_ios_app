//
//  LMAgentRequestLogRecorder.swift
//  processor
//
//  Builds request-log snapshots using the same resize/encode path as LMAgenticCoachingLoop.
//

import UIKit

/// Records agent LLM request/response payloads for the in-app request log.
enum LMAgentRequestLogRecorder {
    private static let submitLongEdge: CGFloat = 512
    private static let vectorPreviewCount = 8

    /// Records the payload about to be sent by an Instruct round.
    static func recordInstructRequest(
        round: Int,
        orientation: UIDeviceOrientation,
        reference: UIImage,
        cameraView: UIImage,
        config: LMAppConfig,
        userPrompt: String,
        compositionScore: LMCompositionScore
    ) {
        LMAgentRequestLogStore.shared.updateLatestScore(compositionScore)
        setSnapshot(
            round: round,
            source: .instruct,
            orientation: orientation,
            reference: reference,
            cameraView: cameraView,
            config: config,
            userPrompt: userPrompt,
            compositionScore: compositionScore
        )
    }

    /// Records LLM response fields after an Instruct round completes.
    static func recordInstructResponse(round: Int, result: LMAgenticRunResult) {
        let extracted = LMActionExtractor.extractAction(result.answerFull)
        let record = LMAgentLlmResponseRecord(
            completedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
            httpCode: result.httpCode,
            ttfbMs: result.ttfbMs > 0 ? result.ttfbMs : nil,
            reasoningFull: result.reasoningFull,
            answerFull: result.answerFull,
            rawOutputFull: result.rawOutput,
            llmActionExtracted: extracted,
            arbiterFinalAction: result.finalAction,
            errorBody: result.errorBody
        )
        LMAgentRequestLogStore.shared.patchSnapshotResponse(expectedRound: round, response: record)
    }

    /// Captures current preview/reference bitmaps without running the full Instruct pipeline.
    static func recordLiveCapture(
        orientation: UIDeviceOrientation,
        reference: UIImage,
        cameraView: UIImage,
        config: LMAppConfig,
        userPrompt: String
    ) {
        setSnapshot(
            round: nil,
            source: .liveCapture,
            orientation: orientation,
            reference: reference,
            cameraView: cameraView,
            config: config,
            userPrompt: userPrompt,
            compositionScore: nil
        )
    }

    /// Persists the raw preview bitmap captured by the Inspire Me button.
    static func recordInspireMeFrame(_ image: UIImage, orientationNote: String) {
        guard let copy = image.copy() as? UIImage else { return }
        LMAgentRequestLogStore.shared.setInspireMeFrame(
            LMInspireMeLogFrame(
                capturedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
                rawSize: "\(Int(image.size.width))x\(Int(image.size.height))",
                image: copy,
                orientationNote: orientationNote
            )
        )
    }

    /// Persists EVA02 embedding summary after Inspire Me.
    static func recordInspireMeEva02(embedding: [Float]) {
        let preview = embedding.prefix(vectorPreviewCount)
            .map { String(format: "%.4f", $0) }
            .joined(separator: ", ")
        let suffix = embedding.count > vectorPreviewCount ? ", …]" : "]"
        let l2 = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
        LMAgentRequestLogStore.shared.setInspireMeEva02(
            LMInspireMeEva02LogInfo(
                computedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
                vectorDim: embedding.count,
                l2Norm: l2,
                vectorPreview: "[\(preview)\(suffix)"
            )
        )
    }

    private static func setSnapshot(
        round: Int?,
        source: LMAgentRequestLogSource,
        orientation: UIDeviceOrientation,
        reference: UIImage,
        cameraView: UIImage,
        config: LMAppConfig,
        userPrompt: String,
        compositionScore: LMCompositionScore?
    ) {
        let refResized = resizeLongEdge(reference, maxEdge: submitLongEdge)
        let camResized = resizeLongEdge(cameraView, maxEdge: submitLongEdge)
        let requestJson = buildRequestJsonPreview(
            config: config,
            reference: refResized,
            cameraView: camResized,
            userPrompt: userPrompt
        )

        LMAgentRequestLogStore.shared.setSnapshot(
            LMAgentRequestLogSnapshot(
                recordedAtMs: Int64(Date().timeIntervalSince1970 * 1000),
                round: round,
                source: source,
                deviceOrientation: orientationLabel(orientation),
                rawReferenceSize: "\(Int(reference.size.width))x\(Int(reference.size.height))",
                rawCameraViewSize: "\(Int(cameraView.size.width))x\(Int(cameraView.size.height))",
                submittedReferenceSize: "\(Int(refResized.size.width))x\(Int(refResized.size.height))",
                submittedCameraViewSize: "\(Int(camResized.size.width))x\(Int(camResized.size.height))",
                referenceImage: refResized,
                cameraViewImage: camResized,
                systemPrompt: config.systemPrompt,
                userPrompt: userPrompt,
                requestJsonPreview: requestJson,
                compositionScore: compositionScore,
                llmResponse: nil
            )
        )
    }

    private static func buildRequestJsonPreview(
        config: LMAppConfig,
        reference: UIImage,
        cameraView: UIImage,
        userPrompt: String
    ) -> String {
        let refDataUrl = sanitizeDataUrl(imageDataUrl(reference, config: config))
        let camDataUrl = sanitizeDataUrl(imageDataUrl(cameraView, config: config))
        let payload: [String: Any] = [
            "model": config.modelName,
            "stream": true,
            "extra_body": ["thinking_budget": config.thinkingBudget],
            "messages": [
                ["role": "system", "content": config.systemPrompt],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": userPrompt],
                        ["type": "image_url", "image_url": ["url": refDataUrl]],
                        ["type": "image_url", "image_url": ["url": camDataUrl]]
                    ]
                ]
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private static func imageDataUrl(_ image: UIImage, config: LMAppConfig) -> String {
        let quality = CGFloat(config.imageDataUrlQuality) / 100.0
        let data = image.jpegData(compressionQuality: quality) ?? Data()
        let base64 = data.base64EncodedString()
        return "data:\(config.imageDataUrlMime);base64,\(base64)"
    }

    private static func sanitizeDataUrl(_ dataUrl: String) -> String {
        guard let range = dataUrl.range(of: "base64,") else { return dataUrl }
        let prefix = String(dataUrl[..<range.upperBound])
        let payload = String(dataUrl[range.upperBound...])
        return "\(prefix)<base64 len=\(payload.count)>"
    }

    private static func resizeLongEdge(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let longSide = max(size.width, size.height)
        guard longSide > maxEdge else { return image }
        let scale = maxEdge / longSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    private static func orientationLabel(_ orientation: UIDeviceOrientation) -> String {
        switch orientation {
        case .portrait: return "Portrait"
        case .portraitUpsideDown: return "PortraitUpsideDown"
        case .landscapeLeft: return "LandscapeLeft"
        case .landscapeRight: return "LandscapeRight"
        case .faceUp: return "FaceUp"
        case .faceDown: return "FaceDown"
        default: return "Unknown"
        }
    }
}
