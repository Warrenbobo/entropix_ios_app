//
//  LMGoogleInterstitialAdLoader.swift
//  processor
//

import Foundation
import GoogleMobileAds
import UIKit

/// Google Mobile Ads implementation of `LMInterstitialAdLoading`.
final class LMGoogleInterstitialAdLoader: LMInterstitialAdLoading {

    /**
     Loads an interstitial via `InterstitialAd.load`.

     - Parameter adUnitID: AdMob interstitial unit ID.
     */
    func load(adUnitID: String) async throws -> any LMInterstitialAdHandle {
        try await withCheckedThrowingContinuation { continuation in
            InterstitialAd.load(with: adUnitID, request: Request()) { ad, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let ad else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "LMGoogleInterstitialAdLoader",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Interstitial load returned nil ad"]
                        )
                    )
                    return
                }
                continuation.resume(returning: LMGoogleInterstitialAdHandle(ad: ad))
            }
        }
    }
}

/// Wraps `InterstitialAd` and forwards dismiss / fail to `eventSink`.
final class LMGoogleInterstitialAdHandle: NSObject, LMInterstitialAdHandle, FullScreenContentDelegate {

    private let ad: InterstitialAd
    /// Set by the coordinator before present so callbacks know which slot finished.
    var placement: LMInterstitialPlacement?

    weak var eventSink: LMInterstitialAdEventSinking?

    /**
     - Parameter ad: Loaded Google interstitial.
     */
    init(ad: InterstitialAd) {
        self.ad = ad
        super.init()
        ad.fullScreenContentDelegate = self
    }

    func present(from viewController: UIViewController) -> Bool {
        do {
            try ad.canPresent(from: viewController)
        } catch {
            LMLogger.log("Interstitial canPresent failed: \(error.localizedDescription)")
            return false
        }
        ad.present(from: viewController)
        return true
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard let placement else { return }
        LMLogger.log("Interstitial dismissed placement=\(placement.rawValue)")
        eventSink?.interstitialDidDismiss(placement: placement)
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        guard let placement else { return }
        LMLogger.log("Interstitial present failed placement=\(placement.rawValue): \(error.localizedDescription)")
        eventSink?.interstitialDidFailToPresent(placement: placement, error: error)
    }
}
