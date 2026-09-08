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

    override var usesMineNavigationBarStyle: Bool { true }

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
        barTitle = LMText.profile.mineTabSceneHistory
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
            selectedSpotId: record.selectedSpotId
        )
    }
}

extension LMSceneHistoryBrowsePage: LMSceneExploreResultOverlayDelegate {
    func sceneExploreResultOverlayDidSelectSpot(_ spot: LMSceneExploreSpot) {}

    func sceneExploreResultOverlayDidTapGoToSpot(_ spot: LMSceneExploreSpot) {
        // Open camera in suspended-like Path B experience with this spot.
        let camera = LMCameraPage()
        camera.navigationSource = .normal
        navigationController?.pushViewController(camera, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let session = LMExploreSession(
                phase: .suspended,
                freezeFrame: self.cover,
                showHeatmap: self.record.showHeatmap,
                spots: self.record.spots,
                selectedSpotId: spot.id
            )
            camera.exploreSession = session
            camera.preShootPlanMode = .composition
            camera.preShootPlanModeSwitchEnabled = false
            camera.updateInspireMeButtonState()
            camera.goToSpot(spot)
        }
    }

    func sceneExploreResultOverlayDidTapGetTemplate(_ spot: LMSceneExploreSpot) {
        guard let cover else { return }
        let camera = LMCameraPage()
        navigationController?.pushViewController(camera, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let session = LMExploreSession(
                phase: .result,
                freezeFrame: cover,
                showHeatmap: self.record.showHeatmap,
                spots: self.record.spots,
                selectedSpotId: spot.id
            )
            camera.exploreSession = session
            camera.getTemplate(for: spot)
        }
    }

    func sceneExploreResultOverlayDidTapBack() {
        navigationController?.popViewController(animated: true)
    }

    func sceneExploreResultOverlayDidDismissCard() {}
}
