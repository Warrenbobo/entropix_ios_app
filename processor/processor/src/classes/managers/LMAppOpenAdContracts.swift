//
//  LMAppOpenAdContracts.swift
//  processor
//

import UIKit

// MARK: - Configuration (Dependency Inversion)

/// Supplies App Open placement settings without coupling callers to `AppConfigs`.
protocol LMAppOpenAdConfiguring {
    /// AdMob App Open ad unit ID.
    var adUnitID: String { get }
    /// Maximum age of a loaded ad before it is discarded (Google: ~4 hours).
    var expirationInterval: TimeInterval { get }
    /// How long splash may wait for a load before skipping into Camera.
    var presentWaitTimeout: TimeInterval { get }
}

/// Default configuration backed by `AppConfigs.GoogleAdConfigs`.
struct LMAppOpenAdConfiguration: LMAppOpenAdConfiguring {
    var adUnitID: String { AppConfigs.GoogleAdConfigs.appOpenAdId }
    var expirationInterval: TimeInterval { 4 * 3_600 }
    /// Cold start + first AdMob request often exceeds 5s; keep splash long enough to show the ad.
    var presentWaitTimeout: TimeInterval { 15 }
}

// MARK: - Policy (Open/Closed)

/// Decides whether App Open may run for the current session/user.
protocol LMAppOpenAdPolicyEvaluating {
    /// Returns `true` when an App Open attempt is allowed.
    func shouldAttemptAppOpenAd() -> Bool
}

/**
 Default policy: skip empty unit IDs.

 Offline demo does **not** block App Open — demo units do not require FramAist backend.
 Product can later suppress for Plus / Lifelong via additional rules (OCP).
 */
struct LMAppOpenAdPolicy: LMAppOpenAdPolicyEvaluating {
    func shouldAttemptAppOpenAd() -> Bool {
        guard AppConfigs.GoogleAdConfigs.adsEnabled else {
            LMLogger.log("App Open skipped — adsEnabled=false")
            return false
        }
        let unit = AppConfigs.GoogleAdConfigs.appOpenAdId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !unit.isEmpty else {
            LMLogger.log("App Open skipped — empty ad unit ID")
            return false
        }
        return true
    }
}

// MARK: - Load / present abstractions (Interface Segregation + DIP)

/// Opaque loaded creative; UI never imports GoogleMobileAds through this type.
protocol LMAppOpenAdHandle: AnyObject {
    /**
     Presents the full-screen App Open ad from `viewController`.

     - Returns: `false` when the SDK reports the ad cannot be presented (caller should finish/skip).
     */
    func present(from viewController: UIViewController) -> Bool
    /// Forwards full-screen lifecycle events to the coordinator.
    var eventSink: LMAppOpenAdFullScreenEventSinking? { get set }
}

/// Full-screen lifecycle sink for a loaded App Open handle.
protocol LMAppOpenAdFullScreenEventSinking: AnyObject {
    /// Called when the ad was dismissed by the user or system.
    func appOpenAdDidDismiss()
    /// Called when presentation failed.
    func appOpenAdDidFailToPresent(error: Error)
}

/// Loads App Open creatives (Single Responsibility: network/SDK load only).
protocol LMAppOpenAdLoading: AnyObject {
    /**
     Loads an App Open ad for `adUnitID`.

     - Throws: underlying SDK / network errors.
     */
    func load(adUnitID: String) async throws -> any LMAppOpenAdHandle
}

// MARK: - Public facade for splash (ISP)

/// Splash-facing App Open API: preload and gated present before Camera.
protocol LMAppOpenAdServing: AnyObject {
    /// Starts a background load when policy allows and no valid ad is ready.
    func preloadIfNeeded()
    /**
     Presents an App Open ad only while `splash` is still the visible launch surface.

     Always invokes `onFinished` exactly once (dismiss, fail, timeout, or skip)
     so the caller can enter Camera.
     */
    func showIfAvailable(from splash: UIViewController, onFinished: @escaping () -> Void)
}
