//
//  LMGoogleAppOpenAdLoader.swift
//  processor
//

import Foundation
import GoogleMobileAds
import UIKit

/// Google Mobile Ads implementation of `LMAppOpenAdLoading` (Dependency Inversion: swappable).
final class LMGoogleAppOpenAdLoader: LMAppOpenAdLoading {

    /**
     Loads an App Open creative via `AppOpenAd.load`.

     - Parameter adUnitID: AdMob App Open unit ID.
     - Returns: A handle that can present without exposing `AppOpenAd` to callers.
     */
    func load(adUnitID: String) async throws -> any LMAppOpenAdHandle {
        try await withCheckedThrowingContinuation { continuation in
            AppOpenAd.load(with: adUnitID, request: Request()) { ad, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let ad else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "LMGoogleAppOpenAdLoader",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "App Open load returned nil ad"]
                        )
                    )
                    return
                }
                continuation.resume(returning: LMGoogleAppOpenAdHandle(ad: ad))
            }
        }
    }
}

/// Wraps `AppOpenAd` and forwards full-screen callbacks to `eventSink`.
final class LMGoogleAppOpenAdHandle: NSObject, LMAppOpenAdHandle, FullScreenContentDelegate {

    private let ad: AppOpenAd

    weak var eventSink: LMAppOpenAdFullScreenEventSinking?

    /**
     Creates a handle around a loaded Google App Open ad.

     - Parameter ad: Loaded `AppOpenAd` instance.
     */
    init(ad: AppOpenAd) {
        self.ad = ad
        super.init()
        ad.fullScreenContentDelegate = self
    }

    /**
     Presents the wrapped App Open ad from `viewController`.

     - Returns: `false` when `canPresent` fails (does not call the SDK present).
     */
    func present(from viewController: UIViewController) -> Bool {
        do {
            try ad.canPresent(from: viewController)
        } catch {
            LMLogger.log("App Open canPresent failed: \(error.localizedDescription)")
            return false
        }
        ad.present(from: viewController)
        return true
    }

    // MARK: - FullScreenContentDelegate

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        LMLogger.log("App Open dismissed")
        eventSink?.appOpenAdDidDismiss()
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        LMLogger.log("App Open failed to present: \(error.localizedDescription)")
        eventSink?.appOpenAdDidFailToPresent(error: error)
    }

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        LMLogger.log("App Open will present")
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        LMLogger.log("App Open impression")
    }
}
