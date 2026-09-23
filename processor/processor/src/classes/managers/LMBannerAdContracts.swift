//
//  LMBannerAdContracts.swift
//  processor
//

import UIKit

// MARK: - Configuration (Dependency Inversion)

/// Supplies Banner placement settings without coupling callers to `AppConfigs`.
protocol LMBannerAdConfiguring {
    /// AdMob Banner ad unit ID.
    var adUnitID: String { get }
}

/// Default configuration backed by `AppConfigs.GoogleAdConfigs`.
struct LMBannerAdConfiguration: LMBannerAdConfiguring {
    var adUnitID: String { AppConfigs.GoogleAdConfigs.bannerAdId }
}

// MARK: - Policy (Open/Closed)

/// Decides whether a Mine banner may run.
protocol LMBannerAdPolicyEvaluating {
    /// Returns `true` when a banner load/show attempt is allowed.
    func shouldShowBannerAd() -> Bool
}

/**
 Default policy: skip empty unit IDs.

 Product can later suppress for Plus / Lifelong here without changing the host (OCP).
 */
struct LMBannerAdPolicy: LMBannerAdPolicyEvaluating {
    func shouldShowBannerAd() -> Bool {
        guard AppConfigs.GoogleAdConfigs.adsEnabled else {
            LMLogger.log("Banner skipped — adsEnabled=false")
            return false
        }
        let unit = AppConfigs.GoogleAdConfigs.bannerAdId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !unit.isEmpty else {
            LMLogger.log("Banner skipped — empty ad unit ID")
            return false
        }
        return true
    }
}

// MARK: - Host facade (ISP)

/// Notifies Mine about banner load outcomes so layout can react.
protocol LMBannerAdHostDelegate: AnyObject {
    /// Called when a banner creative is ready; `adHeight` is the rendered height in points.
    func bannerAdHost(_ host: LMBannerAdHosting, didReceiveAdWithHeight adHeight: CGFloat)
    /// Called when load fails; Mine should collapse the banner container.
    func bannerAdHost(_ host: LMBannerAdHosting, didFailWithError error: Error)
}

/// Hosts an anchored adaptive banner inside a container owned by Mine.
protocol LMBannerAdHosting: AnyObject {
    var delegate: LMBannerAdHostDelegate? { get set }

    /**
     Installs and loads a banner into `container`.

     Caller owns container layout (leading/trailing/bottom). Host manages the
     internal `BannerView` and reports height via `delegate`.
     */
    func installBanner(in container: UIView, rootViewController: UIViewController)

    /// Tears down the banner view and cancels pending loads.
    func removeBanner()

    /**
     Updates anchored adaptive size when the container width changes (rotation / size class).

     - Parameter containerWidth: Width available for the banner in points.
     */
    func updateAdaptiveSizeIfNeeded(containerWidth: CGFloat)
}
