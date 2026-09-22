//
//  LMSceneExploreClient.swift
//  processor
//
//  Device-direct Scene Explore VLM via OpenAI-compatible Chat Completions.
//

import UIKit

/// Result of a Scene Explore VLM call.
struct LMSceneExploreClientResult {
    var httpCode: Int
    var spots: [LMSceneExploreSpot]
    var wideScene: Bool
    var rawText: String
    var errorBody: String?
}

/// Parses Spot JSON from model output (strips fences / trailing prose when needed).
enum LMSceneExploreSpotParser {
    /**
     Parses Android-aligned Scene Explore JSON.

     Accepts bbox as `[x1,y1,x2,y2]` (preferred) or legacy `[x,y,w,h]`.
     */
    static func parse(from text: String) -> LMSceneExploreParseResult {
        let candidates = extractJSONCandidates(from: text)
        for candidate in candidates {
            if let parsed = decodePayload(from: candidate) {
                return parsed
            }
        }
        return LMSceneExploreParseResult(spots: [], wideScene: false, declineReason: nil)
    }

    private static func extractJSONCandidates(from text: String) -> [String] {
        var results: [String] = []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        results.append(trimmed)

        if let fence = trimmed.range(of: "```") {
            var body = String(trimmed[fence.upperBound...])
            if body.lowercased().hasPrefix("json") {
                body = String(body.dropFirst(4))
            }
            if let end = body.range(of: "```") {
                body = String(body[..<end.lowerBound])
            }
            results.append(body.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        if let start = trimmed.firstIndex(of: "{"),
           let end = trimmed.lastIndex(of: "}") {
            results.append(String(trimmed[start...end]))
        }
        return results
    }

    private static func decodePayload(from jsonText: String) -> LMSceneExploreParseResult? {
        guard let data = jsonText.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        let wideScene = boolValue(obj["wide_scene"]) ?? false
        let decline = (obj["decline_reason"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let rawSpots = (obj["spots"] as? [[String: Any]]) ?? []
        var spots: [LMSceneExploreSpot] = []
        for (index, item) in rawSpots.enumerated() {
            let id = (item["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (item["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let reason = (item["reason"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let warning = (item["safety_warning"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let cameraInstruction = (item["camera_instruction"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let bboxRaw = item["bbox"] as? [Any] ?? []
            let bboxNums = bboxRaw.compactMap { value -> CGFloat? in
                if let n = value as? NSNumber { return CGFloat(truncating: n) }
                return nil
            }
            guard !name.isEmpty, let xywh = normalizeBBox(bboxNums) else { continue }
            spots.append(
                LMSceneExploreSpot(
                    id: (id?.isEmpty == false ? id! : "spot_\(index + 1)"),
                    name: name,
                    reason: reason,
                    bbox: xywh,
                    safetyWarning: (warning?.isEmpty == false) ? warning : nil,
                    cameraInstruction: (cameraInstruction?.isEmpty == false) ? cameraInstruction : nil
                )
            )
        }
        // Valid empty payload (decline) still counts as a successful parse.
        if spots.isEmpty, decline == nil, rawSpots.isEmpty == false {
            return nil
        }
        if spots.isEmpty, obj["spots"] == nil, decline == nil {
            return nil
        }
        return LMSceneExploreParseResult(spots: spots, wideScene: wideScene, declineReason: decline)
    }

    /**
     Converts raw bbox to normalized xywh.

     - Prefer Android `[x1, y1, x2, y2]` when x2>x1 and y2>y1.
     - Fall back to legacy `[x, y, w, h]`.
     */
    static func normalizeBBox(_ raw: [CGFloat]) -> [CGFloat]? {
        guard raw.count >= 4 else { return nil }
        let x0 = raw[0], y0 = raw[1], a = raw[2], b = raw[3]
        let xywh: [CGFloat]
        if a > x0, b > y0, a <= 1.05, b <= 1.05 {
            xywh = [x0, y0, a - x0, b - y0]
        } else {
            xywh = [x0, y0, a, b]
        }
        let rect = CGRect(x: xywh[0], y: xywh[1], width: xywh[2], height: xywh[3])
            .standardized
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !rect.isNull, rect.width > 0.01, rect.height > 0.01 else { return nil }
        return [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height]
    }

    private static func boolValue(_ any: Any?) -> Bool? {
        if let b = any as? Bool { return b }
        if let n = any as? NSNumber { return n.boolValue }
        if let s = any as? String {
            let lower = s.lowercased()
            if lower == "true" || lower == "1" { return true }
            if lower == "false" || lower == "0" { return false }
        }
        return nil
    }
}

/// Streams Scene Explore chat completions and parses Spot JSON.
final class LMSceneExploreClient {
    private let chatClient = LMDashScopeChatClient()

    /**
     Runs Scene Explore on a full-frame image.

     Resizes proportionally to long edge from `scene_explore_config.json` (default 1024)
     before sending to the LLM.
     */
    func explore(image: UIImage) async -> LMSceneExploreClientResult {
        let settings = LMLlmModuleSettingsStore.loadSceneExplore()
        guard settings.isConfigured else {
            return LMSceneExploreClientResult(
                httpCode: 0,
                spots: [],
                wideScene: false,
                rawText: "",
                errorBody: "Scene Explore not configured"
            )
        }

        let feature = LMSceneExploreConfigRepository.shared.get()
        let longEdge = feature.imageLongEdge > 0 ? feature.imageLongEdge : 1024
        let prepared = prepareJPEG(image, longEdge: longEdge, quality: feature.imageJPEGQuality)
        let dataUrl = "data:image/jpeg;base64,\(prepared.base64EncodedString())"

        let systemContent = Self.systemPromptWithOutputLanguage(feature.systemPrompt)
        let messages: [[String: Any]] = [
            ["role": "system", "content": systemContent],
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": feature.userPrompt],
                    ["type": "image_url", "image_url": ["url": dataUrl]]
                ]
            ]
        ]

        let body = LMChatRequestBuilder.buildCompleteRequest(
            model: settings.modelName,
            enableThinking: settings.enableThinking,
            thinkingBudget: settings.thinkingBudget,
            temperature: settings.temperature,
            maxTokens: settings.maxTokens,
            messages: messages
        )

        let stream = await LMLlmTaskRuntime.shared.runExploreComplete(
            baseUrl: settings.baseURL,
            apiKey: settings.apiKey,
            requestBody: body
        )

        guard (200...299).contains(stream.httpCode) else {
            let errorBody = LMLlmTaskRuntime.isRetryableFailure(stream)
                ? LMLlmTaskRuntime.retryableErrorMessage(for: stream)
                : stream.errorBody
            return LMSceneExploreClientResult(
                httpCode: stream.httpCode,
                spots: [],
                wideScene: false,
                rawText: stream.fullText,
                errorBody: errorBody
            )
        }

        let parsed = LMSceneExploreSpotParser.parse(from: stream.fullText)
        if let decline = parsed.declineReason, parsed.spots.isEmpty {
            return LMSceneExploreClientResult(
                httpCode: stream.httpCode,
                spots: [],
                wideScene: parsed.wideScene,
                rawText: stream.fullText,
                errorBody: decline
            )
        }
        return LMSceneExploreClientResult(
            httpCode: stream.httpCode,
            spots: parsed.spots,
            wideScene: parsed.wideScene,
            rawText: stream.fullText,
            errorBody: parsed.spots.isEmpty ? "Failed to parse spots JSON" : nil
        )
    }

    /**
     Appends app-locale output-language constraints (Agent-parity) to the bundled system prompt.

     - Parameter base: Text from `scene_explore_system_prompt.txt`.
     - Returns: System content for this request.
     */
    private static func systemPromptWithOutputLanguage(_ base: String) -> String {
        let languageLines = LMLaunageManager.shared.currentLanguage.sceneExploreLLMOutputLanguageLines
        guard !languageLines.isEmpty else { return base }
        return base
            + "\n\n"
            + languageLines.joined(separator: "\n")
    }

    private func prepareJPEG(_ image: UIImage, longEdge: CGFloat, quality: CGFloat) -> Data {
        let resized = resizeLongEdge(image, maxEdge: longEdge)
        return resized.jpegData(compressionQuality: quality) ?? Data()
    }

    private func resizeLongEdge(_ image: UIImage, maxEdge: CGFloat) -> UIImage {
        let size = image.size
        let longSide = max(size.width, size.height)
        guard longSide > maxEdge, longSide > 0 else { return image }
        let scale = maxEdge / longSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
