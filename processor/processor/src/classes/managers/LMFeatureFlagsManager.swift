//
//  LMFeatureFlagsManager.swift
//  processor
//

import Foundation

/// Runtime feature flags persisted in UserDefaults (Android `FeatureFlagsManager` parity).
enum LMFeatureFlagsManager {

    static let didChangeNotification = Notification.Name("LMFeatureFlagsDidChange")

    private static let prefsKey = "backend_api_enabled"
    private static let neuralGeometricKey = "use_neural_geometric_scorers"
    private static let directGeminiKey = "inspire_me_direct_gemini_enabled"

    /// Master switch: `false` = offline demo mode; backend API calls are skipped.
    static var backendApiEnabled: Bool {
        UserDefaults.standard.bool(forKey: prefsKey)
    }

    /**
     When `true`, geometric scoring prefers PiDiNet + U2-Netp (with Vision fallback if models missing).

     Default `true`. Persisted under `use_neural_geometric_scorers`.
     */
    static var useNeuralGeometricScorers: Bool {
        UserDefaults.standard.bool(forKey: neuralGeometricKey)
    }

    /**
     When `true` (and backend API enabled), Inspire Me uses device → Gemini directly
     instead of Composition `/analyze` + job polling.

     Default `true` for internal BYOK builds (SPEC §13).
     */
    static var inspireMeDirectGeminiEnabled: Bool {
        UserDefaults.standard.bool(forKey: directGeminiKey)
    }

    /// Loads persisted flags. Call once at app launch.
    static func setup() {
        if UserDefaults.standard.object(forKey: prefsKey) == nil {
            UserDefaults.standard.set(false, forKey: prefsKey)
        }
        if UserDefaults.standard.object(forKey: neuralGeometricKey) == nil {
            UserDefaults.standard.set(true, forKey: neuralGeometricKey)
        }
        if UserDefaults.standard.object(forKey: directGeminiKey) == nil {
            UserDefaults.standard.set(true, forKey: directGeminiKey)
        }
        LMLogger.log(
            "Feature flags: backendApiEnabled=\(backendApiEnabled) " +
            "useNeuralGeometricScorers=\(useNeuralGeometricScorers) " +
            "inspireMeDirectGeminiEnabled=\(inspireMeDirectGeminiEnabled)"
        )
    }

    /// Persists and publishes the backend API master switch.
    static func setBackendApiEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: prefsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        LMLogger.log("Feature flags updated: backendApiEnabled=\(enabled)")
    }

    /// Persists and publishes the neural geometric scorer switch.
    static func setUseNeuralGeometricScorers(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: neuralGeometricKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        LMLogger.log("Feature flags updated: useNeuralGeometricScorers=\(enabled)")
    }

    /// Persists and publishes the direct-Gemini Inspire Me switch.
    static func setInspireMeDirectGeminiEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: directGeminiKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        LMLogger.log("Feature flags updated: inspireMeDirectGeminiEnabled=\(enabled)")
    }
}
