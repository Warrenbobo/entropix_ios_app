//
//  LMGeminiModelSettingsStore.swift
//  processor
//
//  Persists Gemini BYOK settings for Inspire Me (baseURL / model / apiKey).
//

import Foundation
import KeychainAccess

/**
 Locked Gemini image model ids for Inspire Me (SPEC §5.3).

 Do not expose legacy `gemini-2.5-*` or preview suffixes in the Models UI.
 */
enum LMGeminiImageModel: String, CaseIterable {
    /// Nano Banana 2 — default / faster Inspire Me path.
    case flash31 = "gemini-3.1-flash-image"
    /// Nano Banana Pro — higher fidelity; longer latency.
    case pro3 = "gemini-3-pro-image"

    /// User-facing display name (i18n applied at call sites via LMText).
    var displayNameKey: String {
        switch self {
        case .flash31: return "gemini31FlashImage"
        case .pro3: return "gemini3ProImage"
        }
    }

    /// Preferred URLSession timeout for this model (SPEC §7.6).
    var requestTimeout: TimeInterval {
        switch self {
        case .flash31: return AppConfigs.Gemini.flashTimeout
        case .pro3: return AppConfigs.Gemini.proTimeout
        }
    }

    /// Whether to send `thinkingConfig.thinkingLevel = minimal`.
    var supportsMinimalThinking: Bool {
        switch self {
        case .flash31: return true
        case .pro3: return false
        }
    }
}

/// Snapshot of user-configured Gemini endpoint settings.
struct LMGeminiModelSettings {
    var baseURL: String
    var apiKey: String
    var model: LMGeminiImageModel

    /// True when baseURL and apiKey are non-empty after trim.
    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/**
 Loads and saves Gemini Models page settings.

 - baseURL / selected model → UserDefaults
 - apiKey → Keychain (`KeychainAccess`, same service as device UUID)
 */
enum LMGeminiModelSettingsStore {

    private static let baseURLKey = "gemini_inspire_base_url"
    private static let modelKey = "gemini_inspire_model"
    private static let apiKeyKeychainKey = "com.processor.keychain.gemini_api_key"

    private static var keychain: Keychain {
        Keychain(service: "com.processor.keychain")
    }

    /// Current settings (defaults applied when unset).
    static func load() -> LMGeminiModelSettings {
        let rawBase = UserDefaults.standard.string(forKey: baseURLKey)
            ?? AppConfigs.Gemini.defaultBaseURL
        let modelRaw = UserDefaults.standard.string(forKey: modelKey)
            ?? LMGeminiImageModel.flash31.rawValue
        let model = LMGeminiImageModel(rawValue: modelRaw) ?? .flash31
        let apiKey = (try? keychain.getString(apiKeyKeychainKey)) ?? ""
        return LMGeminiModelSettings(
            baseURL: normalizeBaseURL(rawBase),
            apiKey: apiKey,
            model: model
        )
    }

    /// Persists validated settings. Caller should validate first.
    static func save(_ settings: LMGeminiModelSettings) {
        let base = normalizeBaseURL(settings.baseURL)
        UserDefaults.standard.set(base, forKey: baseURLKey)
        UserDefaults.standard.set(settings.model.rawValue, forKey: modelKey)
        let key = settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if key.isEmpty {
                try keychain.remove(apiKeyKeychainKey)
            } else {
                try keychain.set(key, key: apiKeyKeychainKey)
            }
        } catch {
            LMLogger.log("⚠️ Gemini apiKey Keychain save failed: \(error.localizedDescription)")
        }
        LMLogger.log("💾 Gemini model settings saved: model=\(settings.model.rawValue) baseURL=\(base)")
    }

    /// Whether Inspire Me direct path may start (baseURL + apiKey present).
    static var isConfigured: Bool {
        load().isConfigured
    }

    /**
     Validates Models page fields before save.

     - Returns: `nil` if valid; otherwise an error message suitable for toast / field error.
     */
    static func validate(
        baseURL: String,
        apiKey: String,
        model: LMGeminiImageModel
    ) -> String? {
        let trimmedBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBase.isEmpty else {
            return LMText.settings.modelsBaseURLRequired
        }
        guard let url = URL(string: trimmedBase),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              url.host != nil else {
            return LMText.settings.modelsBaseURLInvalid
        }
        guard !trimmedKey.isEmpty else {
            return LMText.settings.modelsAPIKeyRequired
        }
        _ = model
        return nil
    }

    /// Trims whitespace and trailing `/` from a host base URL.
    static func normalizeBaseURL(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    /**
     Whether a composition `taskId` is a local direct-Gemini session
     (skip Composition job polling / result reporting).
     */
    static func isLocalGeminiTaskId(_ taskId: String?) -> Bool {
        guard let taskId, !taskId.isEmpty else { return false }
        return taskId.hasPrefix("local_gemini_")
    }
}
