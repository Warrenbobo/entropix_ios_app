//
//  LMGeminiInspireConfigRepository.swift
//  processor
//
//  Loads Idea Inspiration feature params from gemini_inspire_config.json.
//

import Foundation

/// Feature parameters for Direct Gemini Idea Inspiration (no credentials).
struct LMGeminiInspireFeatureConfig: Sendable {
    var promptAsset: String
    var inputLongEdge: CGFloat
    var jpegQuality: CGFloat
    var defaultImageSize: String
    var flashTimeoutSec: TimeInterval
    var proTimeoutSec: TimeInterval
}

/// Loads Gemini Inspire feature config from the app bundle.
final class LMGeminiInspireConfigRepository: @unchecked Sendable {
    static let shared = LMGeminiInspireConfigRepository()

    private let lock = NSLock()
    private var cached: LMGeminiInspireFeatureConfig?

    private init() {}

    /// Returns cached feature config.
    func get() -> LMGeminiInspireFeatureConfig {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let loaded = load()
        cached = loaded
        return loaded
    }

    /// Clears cache.
    func invalidate() {
        lock.lock()
        cached = nil
        lock.unlock()
    }

    private func load() -> LMGeminiInspireFeatureConfig {
        let json = readJSON(named: "gemini_inspire_config")
        return LMGeminiInspireFeatureConfig(
            promptAsset: json["prompt_asset"] as? String ?? AppConfigs.Gemini.inspirePromptAssetPath,
            inputLongEdge: CGFloat(json["input_long_edge"] as? Int ?? Int(AppConfigs.Gemini.inputMaxLongSide)),
            jpegQuality: CGFloat(json["jpeg_quality"] as? Double ?? 0.9),
            defaultImageSize: json["default_image_size"] as? String ?? AppConfigs.Gemini.defaultImageSize,
            flashTimeoutSec: TimeInterval(json["flash_timeout_sec"] as? Int ?? Int(AppConfigs.Gemini.flashTimeout)),
            proTimeoutSec: TimeInterval(json["pro_timeout_sec"] as? Int ?? Int(AppConfigs.Gemini.proTimeout))
        )
    }

    private func readJSON(named name: String) -> [String: Any] {
        if let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "config"),
           let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        return [:]
    }
}
