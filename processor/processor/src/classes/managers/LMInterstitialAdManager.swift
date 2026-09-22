//
//  LMInterstitialAdManager.swift
//  processor
//

import UIKit

/**
 Preloads and presents one interstitial per loading placement.

 If no creative is ready, `showIfAvailable` finishes immediately so loading UI is never blocked.
 Close timing is left to the Google SDK.
 */
final class LMInterstitialAdManager: LMInterstitialAdEventSinking {

    static let shared = LMInterstitialAdManager()

    private let policy: LMInterstitialAdPolicyEvaluating
    private let loader: LMInterstitialAdLoading
    private let adsBootstrap: LMMobileAdsBootstrapping
    private let expirationInterval: TimeInterval = 3_600

    private var slots: [LMInterstitialPlacement: Slot] = [:]

    /**
     - Parameters:
       - policy: Unit-ID gate.
       - loader: Google loader by default.
       - adsBootstrap: SDK start gate.
     */
    init(
        policy: LMInterstitialAdPolicyEvaluating = LMInterstitialAdPolicy(),
        loader: LMInterstitialAdLoading = LMGoogleInterstitialAdLoader(),
        adsBootstrap: LMMobileAdsBootstrapping = LMMobileAdsBootstrap.shared
    ) {
        self.policy = policy
        self.loader = loader
        self.adsBootstrap = adsBootstrap
    }

    /// Preloads Find Spot and suggestion-loading units after the SDK is ready.
    func preloadAll() {
        preloadIfNeeded(.findSpot)
        preloadIfNeeded(.suggestionLoading)
    }

    /**
     Loads a placement when policy allows and the cached ad is missing or expired.
     */
    func preloadIfNeeded(_ placement: LMInterstitialPlacement) {
        guard policy.shouldAttemptInterstitial(for: placement) else { return }
        let slot = slot(for: placement)
        guard !slot.isAdAvailable(expiration: expirationInterval) else { return }
        guard !slot.isLoading else { return }
        startLoad(placement)
    }

    /**
     Presents immediately when a creative is ready; otherwise invokes `onFinished` once and preloads.

     - Parameters:
       - placement: Which loading surface requested the ad.
       - viewController: Camera page still on screen.
       - onFinished: Called exactly once (dismiss, fail, skip, or cancel).
     */
    func showIfAvailable(
        _ placement: LMInterstitialPlacement,
        from viewController: UIViewController,
        onFinished: @escaping () -> Void
    ) {
        let slot = slot(for: placement)
        guard !slot.isShowing else {
            LMLogger.log("Interstitial already showing placement=\(placement.rawValue) — skip this attempt")
            onFinished()
            return
        }
        slot.pendingFinished = onFinished

        guard policy.shouldAttemptInterstitial(for: placement) else {
            finish(placement, reason: "policy denied")
            return
        }
        guard viewController.viewIfLoaded?.window != nil else {
            finish(placement, reason: "presenter not in window")
            return
        }
        guard slot.isAdAvailable(expiration: expirationInterval), let handle = slot.loadedHandle else {
            finish(placement, reason: "not ready — skip")
            preloadIfNeeded(placement)
            return
        }

        handle.placement = placement
        handle.eventSink = self
        slot.isShowing = true
        slot.loadedHandle = nil
        slot.loadTime = nil
        LMLogger.log("Interstitial presenting placement=\(placement.rawValue)")
        if !handle.present(from: viewController) {
            slot.isShowing = false
            finish(placement, reason: "canPresent rejected")
            preloadIfNeeded(placement)
        }
    }

    /**
     Drops a not-yet-presented attempt so a later dismiss cannot fire a stale callback.

     Does not force-close an ad the SDK is already showing; that close stays with the user.
     */
    func cancelIfNotShowing(_ placement: LMInterstitialPlacement) {
        let slot = slot(for: placement)
        guard !slot.isShowing else {
            LMLogger.log("Interstitial cancel ignored — already on screen (\(placement.rawValue))")
            return
        }
        finish(placement, reason: "cancelled before present")
    }

    // MARK: - LMInterstitialAdEventSinking

    func interstitialDidDismiss(placement: LMInterstitialPlacement) {
        slot(for: placement).isShowing = false
        finish(placement, reason: "dismissed")
        preloadIfNeeded(placement)
    }

    func interstitialDidFailToPresent(placement: LMInterstitialPlacement, error: Error) {
        slot(for: placement).isShowing = false
        finish(placement, reason: "present failed: \(error.localizedDescription)")
        preloadIfNeeded(placement)
    }

    // MARK: - Private

    private func slot(for placement: LMInterstitialPlacement) -> Slot {
        if let existing = slots[placement] {
            return existing
        }
        let created = Slot()
        slots[placement] = created
        return created
    }

    private func startLoad(_ placement: LMInterstitialPlacement) {
        let slot = slot(for: placement)
        slot.isLoading = true
        let unit = placement.adUnitID
        adsBootstrap.whenReady { [weak self] in
            guard let self else { return }
            Task {
                do {
                    let handle = try await self.loader.load(adUnitID: unit)
                    await MainActor.run {
                        slot.isLoading = false
                        slot.loadedHandle = handle
                        slot.loadTime = Date()
                        LMLogger.log("Interstitial loaded placement=\(placement.rawValue)")
                    }
                } catch {
                    await MainActor.run {
                        slot.isLoading = false
                        LMLogger.log("Interstitial load failed placement=\(placement.rawValue): \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func finish(_ placement: LMInterstitialPlacement, reason: String) {
        let slot = slot(for: placement)
        let callback = slot.pendingFinished
        slot.pendingFinished = nil
        LMLogger.log("Interstitial finished placement=\(placement.rawValue) reason=\(reason)")
        callback?()
    }
}

private final class Slot {
    var loadedHandle: (any LMInterstitialAdHandle)?
    var loadTime: Date?
    var isLoading = false
    var isShowing = false
    var pendingFinished: (() -> Void)?

    func isAdAvailable(expiration: TimeInterval) -> Bool {
        guard loadedHandle != nil, let loadTime else { return false }
        return Date().timeIntervalSince(loadTime) < expiration
    }
}
