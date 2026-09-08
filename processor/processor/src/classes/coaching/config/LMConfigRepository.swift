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
    private var cachedGeminiInspirePrompt: String?
    private var geminiPromptFallbackLogged = false

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
        cachedGeminiInspirePrompt = nil
        geminiPromptFallbackLogged = false
        lock.unlock()
    }

    /**
     Loads the Inspire Me FixedPrompt from `gemini_inspire_prompt.txt`.

     Pipeline expects **one** final 2×2 contact sheet (see SPEC §6.3). Callers may append
     `Expected panel aspect ratio: {ratio}.` after this string.
     */
    func geminiInspirePrompt() -> String {
        lock.lock()
        defer { lock.unlock() }
        if let cachedGeminiInspirePrompt, !cachedGeminiInspirePrompt.isEmpty {
            return cachedGeminiInspirePrompt
        }
        if let text = String(
            data: readBundleResource(path: AppConfigs.Gemini.inspirePromptAssetPath),
            encoding: .utf8
        ), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cachedGeminiInspirePrompt = text
            return text
        }
        // Xcode may flatten `resources/config/*` to the bundle root.
        if let url = Bundle.main.url(forResource: "gemini_inspire_prompt", withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cachedGeminiInspirePrompt = text
            return text
        }
        if !geminiPromptFallbackLogged {
            geminiPromptFallbackLogged = true
            LMLogger.log("⚠️ gemini_inspire_prompt.txt missing — using short fallback prompt")
        }
        let fallback = fallbackGeminiInspirePrompt
        cachedGeminiInspirePrompt = fallback
        return fallback
    }

    private var fallbackGeminiInspirePrompt: String {
        """
        Task: Analyze reference image scenery, then generate a 2x2 grid.
        Output exactly one image: a single 2x2 contact sheet (four equal panels). Do not return four separate images.
        Subject: Young Chinese traveler, modest fashionable daily wear.
        Preserve reference background; photorealistic travel aesthetic.
        """
    }

    private func load() -> LMAppConfig {
        let prompts = (try? JSONSerialization.jsonObject(
            with: readBundleJSON(named: AppConfigs.AgentLLM.promptsJSON, subdirectory: "config")
        ) as? [String: Any]) ?? [:]

        let ar = LMLlmModuleSettingsStore.loadARGuidance()
        return LMAppConfig(
            baseUrl: ar.baseURL
                .trimmingCharacters(in: CharacterSet(charactersIn: "/")),
            apiKey: ar.apiKey,
            modelName: ar.modelName,
            enableThinking: ar.enableThinking,
            thinkingBudget: ar.thinkingBudget > 0 ? ar.thinkingBudget : AppConfigs.AgentLLM.thinkingBudget,
            temperature: ar.temperature,
            maxTokens: ar.maxTokens,
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

    private func readBundleResource(path: String) -> Data {
        let components = path.split(separator: "/")
        let name = String(components.last ?? Substring(path))
        let ext = (name as NSString).pathExtension
        let base = (name as NSString).deletingPathExtension
        let subdir = components.dropLast().joined(separator: "/")
        guard let url = Bundle.main.url(
            forResource: base,
            withExtension: ext.isEmpty ? nil : ext,
            subdirectory: subdir.isEmpty ? nil : subdir
        ) else {
            return Data()
        }
        return (try? Data(contentsOf: url)) ?? Data()
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
