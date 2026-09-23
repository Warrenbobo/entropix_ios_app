//
//  LMLlmCallQuotaStore.swift
//  processor
//
//  Per-module local LLM call quotas (Scene Explore / Inspire / AR Guidance).
//

import Foundation

/**
 Tracks remaining external LLM calls per `LMLlmFeatureModule`.

 Seeded from `AppConfigs.llmCallQuotaInitial` on first launch (missing UserDefaults keys only).
 Not shown in UI; entry points reuse `presentMissingModelConfig` when exhausted.
 */
enum LMLlmCallQuotaStore {

    private static let keyPrefix = "llm_call_quota_"

    /// Seeds missing keys with `AppConfigs.llmCallQuotaInitial`. Call once at launch.
    static func setup() {
        for module in LMLlmFeatureModule.allCases {
            let key = storageKey(for: module)
            if UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(AppConfigs.llmCallQuotaInitial, forKey: key)
            }
        }
        LMLogger.log(
            "LLM call quota ready: scene=\(remaining(for: .sceneExplore)) " +
            "inspire=\(remaining(for: .ideaInspiration)) " +
            "ar=\(remaining(for: .arGuidance)) initial=\(AppConfigs.llmCallQuotaInitial)"
        )
    }

    /// Remaining calls for `module` (never negative).
    static func remaining(for module: LMLlmFeatureModule) -> Int {
        max(0, UserDefaults.standard.integer(forKey: storageKey(for: module)))
    }

    /// `true` when at least one call remains.
    static func hasRemaining(for module: LMLlmFeatureModule) -> Bool {
        remaining(for: module) > 0
    }

    /**
     Decrements remaining by 1 when possible.

     - Returns: `true` if a call was consumed; `false` if already exhausted.
     */
    @discardableResult
    static func consume(for module: LMLlmFeatureModule) -> Bool {
        let key = storageKey(for: module)
        let current = UserDefaults.standard.integer(forKey: key)
        guard current > 0 else {
            LMLogger.log("LLM quota exhausted module=\(module.rawValue)")
            return false
        }
        let next = current - 1
        UserDefaults.standard.set(next, forKey: key)
        LMLogger.log("LLM quota consume module=\(module.rawValue) remaining=\(next)")
        return true
    }

    private static func storageKey(for module: LMLlmFeatureModule) -> String {
        keyPrefix + module.rawValue
    }
}
