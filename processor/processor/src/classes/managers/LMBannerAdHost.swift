//
//  LMBannerAdHost.swift
//  processor
//

import GoogleMobileAds
import UIKit

/**
 Google Mobile Ads implementation of `LMBannerAdHosting` for Mine.

 Keeps `BannerView` / Google types behind this type so `LMMinePage` stays UIKit-focused (DIP).
 */
final class LMBannerAdHost: NSObject, LMBannerAdHosting {

    weak var delegate: LMBannerAdHostDelegate?

    private let configuration: LMBannerAdConfiguring
    private let policy: LMBannerAdPolicyEvaluating
    private let adsBootstrap: LMMobileAdsBootstrapping

    private weak var container: UIView?
    private weak var rootViewController: UIViewController?
    private var bannerView: BannerView?
    private var lastRequestedWidth: CGFloat = 0
    private var hasInstalled = false
    private var isLoadInFlight = false

    /**
     - Parameters:
       - configuration: Ad unit settings.
       - policy: Whether banners may show.
       - adsBootstrap: SDK start gate.
     */
    init(
        configuration: LMBannerAdConfiguring = LMBannerAdConfiguration(),
        policy: LMBannerAdPolicyEvaluating = LMBannerAdPolicy(),
        adsBootstrap: LMMobileAdsBootstrapping = LMMobileAdsBootstrap.shared
    ) {
        self.configuration = configuration
        self.policy = policy
        self.adsBootstrap = adsBootstrap
        super.init()
    }

    // MARK: - LMBannerAdHosting

    func installBanner(in container: UIView, rootViewController: UIViewController) {
        guard policy.shouldShowBannerAd() else { return }

        self.container = container
        self.rootViewController = rootViewController
        bannerView?.rootViewController = rootViewController

        if hasInstalled, bannerView != nil {
            LMLogger.log("Banner already installed — skip recreate")
            return
        }

        hasInstalled = true
        container.isHidden = true

        adsBootstrap.whenReady { [weak self] in
            self?.createAndLoadBannerIfNeeded()
        }
    }

    func removeBanner() {
        bannerView?.delegate = nil
        bannerView?.removeFromSuperview()
        bannerView = nil
        container = nil
        rootViewController = nil
        hasInstalled = false
        isLoadInFlight = false
        lastRequestedWidth = 0
        LMLogger.log("Banner removed")
    }

    func updateAdaptiveSizeIfNeeded(containerWidth: CGFloat) {
        let width = floor(containerWidth)
        guard width > 0 else { return }
        guard abs(width - lastRequestedWidth) > 1 else { return }
        guard let bannerView else { return }
        guard !isLoadInFlight else { return }

        lastRequestedWidth = width
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        bannerView.adSize = adSize
        let height = resolvedBannerHeight(for: bannerView)
        LMLogger.log("Banner adaptive size updated width=\(width) height=\(height)")
        requestAd(on: bannerView)
    }

    // MARK: - Private

    private func createAndLoadBannerIfNeeded() {
        guard let container, let rootViewController else {
            LMLogger.log("Banner create skipped — missing container/root")
            return
        }
        if bannerView != nil { return }

        container.layoutIfNeeded()
        let rawWidth = container.bounds.width
        let width = floor(rawWidth > 1 ? rawWidth : UIScreen.main.bounds.width)
        let adSize = currentOrientationAnchoredAdaptiveBanner(width: max(width, 320))
        lastRequestedWidth = width

        let banner = BannerView(adSize: adSize)
        banner.adUnitID = configuration.adUnitID
        banner.rootViewController = rootViewController
        banner.delegate = self
        banner.backgroundColor = .clear
        banner.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(banner)
        NSLayoutConstraint.activate([
            banner.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            banner.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            banner.topAnchor.constraint(equalTo: container.topAnchor),
            banner.centerXAnchor.constraint(equalTo: container.centerXAnchor)
        ])

        bannerView = banner
        LMLogger.log("Banner loading unit=\(configuration.adUnitID) width=\(width)")
        requestAd(on: banner)
    }

    private func requestAd(on banner: BannerView) {
        isLoadInFlight = true
        banner.load(Request())
    }

    /**
     Resolves a usable banner height from AdMob size / view metrics.

     Adaptive sizes should report height via `cgSize(for:)`; fall back so Mine never
     collapses to a zero-height “visible” banner.
     */
    private func resolvedBannerHeight(for bannerView: BannerView) -> CGFloat {
        let adHeight = cgSize(for: bannerView.adSize).height
        if adHeight >= 40 { return adHeight }

        let intrinsic = bannerView.intrinsicContentSize.height
        if intrinsic >= 40 { return intrinsic }

        let boundsHeight = bannerView.bounds.height
        if boundsHeight >= 40 { return boundsHeight }

        // Standard anchored adaptive floor.
        return 50
    }

    private func currentOrientationAnchoredAdaptiveBanner(width: CGFloat) -> AdSize {
        largeAnchoredAdaptiveBanner(width: width)
    }
}

// MARK: - BannerViewDelegate

extension LMBannerAdHost: BannerViewDelegate {

    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        isLoadInFlight = false
        let height = resolvedBannerHeight(for: bannerView)
        LMLogger.log("Banner received ad height=\(height) adSize=\(cgSize(for: bannerView.adSize))")
        container?.isHidden = false
        delegate?.bannerAdHost(self, didReceiveAdWithHeight: height)
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        isLoadInFlight = false
        LMLogger.log("Banner failed: \(error.localizedDescription)")
        container?.isHidden = true
        delegate?.bannerAdHost(self, didFailWithError: error)
    }

    func bannerViewDidRecordImpression(_ bannerView: BannerView) {
        LMLogger.log("Banner impression")
    }

    func bannerViewDidRecordClick(_ bannerView: BannerView) {
        LMLogger.log("Banner click")
    }
}
