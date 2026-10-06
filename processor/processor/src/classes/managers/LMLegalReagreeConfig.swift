//
//  LMLegalReagreeConfig.swift
//  processor
//
//  Bundled Phase-1 legal re-agree configuration (ios-legal-reagree-spec.md).
//

import Foundation

/// Which legal document(s) are pending re-agree for the current binary.
enum LMLegalReagreePendingDocs: Equatable {
    case none
    case termsOnly
    case privacyOnly
    case both
}

/// Bundled `legal_reagree_config.json` payload.
struct LMLegalReagreeConfig: Equatable {
    let reagreeEnabled: Bool
    let termsAgreementId: String
    let privacyAgreementId: String
    let termsUrl: String
    let privacyUrl: String
    let summaryKey: String?
    let termsAgreementLabel: String?
    let privacyAgreementLabel: String?

    /// Loads and validates bundled config. Missing or invalid → `nil` (gate off).
    static func loadBundled() -> LMLegalReagreeConfig? {
        guard let data = readBundledData() else {
            LMLogger.log("⚠️ legal_reagree_config.json missing — re-agree gate off")
            return nil
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            LMLogger.log("⚠️ legal_reagree_config.json decode failed — re-agree gate off")
            return nil
        }

        let enabled = obj["reagreeEnabled"] as? Bool ?? false
        let termsId = Self.normalizeId(obj["termsAgreementId"] as? String)
        let privacyId = Self.normalizeId(obj["privacyAgreementId"] as? String)

        guard Self.isValidTermsId(termsId), Self.isValidPrivacyId(privacyId) else {
            LMLogger.log("⚠️ legalAgreementId invalid (terms=\(termsId), privacy=\(privacyId)) — re-agree gate off")
            return nil
        }

        let termsUrl = (obj["termsUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let privacyUrl = (obj["privacyUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)

        return LMLegalReagreeConfig(
            reagreeEnabled: enabled,
            termsAgreementId: termsId,
            privacyAgreementId: privacyId,
            termsUrl: (termsUrl?.isEmpty == false) ? termsUrl! : LMApi.Terms.service,
            privacyUrl: (privacyUrl?.isEmpty == false) ? privacyUrl! : LMApi.Terms.privacy,
            summaryKey: obj["summaryKey"] as? String,
            termsAgreementLabel: obj["termsAgreementLabel"] as? String,
            privacyAgreementLabel: obj["privacyAgreementLabel"] as? String
        )
    }

    /**
     Validates Terms id: `terms-YYYYMMDD-seq`.
     */
    static func isValidTermsId(_ id: String) -> Bool {
        guard id.count <= 64, !id.isEmpty else { return false }
        return id.range(of: #"^terms-[0-9]{8}-[0-9]{2}$"#, options: .regularExpression) != nil
    }

    /**
     Validates Privacy id: `privacy-YYYYMMDD-seq`.
     */
    static func isValidPrivacyId(_ id: String) -> Bool {
        guard id.count <= 64, !id.isEmpty else { return false }
        return id.range(of: #"^privacy-[0-9]{8}-[0-9]{2}$"#, options: .regularExpression) != nil
    }

    private static func normalizeId(_ raw: String?) -> String {
        (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func readBundledData() -> Data? {
        if let url = Bundle.main.url(forResource: "legal_reagree_config", withExtension: "json", subdirectory: "config"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = Bundle.main.url(forResource: "legal_reagree_config", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }
}
