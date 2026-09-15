//
//  LMSceneHistoryBrowsePage.swift
//  processor
//
//  Browse a Scene History bookmark with Explore-like spot cards (new Task each time).
//

import UIKit
import SnapKit

/// Read-only Explore browse from Mine Scene History. Back returns to Mine (not camera).
final class LMSceneHistoryBrowsePage: LMPageWrapper {

    /// History uses overlay circular back; hide Mine nav chrome.
    override var usesMineNavigationBarStyle: Bool { false }

    private let record: LMSceneHistoryRecord
    private let cover: UIImage?
    private let overlay = LMSceneExploreResultOverlay()

    init(record: LMSceneHistoryRecord, cover: UIImage?) {
        self.record = record
        self.cover = cover
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = .black
        view.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        overlay.delegate = self
        guard let cover else { return }

        var heatmap: UIImage?
        var showHeatmap = record.showHeatmap
        if showHeatmap {
            let coverage = LMGaussianHeatmapRenderer.bboxUnionCoverage(spots: record.spots)
            if LMGaussianHeatmapRenderer.shouldHideHeatmap(wideScene: false, coverage: coverage)
                || record.spots.isEmpty {
                showHeatmap = false
            } else {
                let opacity = LMSceneExploreConfigRepository.shared.get().heatmapOpacity
                heatmap = LMGaussianHeatmapRenderer.render(
                    base: cover,
                    spots: record.spots,
                    opacity: opacity
                )
                showHeatmap = heatmap != nil
            }
        }

        overlay.configure(
            image: cover,
            heatmap: heatmap,
            showHeatmap: showHeatmap,
            spots: record.spots,
            selectedSpotId: record.selectedSpotId,
            chrome: .historyBrowse
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func backButtonItemOnTap() {
        navigationController?.popViewController(animated: true)
    }

    /**
     Finds an existing camera page in the stack or pushes one, then applies pending Path A/B.
     */
    private func routePendingToCamera(_ pending: LMSceneExploreHistoryPending) {
        LMSceneExploreHistoryPending.enqueue(pending)
        if let camera = navigationController?.viewControllers.compactMap({ $0 as? LMCameraPage }).first {
            navigationController?.popToViewController(camera, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                camera.consumeSceneHistoryPendingActionIfNeeded()
            }
        } else {
            let camera = LMCameraPage()
            camera.navigationSource = .normal
            navigationController?.pushViewController(camera, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                camera.consumeSceneHistoryPendingActionIfNeeded()
            }
        }
    }
}

extension LMSceneHistoryBrowsePage: LMSceneExploreResultOverlayDelegate {
    func sceneExploreResultOverlayDidSelectSpot(_ spot: LMSceneExploreSpot) {}

    func sceneExploreResultOverlayDidTapGoToSpot(_ spot: LMSceneExploreSpot) {
        guard let cover else { return }
        routePendingToCamera(
            .goToSpot(
                cover: cover,
                spots: record.spots,
                spotId: spot.id,
                showHeatmap: record.showHeatmap
            )
        )
    }

    func sceneExploreResultOverlayDidTapGetTemplate(_ spot: LMSceneExploreSpot) {
        guard let cover else { return }
        routePendingToCamera(
            .getTemplate(
                cover: cover,
                spots: record.spots,
                spotId: spot.id,
                showHeatmap: record.showHeatmap
            )
        )
    }

    func sceneExploreResultOverlayDidTapBack() {
        // History browse: no exit confirm — return to Mine Scene History.
        navigationController?.popViewController(animated: true)
    }

    func sceneExploreResultOverlayDidDismissCard() {}
}
