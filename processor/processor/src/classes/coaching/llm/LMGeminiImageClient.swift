//
//  LMGeminiImageClient.swift
//  processor
//
//  Direct Gemini `generateContent` client for Inspire Me AIGC (SPEC §7).
//

import UIKit

/// Errors from the direct Gemini Inspire Me image path.
enum LMGeminiImageError: Error, LocalizedError {
    case invalidSettings
    case invalidURL
    case httpStatus(Int, String?)
    case blocked(String?)
    case noImage
    case decodeFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidSettings:
            return LMText.camera.geminiModelsNotConfigured
        case .invalidURL:
            return LMText.camera.geminiRequestFailed
        case .httpStatus(let code, let message):
            if let message, !message.isEmpty { return message }
            return String(format: LMText.camera.geminiHTTPErrorFormat, code)
        case .blocked:
            return LMText.camera.geminiPromptBlocked
        case .noImage:
            return LMText.camera.geminiNoImage
        case .decodeFailed:
            return LMText.camera.geminiDecodeFailed
        case .cancelled:
            return LMText.camera.geminiRequestFailed
        }
    }
}

/**
 Raw `URLSession` client for Gemini image generation.

 Uses stable `models.generateContent` (not Interactions API). Auth via `x-goog-api-key`.
 Response parsing skips `thought == true` parts and prefers the last non-thought inline image.
 */
final class LMGeminiImageClient {

    static let shared = LMGeminiImageClient()

