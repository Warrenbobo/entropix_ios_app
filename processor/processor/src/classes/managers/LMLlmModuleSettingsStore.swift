//
//  LMLlmModuleSettingsStore.swift
//  processor
//
//  Per-module BYOK settings for Scene Explore / Idea Inspiration / AR Guidance.
//  Resolve order: user Save → model_config.json → safe empty defaults.
//

import Foundation
import KeychainAccess

/// Feature modules that own independent LLM credentials (parity SPEC §3).
enum LMLlmFeatureModule: String, CaseIterable {
    case sceneExplore = "scene_explore"
    case ideaInspiration = "idea_inspiration"
    case arGuidance = "ar_guidance"

    /// JSON key inside `model_config.json`.
    var configKey: String { rawValue }

    /// UserDefaults / Keychain suffix.
    var storageSuffix: String { rawValue }
}

/// OpenAI-compatible chat module connection settings (Scene Explore / AR Guidance).
struct LMChatModuleSettings: Equatable {
    var baseURL: String
    var apiKey: String
    var modelName: String
    var enableThinking: Bool
    var thinkingBudget: Int
    var temperature: Double
    var maxTokens: Int

    /// True when baseURL, apiKey, and modelName are non-empty after trim.
    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func emptyDefaults(enableThinking: Bool = false, thinkingBudget: Int = 512) -> LMChatModuleSettings {
        LMChatModuleSettings(
            baseURL: "",
            apiKey: "",
            modelName: "",
            enableThinking: enableThinking,
            thinkingBudget: thinkingBudget,
            temperature: 0.7,
            maxTokens: 2048
        )
    }
}

/// Gemini Idea Inspiration connection settings.
struct LMIdeaInspirationSettings: Equatable {
    var baseURL: String
    var apiKey: String
    var model: LMGeminiImageModel

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var modelName: String { model.rawValue }

    static var emptyDefaults: LMIdeaInspirationSettings {
        LMIdeaInspirationSettings(
            baseURL: AppConfigs.Gemini.defaultBaseURL,
            apiKey: "",
            model: .flash31
        )
    }
}

/**
 Loads and saves per-module Models settings.

 - Non-secret fields → UserDefaults
 - apiKey → Keychain
 - Resolve: user saved → `model_config.json` → empty safe defaults
 */
enum LMLlmModuleSettingsStore {

    private static let migrationFlagKey = "llm_module_settings_migrated_v1"
    /// Clears model name previously injected by v1 migration (`AppConfigs.AgentLLM.modelName`).
    private static let clearInventedARModelFlagKey = "llm_module_cleared_ar_invented_model_v1"
    private static let userSavedPrefix = "llm_module_user_saved_"
    /// Old compile-time default that must not remain as a shipped AR Guidance value.
    private static let inventedARGuidanceModelName = "qwen3.5-397b-a17b"

    private static var keychain: Keychain {
        Keychain(service: "com.processor.keychain")
    }

    // MARK: - Public API

    /// Scene Explore chat settings.
    static func loadSceneExplore() -> LMChatModuleSettings {
        migrateLegacyIfNeeded()
        return loadChatModule(.sceneExplore)
    }

    /// AR Guidance chat settings.
    static func loadARGuidance() -> LMChatModuleSettings {
        migrateLegacyIfNeeded()
        clearInventedARGuidanceModelIfNeeded()
        return loadChatModule(.arGuidance)
    }

    /// Idea Inspiration (Gemini) settings.
    static func loadIdeaInspiration() -> LMIdeaInspirationSettings {
        migrateLegacyIfNeeded()
        return loadIdeaModule()
    }

    /// Whether the given module has enough credentials to call the provider.
    static func isConfigured(_ module: LMLlmFeatureModule) -> Bool {
        switch module {
        case .sceneExplore: return loadSceneExplore().isConfigured
        case .arGuidance: return loadARGuidance().isConfigured
        case .ideaInspiration: return loadIdeaInspiration().isConfigured
        }
    }

