//
//  LMGeminiModelSettingsStore.swift
//  processor
//
//  Persists Gemini BYOK settings for Inspire Me (baseURL / model / apiKey).
//  Thin facade over LMLlmModuleSettingsStore.ideaInspiration for call-site compatibility.
//

import Foundation

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
        let feature = LMGeminiInspireConfigRepository.shared.get()
        switch self {
        case .flash31: return feature.flashTimeoutSec
        case .pro3: return feature.proTimeoutSec
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
 Loads and saves Gemini Models page settings via `LMLlmModuleSettingsStore`.
 */
enum LMGeminiModelSettingsStore {

    /// Current settings (defaults applied when unset).
    static func load() -> LMGeminiModelSettings {
        let idea = LMLlmModuleSettingsStore.loadIdeaInspiration()
        return LMGeminiModelSettings(
            baseURL: idea.baseURL,
            apiKey: idea.apiKey,
            model: idea.model
        )
    }

    /// Persists validated settings. Caller should validate first.
    static func save(_ settings: LMGeminiModelSettings) {
        LMLlmModuleSettingsStore.saveIdeaInspiration(
            LMIdeaInspirationSettings(
                baseURL: settings.baseURL,
                apiKey: settings.apiKey,
                model: settings.model
            )
        )
    }

    /// Whether Inspire Me direct path may start (baseURL + apiKey present).
    static var isConfigured: Bool {
        LMLlmModuleSettingsStore.isConfigured(.ideaInspiration)
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
        LMLlmModuleSettingsStore.normalizeBaseURL(raw)
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