    private let session: URLSession
    private let lock = NSLock()
    private var inFlightTask: URLSessionDataTask?

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = AppConfigs.Gemini.flashTimeout
        config.timeoutIntervalForResource = AppConfigs.Gemini.proTimeout
        session = URLSession(configuration: config)
    }

    /**
     Generates one collage (or discrete tile images) from a scene JPEG.

     - Parameters:
       - sceneJPEG: Compressed scene bytes (long edge ≤1024 recommended).
       - mimeType: Usually `image/jpeg`.
       - prompt: Bundled FixedPrompt (+ optional aspect suffix already applied).
       - aspectRatio: Snapped supported ratio (e.g. `3:4`).
       - settings: User Models-page settings.
       - completion: Main-queue result with either a single collage or up to 4 discrete images.
     */
    func generate(
        sceneJPEG: Data,
        mimeType: String = "image/jpeg",
        prompt: String,
        aspectRatio: String,
        settings: LMGeminiModelSettings,
        completion: @escaping (Result<[UIImage], Error>) -> Void
    ) {
        guard settings.isConfigured else {
            DispatchQueue.main.async { completion(.failure(LMGeminiImageError.invalidSettings)) }
            return
        }
        guard let url = Self.buildGenerateContentURL(baseURL: settings.baseURL, model: settings.model.rawValue) else {
            DispatchQueue.main.async { completion(.failure(LMGeminiImageError.invalidURL)) }
            return
        }

        let body = Self.buildRequestBody(
            prompt: prompt,
            sceneJPEG: sceneJPEG,
            mimeType: mimeType,
            aspectRatio: aspectRatio,
            imageSize: AppConfigs.Gemini.defaultImageSize,
            model: settings.model
        )

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            DispatchQueue.main.async { completion(.failure(LMGeminiImageError.decodeFailed)) }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(settings.apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.timeoutInterval = settings.model.requestTimeout
        request.httpBody = httpBody

        cancelInFlight()

        LMLogger.log(
            "🌐 Gemini generateContent model=\(settings.model.rawValue) aspect=\(aspectRatio) bytes=\(sceneJPEG.count)"
        )

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            self?.lock.lock()
            self?.inFlightTask = nil
            self?.lock.unlock()

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                DispatchQueue.main.async { completion(.failure(LMGeminiImageError.cancelled)) }
                return
            }
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let payload = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]

            if status == 429 || (500...599).contains(status) {
                // Single retry with short backoff for transient failures.
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1.5) {
                    self?.retryOnce(
                        request: request,
                        completion: completion
                    )
                }
                return
            }

            if status != 200 {
                let message = Self.extractErrorMessage(from: payload)
                DispatchQueue.main.async {
                    completion(.failure(LMGeminiImageError.httpStatus(status, message)))
                }
                return
            }

            if let block = Self.blockReason(from: payload) {
                DispatchQueue.main.async {
                    completion(.failure(LMGeminiImageError.blocked(block)))
                }
                return
            }

            do {
                let images = try Self.decodeImages(from: payload)
                DispatchQueue.main.async { completion(.success(images)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }

        lock.lock()
        inFlightTask = task
        lock.unlock()
        task.resume()
    }

    /// Cancels any in-flight Inspire Me Gemini request.
    func cancelInFlight() {
        lock.lock()
        inFlightTask?.cancel()
        inFlightTask = nil
        lock.unlock()
    }

    // MARK: - Private

    private func retryOnce(
        request: URLRequest,
        completion: @escaping (Result<[UIImage], Error>) -> Void
    ) {
        let task = session.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let payload = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
            if status != 200 {
                let message = Self.extractErrorMessage(from: payload)
                DispatchQueue.main.async {
                    completion(.failure(LMGeminiImageError.httpStatus(status, message)))
                }
                return
            }
            if let block = Self.blockReason(from: payload) {
                DispatchQueue.main.async { completion(.failure(LMGeminiImageError.blocked(block))) }
                return
            }
            do {
                let images = try Self.decodeImages(from: payload)
                DispatchQueue.main.async { completion(.success(images)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
        lock.lock()
        inFlightTask = task
        lock.unlock()
        task.resume()
    }

    /**
     Builds `{base}/v1beta/models/{model}:generateContent`.

     If `baseURL` already ends with `/v1` or `/v1beta`, appends `/models/...` only.
     */
    static func buildGenerateContentURL(baseURL: String, model: String) -> URL? {
        let normalized = LMGeminiModelSettingsStore.normalizeBaseURL(baseURL)
        let apiVersion = AppConfigs.Gemini.apiVersion
        let lower = normalized.lowercased()
        let path: String
        if lower.hasSuffix("/v1beta") || lower.hasSuffix("/v1") {
            path = "\(normalized)/models/\(model):generateContent"
        } else {
            path = "\(normalized)/\(apiVersion)/models/\(model):generateContent"
        }
        return URL(string: path)
    }

    static func buildRequestBody(
        prompt: String,
        sceneJPEG: Data,
        mimeType: String,
        aspectRatio: String,
        imageSize: String,
        model: LMGeminiImageModel
    ) -> [String: Any] {
        var generationConfig: [String: Any] = [
            "responseModalities": ["TEXT", "IMAGE"],
            // Consumer generateContent accepts string ratios/sizes under imageConfig.
            // responseFormat.image expects proto enums and rejects "3:4" / "1K".
            "imageConfig": [
                "aspectRatio": aspectRatio,
                "imageSize": imageSize
            ]
        ]
        if model.supportsMinimalThinking {
            generationConfig["thinkingConfig"] = ["thinkingLevel": "minimal"]
        }

        return [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": prompt],
                        [
                            "inlineData": [
                                "mimeType": mimeType,
                                "data": sceneJPEG.base64EncodedString()
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": generationConfig
        ]
    }

    /**
     Thought-safe decode: skip `thought == true` parts; collect remaining inline images.
     Prefer all discrete non-thought images when count is 2…4; otherwise return last image alone for split.
     */
    static func decodeImages(from payload: [String: Any]) throws -> [UIImage] {
        var nonThought: [UIImage] = []
        var thoughtCount = 0
        let candidates = payload["candidates"] as? [[String: Any]] ?? []
        for candidate in candidates {
            let content = candidate["content"] as? [String: Any] ?? [:]
            let parts = content["parts"] as? [[String: Any]] ?? []
            for part in parts {
                let thought = boolValue(part["thought"]) == true
                guard let inline = dictionaryValue(part["inlineData"] ?? part["inline_data"]) else {
                    continue
                }
                guard let dataString = stringValue(inline["data"] ?? inline["Data"]),
                      let data = Data(base64Encoded: dataString, options: [.ignoreUnknownCharacters]),
                      !data.isEmpty,
                      let image = UIImage(data: data) else {
                    continue
                }
                if thought {
                    thoughtCount += 1
                    continue
                }
                nonThought.append(image)
            }
        }

        LMLogger.log("🖼️ Gemini parts: nonThoughtImages=\(nonThought.count) thoughtSkipped=\(thoughtCount)")

        if nonThought.isEmpty {
            throw LMGeminiImageError.noImage
        }
        // 2…4 discrete finals → map directly; otherwise one collage for 2×2 split.
        if nonThought.count >= 2 && nonThought.count <= 4 {
            return nonThought
        }
        return [nonThought.last!]
    }

    static func blockReason(from payload: [String: Any]) -> String? {
        let feedback = payload["promptFeedback"] as? [String: Any]
            ?? payload["prompt_feedback"] as? [String: Any]
        guard let reason = stringValue(feedback?["blockReason"] ?? feedback?["block_reason"]),
              !reason.isEmpty else {
            return nil
        }
        return reason
    }

    static func extractErrorMessage(from payload: [String: Any]) -> String? {
        if let error = payload["error"] as? [String: Any] {
            return stringValue(error["message"])
        }
        return nil
    }

    private static func boolValue(_ any: Any?) -> Bool? {
        if let b = any as? Bool { return b }
        if let n = any as? NSNumber { return n.boolValue }
        return nil
    }

    private static func stringValue(_ any: Any?) -> String? {
        if let s = any as? String { return s }
        return nil
    }

    private static func dictionaryValue(_ any: Any?) -> [String: Any]? {
        any as? [String: Any]
    }
}
