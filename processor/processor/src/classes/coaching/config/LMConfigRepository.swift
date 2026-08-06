//
//  LMConfigRepository.swift
//  processor
//
//  Loads agent prompts from the app bundle; LLM defaults from AppConfigs.AgentLLM.
//

import Foundation

/// Loads coaching configuration from AppConfigs and bundled prompt assets.
final class LMConfigRepository: @unchecked Sendable {
    static let shared = LMConfigRepository()

    private let lock = NSLock()
    private var cached: LMAppConfig?

    private init() {}

    /// Returns cached app configuration, loading on first access.
    func get() -> LMAppConfig {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let loaded = load()
        cached = loaded
        return loaded
    }

    /// Clears the in-memory cache (e.g. after hot reload in debug).
    func invalidate() {
        lock.lock()
        cached = nil
        lock.unlock()
    }

    private func load() -> LMAppConfig {
        let prompts = (try? JSONSerialization.jsonObject(
            with: readBundleJSON(named: AppConfigs.AgentLLM.promptsJSON, subdirectory: "config")
        ) as? [String: Any]) ?? [:]

        return LMAppConfig(
            baseUrl: AppConfigs.AgentLLM.baseURL
                .trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            apiKey: AppConfigs.AgentLLM.apiKey,
            modelName: AppConfigs.AgentLLM.modelName,
            thinkingBudget: AppConfigs.AgentLLM.thinkingBudget,
            imageDataUrlMime: AppConfigs.AgentLLM.imageDataURLMime,
            imageDataUrlQuality: AppConfigs.AgentLLM.imageDataURLQuality,
            systemPrompt: loadSystemPrompt(from: prompts),
            userPrompt: prompts["user_prompt"] as? String ?? AppConfigs.AgentLLM.userPromptPlaceholder,
            globalStructureCalibration: Self.defaultGlobalStructureCalibration
        )
    }

    private func loadSystemPrompt(from prompts: [String: Any]) -> String {
        if let assetPath = prompts["system_prompt_asset"] as? String,
           let text = String(data: readBundleResource(path: assetPath), encoding: .utf8),
           !text.isEmpty {
            return text
        }
        if let inline = prompts["system_prompt"] as? String, !inline.isEmpty {
            return inline
        }
        if let text = String(
            data: readBundleResource(path: AppConfigs.AgentLLM.systemPromptAssetPath),
            encoding: .utf8
        ), !text.isEmpty {
            return text
        }
        LMLogger.log("AGENT_SYSTEM_PROMPT_FALLBACK: bundled system_prompt_agentic_v3.txt not found")
        return fallbackSystemPrompt
    }

    private func readBundleJSON(named name: String, subdirectory: String?) -> Data {
        if let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: subdirectory) {
            return (try? Data(contentsOf: url)) ?? Data()
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "json") {
            return (try? Data(contentsOf: url)) ?? Data()
        }
        return Data()
    }

    /// Loads a bundled resource by logical path (e.g. `config/system_prompt_agentic_v3.txt`).
    ///
    /// Xcode Copy Bundle Resources often flattens `resources/config/` files to the app bundle root,
    /// so this tries the subdirectory first, then the bundle root.
    private func readBundleResource(path: String) -> Data {
        let components = path.split(separator: "/")
        let name = String(components.last ?? Substring(path))
        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        let subdir = components.dropLast().joined(separator: "/")
        let extensionOrNil: String? = ext.isEmpty ? nil : ext

        if !subdir.isEmpty,
           let url = Bundle.main.url(forResource: base, withExtension: extensionOrNil, subdirectory: subdir),
           let data = try? Data(contentsOf: url), !data.isEmpty {
            return data
        }
        if let url = Bundle.main.url(forResource: base, withExtension: extensionOrNil),
           let data = try? Data(contentsOf: url), !data.isEmpty {
            return data
        }
        return Data()
    }

    private var fallbackSystemPrompt: String {
        """
        你是专业摄影构图教练。分析参考图与当前相机画面，输出下一步语义动作。
        在 <answer> 标签内输出 finish(...) 或 do(action="...", ...) 格式的动作。
        """
    }

    static var defaultGlobalStructureCalibration: LMGlobalStructureCalibration {
        let c = AppConfigs.AgentLLM.GlobalStructureCalibration.self
        return LMGlobalStructureCalibration(
            tNeg: c.tNeg,
            tLo: c.tLo,
            tHi: c.tHi,
            sNeg: c.sNeg,
            sLo: c.sLo,
            sHi: c.sHi,
            aboveHiTau: c.aboveHiTau,
            sameSceneGamma: c.sameSceneGamma
        )
    }
}
