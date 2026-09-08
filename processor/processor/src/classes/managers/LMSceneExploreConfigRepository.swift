//
//  LMSceneExploreConfigRepository.swift
//  processor
//
//  Loads Scene Explore feature params from scene_explore_config.json + prompt assets.
//

import Foundation

/// Feature parameters for Scene Explore (no credentials).
struct LMSceneExploreFeatureConfig: Sendable {
    var timeoutSeconds: TimeInterval
    var heatmapOpacity: CGFloat
    var imageLongEdge: CGFloat
    var imageJPEGQuality: CGFloat
    var systemPrompt: String
    var userPrompt: String
}

/// Loads Scene Explore feature config from the app bundle.
final class LMSceneExploreConfigRepository: @unchecked Sendable {
    static let shared = LMSceneExploreConfigRepository()

    private let lock = NSLock()
    private var cached: LMSceneExploreFeatureConfig?

    private init() {}

    /// Returns cached feature config, loading on first access.
    func get() -> LMSceneExploreFeatureConfig {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let loaded = load()
        cached = loaded
        return loaded
    }

    /// Clears cache (e.g. after hot reload).
    func invalidate() {
        lock.lock()
        cached = nil
        lock.unlock()
    }

    private func load() -> LMSceneExploreFeatureConfig {
        let json = readJSON(named: "scene_explore_config")
        let systemAsset = json["system_prompt_asset"] as? String ?? "config/scene_explore_system_prompt.txt"
        let userAsset = json["user_prompt_asset"] as? String ?? "config/scene_explore_user_prompt.txt"
        return LMSceneExploreFeatureConfig(
            timeoutSeconds: TimeInterval(json["timeout_seconds"] as? Int ?? 180),
            heatmapOpacity: CGFloat(json["heatmap_opacity"] as? Double ?? 0.85),
            imageLongEdge: CGFloat(json["image_long_edge"] as? Int ?? 1024),
            imageJPEGQuality: CGFloat(json["image_jpeg_quality"] as? Int ?? 85) / 100.0,
            systemPrompt: readText(path: systemAsset) ?? fallbackSystem,
            userPrompt: readText(path: userAsset) ?? fallbackUser
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

    private func readText(path: String) -> String? {
        let components = path.split(separator: "/")
        let name = String(components.last ?? Substring(path))
        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        let subdir = components.dropLast().joined(separator: "/")
        if let url = Bundle.main.url(
            forResource: base,
            withExtension: ext.isEmpty ? nil : ext,
            subdirectory: subdir.isEmpty ? nil : subdir
        ), let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
            return text
        }
        if let url = Bundle.main.url(forResource: base, withExtension: ext.isEmpty ? nil : ext),
           let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
            return text
        }
        return nil
    }

    private var fallbackSystem: String {
        "你是一位专业摄影师。分析场景并返回 JSON：spots[{name,reason,bbox:[x1,y1,x2,y2]}]，可选 wide_scene。"
    }

    private var fallbackUser: String {
        "请分析这个场景，推荐适合拍摄人像的机位。"
    }
}
