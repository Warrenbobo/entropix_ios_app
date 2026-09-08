//
//  LMQwenModelSettingsStore.swift
//  processor
//
//  Persists Qwen / DashScope Agent LLM baseURL + apiKey.
//  Thin facade over LMLlmModuleSettingsStore.arGuidance for call-site compatibility.
//

import Foundation

/// Snapshot of user-configured Qwen (DashScope compatible-mode) settings.
struct LMQwenModelSettings {
    var baseURL: String
    var apiKey: String

    /// True when baseURL and apiKey are non-empty after trim.
    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/**
 Loads and saves Qwen Agent LLM settings via `LMLlmModuleSettingsStore.arGuidance`.
 */
enum LMQwenModelSettingsStore {

    /// Current settings (defaults applied when unset).
    static func load() -> LMQwenModelSettings {
        let ar = LMLlmModuleSettingsStore.loadARGuidance()
        return LMQwenModelSettings(baseURL: ar.baseURL, apiKey: ar.apiKey)
    }

    /// Persists settings. Caller should validate first.
    static func save(_ settings: LMQwenModelSettings) {
        var ar = LMLlmModuleSettingsStore.loadARGuidance()
        ar.baseURL = settings.baseURL
        ar.apiKey = settings.apiKey
        LMLlmModuleSettingsStore.saveARGuidance(ar)
    }

    /// Whether Agent coaching may call DashScope with a user key.
    static var isConfigured: Bool {
        LMLlmModuleSettingsStore.isConfigured(.arGuidance)
    }

    /**
     Validates Qwen Models fields before save.

     - Returns: `nil` if valid; otherwise a toast / field error string.
     */
    static func validate(baseURL: String, apiKey: String) -> String? {
        let ar = LMLlmModuleSettingsStore.loadARGuidance()
        return LMLlmModuleSettingsStore.validateChat(
            baseURL: baseURL,
            apiKey: apiKey,
            modelName: ar.modelName,
            thinkingBudget: ar.thinkingBudget > 0 ? ar.thinkingBudget : 512,
            temperature: ar.temperature,
            maxTokens: ar.maxTokens > 0 ? ar.maxTokens : 2048
        )
    }

    /// Trims whitespace and trailing `/` from a base URL.
    static func normalizeBaseURL(_ raw: String) -> String {
        LMLlmModuleSettingsStore.normalizeBaseURL(raw)
    }
}
