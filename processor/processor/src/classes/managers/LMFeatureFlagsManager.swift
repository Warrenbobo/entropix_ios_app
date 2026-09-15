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

    /**
     FramAist backend master switch — **hard-disabled**.

     Always `false` so login / composition upload / guest auth stay unreachable.
     Implementation kept for future re-enable.
     */
    static var backendApiEnabled: Bool {
        false
    }

    /**
     When `true`, geometric scoring prefers PiDiNet + U2-Netp (with Vision fallback if models missing).

     Default `true`. Persisted under `use_neural_geometric_scorers`.
     */
    static var useNeuralGeometricScorers: Bool {
        UserDefaults.standard.bool(forKey: neuralGeometricKey)
    }

    /**
     When `true`, Inspire Me uses device → Gemini directly
     instead of Composition `/analyze` + job polling.

     Default `true` for internal BYOK builds (SPEC §13).
     */
    static var inspireMeDirectGeminiEnabled: Bool {
        UserDefaults.standard.bool(forKey: directGeminiKey)
    }

    /// Loads persisted flags. Call once at app launch.
    static func setup() {
        // FRAMAIST_BACKEND_DISABLED — always force off.
        UserDefaults.standard.set(false, forKey: prefsKey)
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

    /**
     No-op while FramAist backend is disabled.

     Keeps call sites compiling; always persists `false`.
     */
    static func setBackendApiEnabled(_ enabled: Bool) {
        // FRAMAIST_BACKEND_DISABLED
        _ = enabled
        UserDefaults.standard.set(false, forKey: prefsKey)
        NotificationCenter.default.post(name: didChangeNotification, object: nil)
        LMLogger.log("Feature flags: setBackendApiEnabled ignored — backend hard-disabled")
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