    /// Persists Scene Explore settings (caller validates first).
    static func saveSceneExplore(_ settings: LMChatModuleSettings) {
        saveChatModule(.sceneExplore, settings)
    }

    /// Persists AR Guidance settings (caller validates first).
    static func saveARGuidance(_ settings: LMChatModuleSettings) {
        saveChatModule(.arGuidance, settings)
        LMConfigRepository.shared.invalidate()
    }

    /// Persists Idea Inspiration settings (caller validates first).
    static func saveIdeaInspiration(_ settings: LMIdeaInspirationSettings) {
        let base = normalizeBaseURL(settings.baseURL)
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: userSavedKey(.ideaInspiration))
        defaults.set(base, forKey: baseURLKey(.ideaInspiration))
        defaults.set(settings.model.rawValue, forKey: modelNameKey(.ideaInspiration))
        writeAPIKey(settings.apiKey, module: .ideaInspiration)
        // Keep legacy Gemini store keys in sync for any remaining call sites.
        defaults.set(base, forKey: "gemini_inspire_base_url")
        defaults.set(settings.model.rawValue, forKey: "gemini_inspire_model")
        LMLogger.log("💾 Idea Inspiration settings saved: model=\(settings.model.rawValue) baseURL=\(base)")
    }

    /**
     Legacy dual-write helper — do **not** call from Models overview UI.

     Camera UX LLM Runtime SPEC §7: thinking is per-module only; overview has no
     global switch. Kept for migration / tests.
     */
    @available(*, deprecated, message: "Per-module Save only; overview must not dual-write thinking")
    static func setEnableThinkingForChatModules(_ enabled: Bool) {
        var explore = loadSceneExplore()
        explore.enableThinking = enabled
        saveSceneExplore(explore)

        var ar = loadARGuidance()
        ar.enableThinking = enabled
        saveARGuidance(ar)
    }

    /// Diagnostic: true if either chat module has thinking enabled (not an overview control).
    static var overviewEnableThinking: Bool {
        loadSceneExplore().enableThinking || loadARGuidance().enableThinking
    }

    /// Restores a module to bundled `model_config.json` defaults (clears user-saved flag).
    static func restoreDefaults(_ module: LMLlmFeatureModule) {
        UserDefaults.standard.set(false, forKey: userSavedKey(module))
        clearPersistedFields(module)
        if module == .arGuidance {
            LMConfigRepository.shared.invalidate()
        }
        LMLogger.log("♻️ Restored defaults for module \(module.rawValue)")
    }

    // MARK: - Validation

    /// Validates OpenAI-compatible chat module fields. Returns toast/field error or nil.
    static func validateChat(
        baseURL: String,
        apiKey: String,
        modelName: String,
        thinkingBudget: Int,
        temperature: Double,
        maxTokens: Int
    ) -> String? {
        let trimmedBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBase.isEmpty else { return LMText.settings.modelsBaseURLRequired }
        guard let url = URL(string: trimmedBase),
              let scheme = url.scheme?.lowercased(),
              (scheme == "https" || scheme == "http"),
              url.host != nil else {
            return LMText.settings.modelsBaseURLInvalid
        }
        guard !trimmedKey.isEmpty else { return LMText.settings.modelsAPIKeyRequired }
        guard !trimmedModel.isEmpty else { return LMText.settings.modelsModelRequired }
        guard (16...65536).contains(thinkingBudget) else {
            return LMText.settings.modelsThinkingBudgetInvalid
        }
        guard temperature >= 0 && temperature <= 1.5 else {
            return LMText.settings.modelsTemperatureInvalid
        }
        guard (256...16384).contains(maxTokens) else {
            return LMText.settings.modelsMaxTokensInvalid
        }
        return nil
    }

    /// Validates Idea Inspiration fields. Returns toast/field error or nil.
    static func validateIdeaInspiration(
        baseURL: String,
        apiKey: String,
        model: LMGeminiImageModel
    ) -> String? {
        _ = model
        return LMGeminiModelSettingsStore.validate(baseURL: baseURL, apiKey: apiKey, model: model)
    }

    static func normalizeBaseURL(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    // MARK: - Load / Save internals

    private static func loadChatModule(_ module: LMLlmFeatureModule) -> LMChatModuleSettings {
        let defaults = UserDefaults.standard
        let bundled = bundledChatDefaults(module)
        let empty = LMChatModuleSettings.emptyDefaults()

        if defaults.bool(forKey: userSavedKey(module)) {
            return LMChatModuleSettings(
                baseURL: normalizeBaseURL(defaults.string(forKey: baseURLKey(module)) ?? bundled.baseURL),
                apiKey: readAPIKey(module: module),
                modelName: defaults.string(forKey: modelNameKey(module)) ?? bundled.modelName,
                enableThinking: defaults.object(forKey: enableThinkingKey(module)) as? Bool ?? bundled.enableThinking,
                thinkingBudget: defaults.object(forKey: thinkingBudgetKey(module)) as? Int ?? bundled.thinkingBudget,
                temperature: defaults.object(forKey: temperatureKey(module)) as? Double ?? bundled.temperature,
                maxTokens: defaults.object(forKey: maxTokensKey(module)) as? Int ?? bundled.maxTokens
            )
        }

        // Bundled model_config non-empty fields, else empty defaults.
        var merged = empty
        if !bundled.baseURL.isEmpty { merged.baseURL = bundled.baseURL }
        if !bundled.modelName.isEmpty { merged.modelName = bundled.modelName }
        merged.enableThinking = bundled.enableThinking
        merged.thinkingBudget = bundled.thinkingBudget
        merged.temperature = bundled.temperature
        merged.maxTokens = bundled.maxTokens
        // Asset api_key is only an optional dev default — prefer empty for shipping.
        if !bundled.apiKey.isEmpty {
            merged.apiKey = bundled.apiKey
        }
        return merged
    }

    private static func loadIdeaModule() -> LMIdeaInspirationSettings {
        let defaults = UserDefaults.standard
        let bundled = bundledIdeaDefaults()
        if defaults.bool(forKey: userSavedKey(.ideaInspiration)) {
            let modelRaw = defaults.string(forKey: modelNameKey(.ideaInspiration))
                ?? bundled.model.rawValue
            return LMIdeaInspirationSettings(
                baseURL: normalizeBaseURL(defaults.string(forKey: baseURLKey(.ideaInspiration)) ?? bundled.baseURL),
                apiKey: readAPIKey(module: .ideaInspiration),
                model: LMGeminiImageModel(rawValue: modelRaw) ?? .flash31
            )
        }
        var merged = LMIdeaInspirationSettings.emptyDefaults
        if !bundled.baseURL.isEmpty { merged.baseURL = bundled.baseURL }
        merged.model = bundled.model
        if !bundled.apiKey.isEmpty { merged.apiKey = bundled.apiKey }
        return merged
    }

    private static func saveChatModule(_ module: LMLlmFeatureModule, _ settings: LMChatModuleSettings) {
        let base = normalizeBaseURL(settings.baseURL)
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: userSavedKey(module))
        defaults.set(base, forKey: baseURLKey(module))
        defaults.set(settings.modelName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: modelNameKey(module))
        defaults.set(settings.enableThinking, forKey: enableThinkingKey(module))
        defaults.set(settings.thinkingBudget, forKey: thinkingBudgetKey(module))
        defaults.set(settings.temperature, forKey: temperatureKey(module))
        defaults.set(settings.maxTokens, forKey: maxTokensKey(module))
        writeAPIKey(settings.apiKey, module: module)

        if module == .arGuidance {
            // Keep legacy Qwen keys in sync.
            defaults.set(base, forKey: "qwen_agent_base_url")
        }
        LMLogger.log("💾 \(module.rawValue) settings saved: model=\(settings.modelName) thinking=\(settings.enableThinking)")
    }

    // MARK: - Bundled model_config.json

    private static func bundledJSON() -> [String: Any] {
        if let url = Bundle.main.url(forResource: "model_config", withExtension: "json", subdirectory: "config"),
           let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        if let url = Bundle.main.url(forResource: "model_config", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return obj
        }
        return [:]
    }

    private static func bundledChatDefaults(_ module: LMLlmFeatureModule) -> LMChatModuleSettings {
        let block = bundledJSON()[module.configKey] as? [String: Any] ?? [:]
        return LMChatModuleSettings(
            baseURL: block["base_url"] as? String ?? "",
            apiKey: block["api_key"] as? String ?? "",
            modelName: block["model_name"] as? String ?? "",
            enableThinking: block["enable_thinking"] as? Bool ?? false,
            thinkingBudget: block["thinking_budget"] as? Int ?? 512,
            temperature: block["temperature"] as? Double ?? 0.7,
            maxTokens: block["max_tokens"] as? Int ?? 2048
        )
    }

    private static func bundledIdeaDefaults() -> LMIdeaInspirationSettings {
        let block = bundledJSON()[LMLlmFeatureModule.ideaInspiration.configKey] as? [String: Any] ?? [:]
        let modelRaw = block["model_name"] as? String ?? LMGeminiImageModel.flash31.rawValue
        return LMIdeaInspirationSettings(
            baseURL: block["base_url"] as? String ?? AppConfigs.Gemini.defaultBaseURL,
            apiKey: block["api_key"] as? String ?? "",
            model: LMGeminiImageModel(rawValue: modelRaw) ?? .flash31
        )
    }

    // MARK: - Keychain / UserDefaults keys

    private static func userSavedKey(_ module: LMLlmFeatureModule) -> String {
        userSavedPrefix + module.storageSuffix
    }

    private static func baseURLKey(_ module: LMLlmFeatureModule) -> String {
        "llm_module_base_url_\(module.storageSuffix)"
    }

    private static func modelNameKey(_ module: LMLlmFeatureModule) -> String {
        "llm_module_model_name_\(module.storageSuffix)"
    }

    private static func enableThinkingKey(_ module: LMLlmFeatureModule) -> String {
        "llm_module_enable_thinking_\(module.storageSuffix)"
    }

    private static func thinkingBudgetKey(_ module: LMLlmFeatureModule) -> String {
        "llm_module_thinking_budget_\(module.storageSuffix)"
    }

    private static func temperatureKey(_ module: LMLlmFeatureModule) -> String {
        "llm_module_temperature_\(module.storageSuffix)"
    }

    private static func maxTokensKey(_ module: LMLlmFeatureModule) -> String {
        "llm_module_max_tokens_\(module.storageSuffix)"
    }

    private static func apiKeyKeychainKey(_ module: LMLlmFeatureModule) -> String {
        "com.processor.keychain.llm_api_key_\(module.storageSuffix)"
    }

    private static func readAPIKey(module: LMLlmFeatureModule) -> String {
        (try? keychain.getString(apiKeyKeychainKey(module))) ?? ""
    }

    private static func writeAPIKey(_ apiKey: String, module: LMLlmFeatureModule) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if key.isEmpty {
                try keychain.remove(apiKeyKeychainKey(module))
            } else {
                try keychain.set(key, key: apiKeyKeychainKey(module))
            }
        } catch {
            LMLogger.log("⚠️ LLM apiKey Keychain save failed (\(module.rawValue)): \(error.localizedDescription)")
        }
        // Mirror legacy keychain slots used by Gemini / Qwen stores.
        let legacyKey: String?
        switch module {
        case .ideaInspiration: legacyKey = "com.processor.keychain.gemini_api_key"
        case .arGuidance: legacyKey = "com.processor.keychain.qwen_api_key"
        case .sceneExplore: legacyKey = nil
        }
        if let legacyKey {
            do {
                if key.isEmpty {
                    try keychain.remove(legacyKey)
                } else {
                    try keychain.set(key, key: legacyKey)
                }
            } catch {
                LMLogger.log("⚠️ Legacy apiKey mirror failed: \(error.localizedDescription)")
            }
        }
    }

    private static func clearPersistedFields(_ module: LMLlmFeatureModule) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: baseURLKey(module))
        defaults.removeObject(forKey: modelNameKey(module))
        defaults.removeObject(forKey: enableThinkingKey(module))
        defaults.removeObject(forKey: thinkingBudgetKey(module))
        defaults.removeObject(forKey: temperatureKey(module))
        defaults.removeObject(forKey: maxTokensKey(module))
        writeAPIKey("", module: module)
        if module == .arGuidance {
            defaults.removeObject(forKey: "qwen_agent_base_url")
        }
    }

    // MARK: - Migration from Gemini / Qwen stores

    private static func migrateLegacyIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationFlagKey) else { return }
        defaults.set(true, forKey: migrationFlagKey)

        // Gemini → Idea Inspiration
        let geminiBase = defaults.string(forKey: "gemini_inspire_base_url")
        let geminiModel = defaults.string(forKey: "gemini_inspire_model")
        let geminiKey = (try? keychain.getString("com.processor.keychain.gemini_api_key")) ?? ""
        if let geminiBase, !geminiBase.isEmpty || !geminiKey.isEmpty {
            defaults.set(true, forKey: userSavedKey(.ideaInspiration))
            defaults.set(normalizeBaseURL(geminiBase), forKey: baseURLKey(.ideaInspiration))
            defaults.set(geminiModel ?? LMGeminiImageModel.flash31.rawValue, forKey: modelNameKey(.ideaInspiration))
            if !geminiKey.isEmpty {
                try? keychain.set(geminiKey, key: apiKeyKeychainKey(.ideaInspiration))
            }
        }

        // Qwen → AR Guidance (legacy store had baseURL + apiKey only; do not invent model defaults).
        let qwenBase = defaults.string(forKey: "qwen_agent_base_url")
        let qwenKey = (try? keychain.getString("com.processor.keychain.qwen_api_key")) ?? ""
        if let qwenBase, !qwenBase.isEmpty || !qwenKey.isEmpty {
            defaults.set(true, forKey: userSavedKey(.arGuidance))
            defaults.set(normalizeBaseURL(qwenBase), forKey: baseURLKey(.arGuidance))
            defaults.set("", forKey: modelNameKey(.arGuidance))
            defaults.set(false, forKey: enableThinkingKey(.arGuidance))
            defaults.set(512, forKey: thinkingBudgetKey(.arGuidance))
            defaults.set(0.7, forKey: temperatureKey(.arGuidance))
            defaults.set(2048, forKey: maxTokensKey(.arGuidance))
            if !qwenKey.isEmpty {
                try? keychain.set(qwenKey, key: apiKeyKeychainKey(.arGuidance))
            }
        }

        LMLogger.log("🔁 Migrated legacy Gemini/Qwen settings into LMLlmModuleSettingsStore")
    }

    /**
     One-shot: remove AR Guidance model name that v1 migration filled from
     `AppConfigs.AgentLLM.modelName` (legacy Qwen store had no model field).
     Does not clear base URL — that may be a real user value from the old Qwen page.
     */
    private static func clearInventedARGuidanceModelIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: clearInventedARModelFlagKey) else { return }
        defaults.set(true, forKey: clearInventedARModelFlagKey)
        let stored = defaults.string(forKey: modelNameKey(.arGuidance)) ?? ""
        if stored == inventedARGuidanceModelName {
            defaults.set("", forKey: modelNameKey(.arGuidance))
            LMConfigRepository.shared.invalidate()
            LMLogger.log("♻️ Cleared invented AR Guidance model name default")
        }
    }
}
