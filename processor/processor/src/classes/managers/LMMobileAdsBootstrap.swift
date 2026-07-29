//
//  LMMobileAdsBootstrap.swift
//  processor
//

import Foundation
import GoogleMobileAds

/// Starts the Google Mobile Ads SDK exactly once (Single Responsibility).
protocol LMMobileAdsBootstrapping {
    /// Initializes the SDK; safe to call repeatedly.
    func startIfNeeded()
    /**
     Invokes `body` on the main queue after SDK start completes (or immediately if already ready).

     Use before the first ad load so cold-start requests are not raced against init.
     */
    func whenReady(_ body: @escaping () -> Void)
}

/// Default bootstrap that wraps `MobileAds.shared.start()`.
final class LMMobileAdsBootstrap: LMMobileAdsBootstrapping {

    static let shared = LMMobileAdsBootstrap()

    private let lock = NSLock()
    private var didStart = false
    private var isReady = false
    private var pendingReadyHandlers: [() -> Void] = []

    private init() {}

    /**
     Starts Google Mobile Ads if not already started.

     Call after privacy/consent decisions when those apply; study builds start at launch.
     */
    func startIfNeeded() {
        lock.lock()
        if didStart {
            lock.unlock()
            return
        }
        didStart = true
        lock.unlock()

        LMLogger.log("AdMob SDK starting…")
        MobileAds.shared.start { [weak self] status in
            LMLogger.log("AdMob SDK started: adapter count=\(status.adapterStatusesByClassName.count)")
            self?.markReady()
        }
    }

    /// Runs `body` on the main queue once the SDK has finished starting.
    func whenReady(_ body: @escaping () -> Void) {
        startIfNeeded()

        lock.lock()
        if isReady {
            lock.unlock()
            DispatchQueue.main.async(execute: body)
            return
        }
        pendingReadyHandlers.append(body)
        lock.unlock()
    }

    private func markReady() {
        lock.lock()
        isReady = true
        let handlers = pendingReadyHandlers
        pendingReadyHandlers.removeAll()
        lock.unlock()

        DispatchQueue.main.async {
            handlers.forEach { $0() }
        }
    }
}
