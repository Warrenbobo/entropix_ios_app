//
//  LMAppOpenAdManager.swift
//  processor
//

import UIKit

/**
 Coordinates App Open preload / gated present between splash and Camera.

 Depends on abstractions (`LMAppOpenAdConfiguring`, `LMAppOpenAdPolicyEvaluating`,
 `LMAppOpenAdLoading`) so Google SDK details stay behind the loader (SOLID).
 */
final class LMAppOpenAdManager: LMAppOpenAdServing {

    static let shared = LMAppOpenAdManager()

    private let configuration: LMAppOpenAdConfiguring
    private let policy: LMAppOpenAdPolicyEvaluating
    private let loader: LMAppOpenAdLoading
    private let adsBootstrap: LMMobileAdsBootstrapping

    private var loadedHandle: (any LMAppOpenAdHandle)?
    private var loadTime: Date?
    private var isLoading = false
    private var isShowing = false
    private var hasFinishedCurrentAttempt = false
    private var loadAttemptCount = 0
    private var pendingFinished: (() -> Void)?
    private var presentWaitWorkItem: DispatchWorkItem?
    private weak var waitingSplash: UIViewController?

    /**
     - Parameters:
       - configuration: Ad unit and timeouts.
       - policy: Whether ads may run.
       - loader: Creative loader (defaults to Google).
       - adsBootstrap: SDK start gate (defaults to shared bootstrap).
     */
    init(
        configuration: LMAppOpenAdConfiguring = LMAppOpenAdConfiguration(),
        policy: LMAppOpenAdPolicyEvaluating = LMAppOpenAdPolicy(),
        loader: LMAppOpenAdLoading = LMGoogleAppOpenAdLoader(),
        adsBootstrap: LMMobileAdsBootstrapping = LMMobileAdsBootstrap.shared
    ) {
        self.configuration = configuration
        self.policy = policy
        self.loader = loader
        self.adsBootstrap = adsBootstrap
    }

    // MARK: - LMAppOpenAdServing

    /// Preloads when policy allows and no non-expired ad is ready.
    func preloadIfNeeded() {
        guard policy.shouldAttemptAppOpenAd() else { return }
        guard !isAdAvailable else { return }
        guard !isLoading else { return }
        startLoad(isRetry: false)
    }

