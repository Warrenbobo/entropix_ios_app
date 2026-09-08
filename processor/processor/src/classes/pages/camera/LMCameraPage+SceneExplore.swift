//
//  LMCameraPage+SceneExplore.swift
//  processor
//
//  Find Spot → Scene Explore → Path A / Path B wiring.
//

import UIKit
import SnapKit

extension LMCameraPage {

    /// Spot appendix appended to Inspire prompt for Path A (SPEC §5.4).
    static func spotPromptAppendix(for spot: LMSceneExploreSpot) -> String {
        """

        Priority focus for this request:
        - Spot name: \(spot.name)
        - Why: \(spot.reason)
        - Keep the FULL scene as reference; prefer compositions that use this area as the primary subject/anchor.
        Do NOT ignore the rest of the environment.
        """
    }

    /// Starts Find Spot / Scene Explore from the PreShootPlan button.
    func handleFindSpotFeature() {
        hideInspireMeGuide()
        guard !isUsingFrontCamera else {
            AppTheme.Toast.showText(LMText.camera.inspireMeOnlyBackCamera)
            return
        }
        guard currentCameraState == .normal else { return }

        if !LMFeatureFlagsManager.backendApiEnabled
            && !LMLlmModuleSettingsStore.isConfigured(.sceneExplore) {
            // Offline demo: allow local fake spots when backend off and unconfigured.
        }

        guard LMLlmModuleSettingsStore.isConfigured(.sceneExplore) else {
            presentMissingModelConfig(for: .sceneExplore)
            return
        }

        guard let image = makeInspireMeImageFromLatestPreviewFrameForExplore() else {
            AppTheme.Toast.showText(LMText.camera.failedToCaptureFrame)
            return
        }

        let session = LMExploreSession(phase: .processing, freezeFrame: image)
        exploreSession = session
        showProcessingOverlay(with: image)
        updateProcessingOverlayLabel(LMText.camera.exploreProcessing)

        Task { [weak self] in
            guard let self else { return }
            let client = LMSceneExploreClient()
            let result = await client.explore(image: image)
            let spots = result.spots
            let wideScene = result.wideScene
            let errorBody = result.errorBody

            var heatmap: UIImage?
            var showHeatmap = false
            if errorBody == nil, !spots.isEmpty {
                let coverage = LMGaussianHeatmapRenderer.bboxUnionCoverage(spots: spots)
                let hide = LMGaussianHeatmapRenderer.shouldHideHeatmap(
                    wideScene: wideScene,
                    coverage: coverage
                )
                showHeatmap = !hide
                if showHeatmap {
                    let opacity = LMSceneExploreConfigRepository.shared.get().heatmapOpacity
                    heatmap = LMGaussianHeatmapRenderer.render(
                        base: image,
                        spots: spots,
                        opacity: opacity
                    )
                    if heatmap == nil { showHeatmap = false }
                }
            }

            await MainActor.run {
                self.hideProcessingOverlay()
                guard errorBody == nil, !spots.isEmpty else {
                    AppTheme.Toast.showText(LMText.camera.exploreFailed)
                    self.exploreSession = nil
                    return
                }
                session.phase = .result
                session.spots = spots
                session.wideScene = wideScene
                session.selectedSpotId = spots.first?.id
                session.showHeatmap = showHeatmap
                session.heatmapImage = heatmap
                self.presentExploreResultOverlay(session: session)
            }
        }
    }

    /**
     Re-synthesizes heatmap onto the freeze frame when restoring a session without a cached bitmap.
     */
    func applyHeatmapDecision(to session: LMExploreSession, frame: UIImage) {
        let coverage = LMGaussianHeatmapRenderer.bboxUnionCoverage(spots: session.spots)
        let hide = LMGaussianHeatmapRenderer.shouldHideHeatmap(
            wideScene: session.wideScene,
            coverage: coverage
        ) || session.spots.isEmpty
        session.showHeatmap = !hide
        if session.showHeatmap {
            let opacity = LMSceneExploreConfigRepository.shared.get().heatmapOpacity
            session.heatmapImage = LMGaussianHeatmapRenderer.render(
                base: frame,
                spots: session.spots,
                opacity: opacity
            )
            if session.heatmapImage == nil {
                session.showHeatmap = false
            }
        } else {
            session.heatmapImage = nil
        }
    }

