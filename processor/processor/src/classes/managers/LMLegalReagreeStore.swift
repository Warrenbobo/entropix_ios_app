//
//  LMLegalReagreeStore.swift
//  processor
//
//  Local persistence + launch prepare for legal re-agree (ios-legal-reagree-spec.md).
//

import Foundation

/// UserDefaults-backed store for per-document Terms / Privacy agreement state.
enum LMLegalReagreeStore {

    private static let hasAgreedTermsKey = "legalReagree.hasAgreedTerms"
    private static let boundTermsIdKey = "legalReagree.boundTermsAgreementId"
    private static let hasAgreedPrivacyKey = "legalReagree.hasAgreedPrivacy"
    private static let boundPrivacyIdKey = "legalReagree.boundPrivacyAgreementId"
    private static let didMigrateFromLegacyKey = "legalReagree.didMigrateFromLegacyPrivacy"
    /// Same key as `LMLaunchSplashPage` first-install privacy gate.
    private static let legacyPrivacyPermissionKey = "hasAgreedPrivacyPermission"

    // MARK: - Launch

    /**
     Applies §4.3 / §6: optional legacy migration, then bind/reset per document id.

     - Returns: Pending docs that still need the re-agree UI, or `.none` to skip.
     */
    @discardableResult
    static func prepareForLaunch(config: LMLegalReagreeConfig?) -> LMLegalReagreePendingDocs {
        guard let config, config.reagreeEnabled else {
            return .none
        }

        migrateFromLegacyPrivacyIfNeeded(config: config)
        applyIdBindings(config: config)

        let termsOK = isTermsOK(config: config)
        let privacyOK = isPrivacyOK(config: config)

        if termsOK && privacyOK {
            return .none
        }
        if !termsOK && !privacyOK {
            return .both
        }
        if !termsOK {
            return .termsOnly
        }
        return .privacyOnly
    }

    /// Persists Agree for **both** current config ids (§4.2 / D4).
    static func markAgreedToCurrentConfig(_ config: LMLegalReagreeConfig) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: hasAgreedTermsKey)
        defaults.set(config.termsAgreementId, forKey: boundTermsIdKey)
        defaults.set(true, forKey: hasAgreedPrivacyKey)
        defaults.set(config.privacyAgreementId, forKey: boundPrivacyIdKey)
        defaults.set(true, forKey: didMigrateFromLegacyKey)
        // Dual-write legacy first-install key (SPEC D1).
        defaults.set(true, forKey: legacyPrivacyPermissionKey)
        defaults.synchronize()
        LMLogger.log(
            "✅ Legal re-agree saved terms=\(config.termsAgreementId) privacy=\(config.privacyAgreementId)"
        )
    }

    // MARK: - Internals

    private static func isTermsOK(config: LMLegalReagreeConfig) -> Bool {
        let defaults = UserDefaults.standard
        let bound = normalize(defaults.string(forKey: boundTermsIdKey))
        let agreed = defaults.bool(forKey: hasAgreedTermsKey)
        return agreed && bound == config.termsAgreementId
    }

    private static func isPrivacyOK(config: LMLegalReagreeConfig) -> Bool {
        let defaults = UserDefaults.standard
        let bound = normalize(defaults.string(forKey: boundPrivacyIdKey))
        let agreed = defaults.bool(forKey: hasAgreedPrivacyKey)
        return agreed && bound == config.privacyAgreementId
    }

    /**
     First feature binary: users who already passed legacy privacy are treated as
     agreed for the **current** baseline ids (no unexpected re-prompt).
     */
    private static func migrateFromLegacyPrivacyIfNeeded(config: LMLegalReagreeConfig) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didMigrateFromLegacyKey) else { return }
        guard defaults.bool(forKey: legacyPrivacyPermissionKey) else { return }

        defaults.set(true, forKey: hasAgreedTermsKey)
        defaults.set(config.termsAgreementId, forKey: boundTermsIdKey)
        defaults.set(true, forKey: hasAgreedPrivacyKey)
        defaults.set(config.privacyAgreementId, forKey: boundPrivacyIdKey)
        defaults.set(true, forKey: didMigrateFromLegacyKey)
        defaults.synchronize()
        LMLogger.log(
            "✅ Legal re-agree migrated from legacy privacy → terms=\(config.termsAgreementId) privacy=\(config.privacyAgreementId)"
        )
    }

    /// Bind / reset each document when config id ≠ bound id (§4.3).
    private static func applyIdBindings(config: LMLegalReagreeConfig) {
        let defaults = UserDefaults.standard

        let boundTerms = normalize(defaults.string(forKey: boundTermsIdKey))
        if boundTerms.isEmpty || boundTerms != config.termsAgreementId {
            defaults.set(false, forKey: hasAgreedTermsKey)
            defaults.set(config.termsAgreementId, forKey: boundTermsIdKey)
            LMLogger.log("📋 Legal Terms requirement bound to \(config.termsAgreementId) (needs agree)")
        }

        let boundPrivacy = normalize(defaults.string(forKey: boundPrivacyIdKey))
        if boundPrivacy.isEmpty || boundPrivacy != config.privacyAgreementId {
            defaults.set(false, forKey: hasAgreedPrivacyKey)
            defaults.set(config.privacyAgreementId, forKey: boundPrivacyIdKey)
            LMLogger.log("📋 Legal Privacy requirement bound to \(config.privacyAgreementId) (needs agree)")
        }

        defaults.synchronize()
    }

    private static func normalize(_ raw: String?) -> String {
        (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