    /**
     Shows App Open only while `splash` remains the launch surface; then finishes once.

     - Parameters:
       - splash: Launch page still on screen (before Camera).
       - onFinished: Enter Camera / home; invoked exactly once.
     */
    func showIfAvailable(from splash: UIViewController, onFinished: @escaping () -> Void) {
        let begin: () -> Void = { [weak self] in
            guard let self else {
                onFinished()
                return
            }

            self.cancelPresentWait()
            self.hasFinishedCurrentAttempt = false
            self.loadAttemptCount = 0
            self.pendingFinished = onFinished
            self.waitingSplash = splash

            guard self.policy.shouldAttemptAppOpenAd() else {
                self.finishAttempt(reason: "policy denied")
                return
            }

            guard self.isSplashStillLaunchSurface(splash) else {
                self.finishAttempt(reason: "Camera/home already visible — skip App Open")
                return
            }

            if self.isShowing {
                LMLogger.log("App Open already showing — wait for dismiss")
                return
            }

            if self.isAdAvailable {
                self.presentLoadedAd(from: splash)
                return
            }

            self.startLoad(isRetry: false)
            let timeout = self.configuration.presentWaitTimeout
            LMLogger.log("App Open waiting up to \(timeout)s for creative…")
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard !self.hasFinishedCurrentAttempt, !self.isShowing else { return }
                if self.isAdAvailable, self.isSplashStillLaunchSurface(splash) {
                    self.presentLoadedAd(from: splash)
                } else {
                    self.finishAttempt(reason: "present wait timeout (\(timeout)s)")
                    self.preloadIfNeeded()
                }
            }
            self.presentWaitWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: work)
        }

        // Ensure splash has joined the window hierarchy before gating (viewDidLoad is too early).
        DispatchQueue.main.async {
            begin()
        }
    }

    // MARK: - Private

    private var isAdAvailable: Bool {
        guard loadedHandle != nil, let loadTime else { return false }
        return Date().timeIntervalSince(loadTime) < configuration.expirationInterval
    }

    /**
     Ensures we only show App Open before the first page (Camera) appears.

     Prefer root-controller identity over `view.window` so a deferred gate still works
     immediately after `makeKeyAndVisible`.
     */
    private func isSplashStillLaunchSurface(_ splash: UIViewController) -> Bool {
        guard let root = LMPackageManager.window?.rootViewController else {
            LMLogger.log("App Open gate: no window root yet")
            return false
        }

        if root === splash {
            return true
        }
        if let nav = root as? UINavigationController,
           nav.viewControllers.contains(where: { $0 === splash }) {
            return true
        }

        // Home root is `LMNavigationWrapper` + `LMCameraPage` (or legacy tab root).
        if root is LMMainRootPage {
            return false
        }
        if let nav = root as? LMNavigationWrapper,
           nav.viewControllers.contains(where: { $0 is LMCameraPage }) {
            return false
        }

        LMLogger.log("App Open gate: unexpected root=\(type(of: root))")
        return false
    }

    private func startLoad(isRetry: Bool) {
        guard !isLoading else { return }
        guard !isAdAvailable else { return }

        isLoading = true
        loadAttemptCount += 1
        let unitID = configuration.adUnitID
        let attempt = loadAttemptCount
        LMLogger.log("App Open loading unit=\(unitID) attempt=\(attempt) retry=\(isRetry)")

        adsBootstrap.whenReady { [weak self] in
            guard let self else { return }
            Task { [weak self] in
                guard let self else { return }
                do {
                    let handle = try await self.loader.load(adUnitID: unitID)
                    await MainActor.run {
                        self.isLoading = false
                        handle.eventSink = self
                        self.loadedHandle = handle
                        self.loadTime = Date()
                        LMLogger.log("App Open loaded (attempt=\(attempt))")

                        if let splash = self.presenterSplashIfWaiting(),
                           !self.hasFinishedCurrentAttempt,
                           !self.isShowing,
                           self.isAdAvailable {
                            self.cancelPresentWait()
                            self.presentLoadedAd(from: splash)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isLoading = false
                        self.loadedHandle = nil
                        self.loadTime = nil
                        LMLogger.log("App Open load failed (attempt=\(attempt)): \(error.localizedDescription)")

                        // One automatic retry while splash is still waiting.
                        if !self.hasFinishedCurrentAttempt,
                           self.pendingFinished != nil,
                           self.loadAttemptCount < 2 {
                            self.startLoad(isRetry: true)
                        }
                    }
                }
            }
        }
    }

    private func presentLoadedAd(from splash: UIViewController) {
        guard let handle = loadedHandle, isAdAvailable else {
            finishAttempt(reason: "no valid ad at present time")
            return
        }
        guard isSplashStillLaunchSurface(splash) else {
            finishAttempt(reason: "lost splash surface before present")
            return
        }
        guard !isShowing else { return }

        cancelPresentWait()
        isShowing = true
        LMLogger.log("App Open presenting from \(type(of: splash))")
        if !handle.present(from: splash) {
            clearLoadedAd()
            finishAttempt(reason: "canPresent rejected")
            preloadIfNeeded()
        }
    }

    private func presenterSplashIfWaiting() -> UIViewController? {
        if let splash = waitingSplash, isSplashStillLaunchSurface(splash) {
            return splash
        }
        if let root = LMPackageManager.window?.rootViewController as? LMLaunchSplashPage {
            return root
        }
        if let nav = LMPackageManager.window?.rootViewController as? UINavigationController,
           let splash = nav.viewControllers.first as? LMLaunchSplashPage {
            return splash
        }
        return nil
    }

    private func finishAttempt(reason: String) {
        guard !hasFinishedCurrentAttempt else { return }
        hasFinishedCurrentAttempt = true
        cancelPresentWait()
        isShowing = false
        waitingSplash = nil
        let callback = pendingFinished
        pendingFinished = nil
        LMLogger.log("App Open finished — \(reason)")
        callback?()
    }

    private func clearLoadedAd() {
        loadedHandle?.eventSink = nil
        loadedHandle = nil
        loadTime = nil
    }

    private func cancelPresentWait() {
        presentWaitWorkItem?.cancel()
        presentWaitWorkItem = nil
    }
}

// MARK: - LMAppOpenAdFullScreenEventSinking

extension LMAppOpenAdManager: LMAppOpenAdFullScreenEventSinking {

    func appOpenAdDidDismiss() {
        clearLoadedAd()
        finishAttempt(reason: "dismissed")
        preloadIfNeeded()
    }

    func appOpenAdDidFailToPresent(error: Error) {
        clearLoadedAd()
        finishAttempt(reason: "present failed: \(error.localizedDescription)")
        preloadIfNeeded()
    }
}