    func presentMissingModelConfig(for module: LMLlmFeatureModule) {
        let moduleName: String
        switch module {
        case .sceneExplore: moduleName = LMText.settings.modelsSectionSceneExplore
        case .ideaInspiration: moduleName = LMText.settings.modelsSectionIdeaInspiration
        case .arGuidance: moduleName = LMText.settings.modelsSectionARGuidance
        }
        let message = String(format: LMText.settings.modelsMissingConfigMessage, moduleName)
        let alert = UIAlertController(
            title: LMText.settings.modelsMissingConfigTitle,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LMText.common.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: LMText.settings.modelsGoToConfig, style: .default) { [weak self] _ in
            self?.openModelsSubPage(module)
        })
        present(alert, animated: true)
    }

    func openModelsSubPage(_ module: LMLlmFeatureModule) {
        let overview = LMModelsSettingPage()
        let sub = LMModelsSettingPage.makeSubPage(for: module)
        if let nav = navigationController {
            nav.pushViewController(overview, animated: false)
            nav.pushViewController(sub, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: overview)
            overview.navigationController?.pushViewController(sub, animated: false)
            present(nav, animated: true)
        }
    }

    func presentPreShootPlanModeSheet() {
        preShootPlanModeSheet?.removeFromSuperview()
        let sheet = LMPreShootPlanModeSheet()
        sheet.delegate = self
        sheet.present(in: view, above: preShootPlanButtonView, selected: preShootPlanMode)
        preShootPlanModeSheet = sheet
        view.bringSubviewToFront(sheet)
    }

    func presentExploreResultOverlay(session: LMExploreSession) {
        sceneExploreResultOverlay?.removeFromSuperview()
        let overlay = LMSceneExploreResultOverlay()
        overlay.delegate = self
        view.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        if let image = session.freezeFrame {
            // Restore heatmap if needed when returning from Path B / Suggestions.
            if session.showHeatmap, session.heatmapImage == nil {
                applyHeatmapDecision(to: session, frame: image)
            }
            overlay.configure(
                image: image,
                heatmap: session.heatmapImage,
                showHeatmap: session.showHeatmap,
                spots: session.spots,
                selectedSpotId: session.selectedSpotId,
                generatedSpotIds: session.generatedSpotIds
            )
        }
        sceneExploreResultOverlay = overlay
        preShootPlanButtonView.isHidden = true
        cameraBottomControlsView.isHidden = true
        cameraControlsView.isHidden = true
    }

    func hideExploreResultOverlay(showCameraChrome: Bool = true) {
        sceneExploreResultOverlay?.removeFromSuperview()
        sceneExploreResultOverlay = nil
        if showCameraChrome {
            cameraBottomControlsView.isHidden = false
            cameraControlsView.isHidden = false
            updateInspireMeButtonState()
        }
    }

    /// Path B: suspend explore, show live preview + chip; leading control resumes Explore.
    func goToSpot(_ spot: LMSceneExploreSpot) {
        guard let session = exploreSession else { return }
        session.phase = .suspended
        session.selectedSpotId = spot.id
        hideExploreResultOverlay(showCameraChrome: true)
        preShootPlanMode = .composition
        preShootPlanModeSwitchEnabled = false
        updateInspireMeButtonState()
        showTargetSpotChip(name: spot.name)
        updateLeadingNavigationControl()
    }

    /// Path A: Get template using full freeze frame + spot appendix.
    func getTemplate(for spot: LMSceneExploreSpot) {
        guard let session = exploreSession, let image = session.freezeFrame else { return }
        if session.generatedSpotIds.contains(spot.id), session.inspireTaskId != nil {
            // Already generated — jump to suggestions.
            suggestionsBoundToExploreSession = true
            hideExploreResultOverlay(showCameraChrome: false)
            // Existing suggestions UI should already be present if prior Path A ran.
            if currentCameraState != .showingSuggestions {
                // Fall through to regenerate only if carousel missing.
            } else {
                return
            }
        }

        pendingSpotPromptAppendix = Self.spotPromptAppendix(for: spot)
        suggestionsBoundToExploreSession = true
        session.selectedSpotId = spot.id
        hideExploreResultOverlay(showCameraChrome: false)
        showProcessingOverlay(with: image)
        isInspireMeCapture = true
        processInspireMeImage(image)
        session.generatedSpotIds.insert(spot.id)
        sceneExploreResultOverlay?.markGenerated(spotId: spot.id)
    }

    func returnToSpotMapFromSuspended() {
        guard let session = exploreSession, session.phase == .suspended else { return }
        session.phase = .result
        hideTargetSpotChip()
        preShootPlanModeSwitchEnabled = true
        presentExploreResultOverlay(session: session)
        updateLeadingNavigationControl()
    }

    func confirmEndExploreSessionFromResult() {
        let alert = UIAlertController(
            title: LMText.camera.exploreExitConfirmTitle,
            message: LMText.camera.exploreExitConfirmSubtitle,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LMText.common.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: LMText.common.confirm, style: .destructive) { [weak self] _ in
            self?.endExploreSessionWritingHistory()
            self?.hideExploreResultOverlay(showCameraChrome: true)
            self?.resetPreShootPlanAfterExploreEnd()
        })
        present(alert, animated: true)
    }

    func endExploreSessionWritingHistory() {
        guard let session = exploreSession else { return }
        session.phase = .ended
        _ = LMSceneHistoryStore.save(session: session)
        exploreSession = nil
        suggestionsBoundToExploreSession = false
        hideTargetSpotChip()
        updateLeadingNavigationControl()
    }

    func resetPreShootPlanAfterExploreEnd() {
        preShootPlanModeSwitchEnabled = true
        // Keep current mode unless cold start; Path B had forced composition.
        updateInspireMeButtonState()
    }

    private func makeInspireMeImageFromLatestPreviewFrameForExplore() -> UIImage? {
        let latestPixelBuffer = previewFrameAccessQueue.sync { latestPreviewPixelBuffer }
        guard let latestPixelBuffer else { return nil }
        let deviceOrientation = LMOrientationMatcher.orientationForCapture()
        return makeInspireMeImage(from: latestPixelBuffer, deviceOrientation: deviceOrientation)
    }

    private func showTargetSpotChip(name: String) {
        hideTargetSpotChip()
        let chip = UILabel()
        chip.text = String(format: LMText.camera.chipTargetSpot, name)
        chip.font = .systemFont(ofSize: 13, weight: .semibold)
        chip.textColor = .white
        chip.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        chip.layer.cornerRadius = 14
        chip.clipsToBounds = true
        chip.textAlignment = .center
        let padded = UIView()
        padded.addSubview(chip)
        chip.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12))
        }
        view.addSubview(padded)
        padded.snp.makeConstraints { make in
            make.top.equalTo(topStatusBarView.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        close.tintColor = .white
        close.addTarget(self, action: #selector(handleDismissTargetChip), for: .touchUpInside)
        padded.addSubview(close)
        close.snp.makeConstraints { make in
            make.leading.equalTo(chip.snp.trailing).offset(4)
            make.centerY.equalTo(chip)
            make.size.equalTo(22)
            make.trailing.equalToSuperview()
        }
        targetSpotChipView = padded
        view.bringSubviewToFront(padded)
    }

    private func hideTargetSpotChip() {
        targetSpotChipView?.removeFromSuperview()
        targetSpotChipView = nil
    }

    private func showGoToSpotBackButton() {
        updateLeadingNavigationControl()
    }

    private func hideGoToSpotBackButton() {
        updateLeadingNavigationControl()
    }

    /// Legacy aliases — text “Back to spot map” control removed (§3).
    private func showReturnToSpotMapButton() { showGoToSpotBackButton() }
    private func hideReturnToSpotMapButton() { hideGoToSpotBackButton() }

    @objc private func handleDismissTargetChip() {
        // Closing chip does not end session (SPEC §5.5).
        hideTargetSpotChip()
    }

    @objc private func handleReturnToSpotMap() {
        returnToSpotMapFromSuspended()
    }

    /// Exits Suggestions and restores Explore result when Path A is bound.
    func exitShowSuggestionsStateReturningToExplore() {
        guard currentCameraState == .showingSuggestions else { return }
        stopPollingAIGCSuggestions()
        hideSuggestionsCarousel()
        bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
        cameraBottomControlsView.setLayoutMode(.normal, animated: true)
        cameraBottomControlsView.setARGuidanceContainerHidden(false)
        currentCameraState = .normal
        currentTaskId = nil
        if let session = exploreSession {
            session.phase = .result
            presentExploreResultOverlay(session: session)
        }
        UIView.animate(withDuration: 0.35) { self.view.layoutIfNeeded() }
    }

    private func updateProcessingOverlayLabel(_ text: String) {
        // Best-effort: reuse processing overlay label if present.
        if let label = view.viewWithTag(10_005) as? UILabel {
            label.text = text
        }
    }
}

extension LMCameraPage: LMPreShootPlanModeSheetDelegate {
    func preShootPlanModeSheetDidSelect(_ mode: LMPreShootPlanMode) {
        preShootPlanMode = mode
        updateInspireMeButtonState()
    }

    func preShootPlanModeSheetDidDismiss() {
        preShootPlanModeSheet = nil
    }
}

extension LMCameraPage: LMSceneExploreResultOverlayDelegate {
    func sceneExploreResultOverlayDidSelectSpot(_ spot: LMSceneExploreSpot) {
        exploreSession?.selectedSpotId = spot.id
    }

    func sceneExploreResultOverlayDidTapGoToSpot(_ spot: LMSceneExploreSpot) {
        goToSpot(spot)
    }

    func sceneExploreResultOverlayDidTapGetTemplate(_ spot: LMSceneExploreSpot) {
        getTemplate(for: spot)
    }

    func sceneExploreResultOverlayDidTapBack() {
        confirmEndExploreSessionFromResult()
    }

    func sceneExploreResultOverlayDidDismissCard() {
        exploreSession?.selectedSpotId = nil
    }
}
