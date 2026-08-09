//
//  LMQwenModelSettingsStore.swift
//  processor
//
//  Persists Qwen / DashScope (ModelScope) Agent LLM baseURL + apiKey for Models page.
//

import Foundation
import KeychainAccess

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
 Loads and saves Qwen Agent LLM settings from the Models page.

 - baseURL → UserDefaults
 - apiKey → Keychain (`KeychainAccess`)
 */
enum LMQwenModelSettingsStore {

    private static let baseURLKey = "qwen_agent_base_url"
    private static let apiKeyKeychainKey = "com.processor.keychain.qwen_api_key"

    private static var keychain: Keychain {
        Keychain(service: "com.processor.keychain")
    }

    /// Current settings (defaults applied when unset).
    static func load() -> LMQwenModelSettings {
        let rawBase = UserDefaults.standard.string(forKey: baseURLKey)
            ?? AppConfigs.AgentLLM.defaultBaseURL
        let apiKey = (try? keychain.getString(apiKeyKeychainKey)) ?? ""
        return LMQwenModelSettings(
            baseURL: normalizeBaseURL(rawBase),
            apiKey: apiKey
        )
    }

    /// Persists settings. Caller should validate first.
    static func save(_ settings: LMQwenModelSettings) {
        let base = normalizeBaseURL(settings.baseURL)
        UserDefaults.standard.set(base, forKey: baseURLKey)
        let key = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if key.isEmpty {
                try keychain.remove(apiKeyKeychainKey)
            } else {
                try keychain.set(key, key: apiKeyKeychainKey)
            }
        } catch {
            LMLogger.log("⚠️ Qwen apiKey Keychain save failed: \(error.localizedDescription)")
        }
        // Agent config is cached at first `get()` — force reload after Models save.
        LMConfigRepository.shared.invalidate()
        LMLogger.log("💾 Qwen model settings saved: baseURL=\(base)")
    }

    /// Whether Agent coaching may call DashScope with a user key.
    static var isConfigured: Bool {
        load().isConfigured
    }

    /**
     Validates Qwen Models fields before save.

     - Returns: `nil` if valid; otherwise a toast / field error string.
     */
    static func validate(baseURL: String, apiKey: String) -> String? {
        let trimmedBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBase.isEmpty else {
            return LMText.settings.modelsBaseURLRequired
        }
        guard let url = URL(string: trimmedBase),
              let scheme = url.scheme?.lowercased(),
              (scheme == "https" || scheme == "http"),
              url.host != nil else {
            return LMText.settings.modelsBaseURLInvalid
        }
        guard !trimmedKey.isEmpty else {
            return LMText.settings.modelsAPIKeyRequired
        }
        return nil
    }

    /// Trims whitespace and trailing `/` from a base URL.
    static func normalizeBaseURL(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }
}
