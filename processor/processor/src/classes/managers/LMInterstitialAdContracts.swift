//
//  LMInterstitialAdContracts.swift
//  processor
//

import UIKit

/// Loading surfaces that may present a dismissible interstitial.
enum LMInterstitialPlacement: String {
    /// Find Spot freeze overlay (`.sceneExploreProcessing`).
    case findSpot
    /// Show Suggestions cards while `ready != true`.
    case suggestionLoading

    /// Demo / study ad unit for this placement.
    var adUnitID: String {
        switch self {
        case .findSpot:
            return AppConfigs.GoogleAdConfigs.findSpotInterstitialAdId
        case .suggestionLoading:
            return AppConfigs.GoogleAdConfigs.suggestionLoadingInterstitialAdId
        }
    }
}

/// Decides whether a placement may load or show.
protocol LMInterstitialAdPolicyEvaluating {
    /**
     - Parameter placement: Find Spot or suggestion-card loading.
     - Returns: `false` when the unit ID is empty.
     */
    func shouldAttemptInterstitial(for placement: LMInterstitialPlacement) -> Bool
}

/**
 Default policy: empty unit IDs skip the ad.

 FramAist backend being disabled does not block interstitials.
 */
struct LMInterstitialAdPolicy: LMInterstitialAdPolicyEvaluating {
    func shouldAttemptInterstitial(for placement: LMInterstitialPlacement) -> Bool {
        guard AppConfigs.GoogleAdConfigs.adsEnabled else {
            LMLogger.log("Interstitial skipped — adsEnabled=false (\(placement.rawValue))")
            return false
        }
        let unit = placement.adUnitID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !unit.isEmpty else {
            LMLogger.log("Interstitial skipped — empty unit (\(placement.rawValue))")
            return false
        }
        return true
    }
}

/// Opaque loaded interstitial. Callers never import GoogleMobileAds.
protocol LMInterstitialAdHandle: AnyObject {
    /**
     Presents the full-screen ad. Close control is owned by the SDK.

     - Returns: `false` when the SDK refuses to present.
     */
    func present(from viewController: UIViewController) -> Bool
    /// Receives dismiss / present-fail events.
    var eventSink: LMInterstitialAdEventSinking? { get set }
    /// Which loading surface this creative is about to cover.
    var placement: LMInterstitialPlacement? { get set }
}

/// Full-screen lifecycle for one interstitial attempt.
protocol LMInterstitialAdEventSinking: AnyObject {
    /// User or system dismissed the ad (close is available only when the SDK allows it).
    func interstitialDidDismiss(placement: LMInterstitialPlacement)
    /// Presentation failed before the user could close it.
    func interstitialDidFailToPresent(placement: LMInterstitialPlacement, error: Error)
}

/// Loads one interstitial creative.
protocol LMInterstitialAdLoading: AnyObject {
    /**
     - Parameter adUnitID: AdMob interstitial unit.
     - Throws: SDK or network errors.
     */
    func load(adUnitID: String) async throws -> any LMInterstitialAdHandle
}
