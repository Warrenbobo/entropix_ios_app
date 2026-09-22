//
//  LMCameraPage+SceneExplore.swift
//  processor
//
//  Find Spot → Scene Explore → Path A / Path B wiring.
//

import UIKit
import SnapKit

extension LMCameraPage {

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

        let freeze = image.lmNormalizedImage()
        let session = LMExploreSession(phase: .processing, freezeFrame: freeze)
        exploreSession = session
        currentCameraState = .sceneExploreProcessing
        showProcessingOverlay(with: freeze, setInspireProcessingState: false)
        applyPageStateChrome()
        updateProcessingOverlayLabel(LMText.camera.exploreProcessing)
        presentFindSpotInterstitial(sessionId: session.sessionId)

        sceneExploreTask?.cancel()
        sceneExploreTask = Task { [weak self] in
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
                guard !Task.isCancelled else { return }
                // User may have confirmed exit while waiting.
                guard self.exploreSession?.sessionId == session.sessionId,
                      self.currentCameraState == .sceneExploreProcessing else {
                    return
                }
                let applyResult = { [weak self] in
                    guard let self else { return }
                    guard self.exploreSession?.sessionId == session.sessionId,
                          self.currentCameraState == .sceneExploreProcessing else {
                        return
                    }
                    self.hideProcessingOverlay()
                    session.phase = .result
                    session.spots = spots
                    session.wideScene = wideScene
                    session.heatmapImage = heatmap
                    session.showHeatmap = showHeatmap

                    let failed = errorBody != nil || spots.isEmpty
                    if failed {
                        // Error lands on RESULT: clean freeze, no dots, short toast.
                        session.spots = []
                        session.showHeatmap = false
                        session.heatmapImage = nil
                        session.selectedSpotId = nil
                        AppTheme.Toast.showText(LMText.camera.exploreFailed)
                    } else {
                        // Card appears only after user taps a spot (no auto-open).
                        session.selectedSpotId = nil
                    }
                    self.presentExploreResultOverlay(session: session)
                }
                if self.findSpotAdSessionId == session.sessionId {
                    self.pendingFindSpotResult = applyResult
                    LMLogger.log("Find Spot result held until interstitial dismiss")
                    return
                }
                applyResult()
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

    /// Presents result overlay inside the camera preview aspect slot (Crop + spots/card).
    func presentExploreResultOverlay(session: LMExploreSession) {
        sceneExploreResultOverlay?.removeFromSuperview()
        let overlay = LMSceneExploreResultOverlay()
        overlay.delegate = self
        previewCanvasView.addSubview(overlay)
        overlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        if let image = session.freezeFrame {
            if session.showHeatmap, session.heatmapImage == nil {
                applyHeatmapDecision(to: session, frame: image)
            }
            overlay.configure(
                image: image,
                heatmap: session.heatmapImage,
                showHeatmap: session.showHeatmap,
                spots: session.spots,
                selectedSpotId: session.selectedSpotId,
                generatedSpotIds: session.generatedSpotIds,
                chrome: .cameraPreviewSlot
            )
        }
        sceneExploreResultOverlay = overlay
        previewCanvasView.bringSubviewToFront(overlay)
        currentCameraState = .sceneExploreResult
        session.phase = .result
        applyPageStateChrome()
        updateLeadingNavigationControl()
    }

    func hideExploreResultOverlay(showCameraChrome: Bool = true) {
        sceneExploreResultOverlay?.removeFromSuperview()
        sceneExploreResultOverlay = nil
        if showCameraChrome {
            applyPageStateChrome()
            updateInspireMeButtonState()
            updateLeadingNavigationControl()
        }
    }

    /**
     Applies chrome for the current Page State (docs/Android/camera-page-states.md).
     Mode chip / bottom / side rail / Album / Get Tips visibility.
     */
    func applyPageStateChrome() {
        guard isViewLoaded else { return }

        switch currentCameraState {
        case .normal:
            preShootPlanButtonView.isHidden = false
            cameraBottomControlsView.isHidden = false
            cameraControlsView.isHidden = false
            bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
            cameraBottomControlsView.setLayoutMode(.normal, animated: false)
            cameraBottomControlsView.applyPreShootShutterAppearance(preShootPlanMode)
            cameraBottomControlsView.setGetTipsVisible(false)
            preShootPlanModeSwitchEnabled = true

        case .sceneExploreProcessing, .sceneExploreResult:
            preShootPlanButtonView.isHidden = true
            cameraBottomControlsView.isHidden = true
            cameraControlsView.isHidden = true

        case .exploreGoToSpot:
            preShootPlanButtonView.isHidden = false
            cameraBottomControlsView.isHidden = false
            cameraControlsView.isHidden = false
            bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
            cameraBottomControlsView.setLayoutMode(.normal, animated: false)
            cameraBottomControlsView.applyPreShootShutterAppearance(.composition)
            cameraBottomControlsView.setGetTipsVisible(false)
            preShootPlanMode = .composition
            preShootPlanModeSwitchEnabled = false

        case .inspireMeProcessing:
            // Bottom remains visible but primary path is wait overlay (IP chrome).
            preShootPlanButtonView.isHidden = true
            cameraBottomControlsView.isHidden = false
            cameraControlsView.isHidden = false

        case .showingSuggestions:
            preShootPlanButtonView.isHidden = true
            cameraBottomControlsView.isHidden = false
            cameraControlsView.isHidden = false
            bottomControlsHeightConstraint?.update(offset: 44)
            cameraBottomControlsView.setLayoutMode(.compact, animated: false)
            cameraBottomControlsView.applySuggestionsChrome()
            cameraBottomControlsView.setGetTipsVisible(false)

        case .compositionSelected:
            preShootPlanButtonView.isHidden = true
            cameraBottomControlsView.isHidden = false
            cameraControlsView.isHidden = false
            bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
            cameraBottomControlsView.setLayoutMode(.normal, animated: false)
        }

        updateInspireMeButtonState()
        updateLeadingNavigationControl()
    }

    /// RESULT chrome: hide shutter/side rail/mode; keep bottom height reserved via canvas layout.
    func applyExploreResultCameraChrome(isShowing: Bool) {
        if isShowing {
            currentCameraState = .sceneExploreResult
        }
        applyPageStateChrome()
    }

    /// Path B: suspend explore, show live preview + chip; leading control resumes Explore.
    func goToSpot(_ spot: LMSceneExploreSpot) {
        guard let session = exploreSession else { return }
        session.phase = .suspended
        session.selectedSpotId = spot.id
        hideExploreResultOverlay(showCameraChrome: false)
        currentCameraState = .exploreGoToSpot
        applyPageStateChrome()
        updateInspireMeButtonState()
        showTargetSpotChip(name: spot.name)
        updateLeadingNavigationControl()
    }

    /// Path A: Get template using full freeze frame + FIXED_CAMERA prompt.
    /// - Parameter bindReturnToExplore: Realtime Path A binds back to RESULT; history Path A usually does not.
    func getTemplate(for spot: LMSceneExploreSpot, bindReturnToExplore: Bool = true) {
        guard let session = exploreSession, let image = session.freezeFrame else {
            LMLogger.log("❌ Path A Get Template aborted — missing session or freeze frame")
            return
        }

        // Same Idea Inspiration / Gemini gate as Basic Camera Get Template shutter.
        if LMFeatureFlagsManager.inspireMeDirectGeminiEnabled,
           !LMLlmModuleSettingsStore.isConfigured(.ideaInspiration) {
            presentMissingModelConfig(for: .ideaInspiration)
            return
        }

        suggestionsBoundToExploreSession = bindReturnToExplore
        session.selectedSpotId = spot.id

        // View compositions: reopen existing suggestions without regenerating.
        if session.generatedSpotIds.contains(spot.id),
           let taskId = session.inspireTaskId ?? currentTaskId,
           !currentSuggestions.isEmpty {
            hideExploreResultOverlay(showCameraChrome: false)
            enterShowSuggestionsState(taskId: taskId, suggestions: currentSuggestions)
            LMLogger.log("📐 Path A View compositions — reuse Suggestions for spot \(spot.id)")
            return
        }

        pendingInspireSpot = spot
        hideExploreResultOverlay(showCameraChrome: false)
        // Direct Gemini: skip long Inspiring freeze — placeholders appear ASAP in processAndGenerateDirectGemini.
        if LMFeatureFlagsManager.inspireMeDirectGeminiEnabled {
            currentCameraState = .inspireMeProcessing
            applyPageStateChrome()
            isInspireMeCapture = true
            inspireTapDate = Date()
            LMLogger.log(
                "inspire.tap mode=FIXED_CAMERA spotId=\(spot.id) " +
                "cameraInstruction=\(!(spot.cameraInstruction?.isEmpty ?? true))"
            )
            processInspireMeImage(image)
        } else {
            currentCameraState = .inspireMeProcessing
            applyPageStateChrome()
            showProcessingOverlay(with: image)
            isInspireMeCapture = true
            processInspireMeImage(image)
        }
        session.generatedSpotIds.insert(spot.id)
        LMLogger.log(
            "🚀 Path A Get Template started spot=\(spot.id) " +
            "freeze=\(Int(image.size.width))x\(Int(image.size.height))"
        )
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
            self?.hideExploreResultOverlay(showCameraChrome: false)
            self?.currentCameraState = .normal
            self?.resetPreShootPlanAfterExploreEnd()
            self?.applyPageStateChrome()
        })
        present(alert, animated: true)
    }

    /// SP-01/02: exit confirm while Scene Explore is still processing.
    func confirmEndExploreSessionFromProcessing() {
        let alert = UIAlertController(
            title: LMText.camera.exploreExitConfirmTitle,
            message: LMText.camera.exploreExitConfirmSubtitle,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LMText.common.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: LMText.common.confirm, style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.sceneExploreTask?.cancel()
            self.sceneExploreTask = nil
            self.cancelFindSpotInterstitial()
            self.hideProcessingOverlay(resetInspireState: false)
            self.exploreSession = nil
            self.currentCameraState = .normal
            self.resetPreShootPlanAfterExploreEnd()
            self.applyPageStateChrome()
        })
        present(alert, animated: true)
    }

    /**
     Shows a preloaded Find Spot interstitial over the freeze overlay.

     If no creative is ready, the callback returns immediately and the result is not held.
     */
    func presentFindSpotInterstitial(sessionId: String) {
        findSpotAdSessionId = sessionId
        pendingFindSpotResult = nil
        LMInterstitialAdManager.shared.showIfAvailable(.findSpot, from: self) { [weak self] in
            guard let self, self.findSpotAdSessionId == sessionId else { return }
            self.findSpotAdSessionId = nil
            let apply = self.pendingFindSpotResult
            self.pendingFindSpotResult = nil
            apply?()
        }
    }

    /**
     Drops a not-yet-shown Find Spot ad and any held result.

     An ad already on screen stays until the user closes it; the held result is cleared so dismiss does nothing.
     */
    func cancelFindSpotInterstitial() {
        findSpotAdSessionId = nil
        pendingFindSpotResult = nil
        LMInterstitialAdManager.shared.cancelIfNotShowing(.findSpot)
    }

    func endExploreSessionWritingHistory() {
        guard let session = exploreSession else { return }
        session.phase = .ended
        if !session.spots.isEmpty {
            _ = LMSceneHistoryStore.save(session: session)
        }
        exploreSession = nil
        suggestionsBoundToExploreSession = false
        hideTargetSpotChip()
        updateLeadingNavigationControl()
    }

    func resetPreShootPlanAfterExploreEnd() {
        preShootPlanModeSwitchEnabled = true
        updateInspireMeButtonState()
    }

    private func makeInspireMeImageFromLatestPreviewFrameForExplore() -> UIImage? {
        let latestPixelBuffer = previewFrameAccessQueue.sync { latestPreviewPixelBuffer }
        guard let latestPixelBuffer else { return nil }
        let deviceOrientation = LMOrientationMatcher.orientationForCapture()
        return makeInspireMeImage(from: latestPixelBuffer, deviceOrientation: deviceOrientation)
    }

    func showTargetSpotChip(name: String) {
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
        hideTargetSpotChip()
    }

    @objc private func handleReturnToSpotMap() {
        returnToSpotMapFromSuspended()
    }

    /// Exits Suggestions and restores Explore result when Path A is bound.
    /// Keeps `currentSuggestions` / `currentTaskId` so View compositions can reopen without regenerating.
    func exitShowSuggestionsStateReturningToExplore() {
        stopPollingAIGCSuggestions()
        hideSuggestionsCarousel()
        hideProcessingOverlay(resetInspireState: false)
        isInspireMeCapture = false
        bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
        cameraBottomControlsView.setLayoutMode(.normal, animated: true)
        cameraBottomControlsView.setARGuidanceContainerHidden(false)
        // Do NOT clear currentSuggestions / currentTaskId / inspireTaskId (SR-08 View).
        if let session = exploreSession {
            session.phase = .result
            if currentTaskId != nil {
                session.inspireTaskId = currentTaskId
            }
            presentExploreResultOverlay(session: session)
        } else {
            currentCameraState = .normal
            applyPageStateChrome()
            updateLeadingNavigationControl()
        }
        syncAgentCoachingForCurrentState()
        updateLeadingNavigationControl()
        UIView.animate(withDuration: 0.35) { self.view.layoutIfNeeded() }
        LMLogger.log("🔙 Show Suggestions → Explore result (Path A, suggestions cached)")
    }

    private func updateProcessingOverlayLabel(_ text: String) {
        if let label = view.viewWithTag(10_005) as? UILabel {
            label.text = text
        }
    }

    /// Applies a History-browse pending Path A/B action after camera is on screen.
    func consumeSceneHistoryPendingActionIfNeeded() {
        guard let pending = LMSceneExploreHistoryPending.consume() else { return }
        switch pending {
        case let .goToSpot(cover, spots, spotId, showHeatmap):
            let session = LMExploreSession(
                phase: .suspended,
                freezeFrame: cover,
                showHeatmap: showHeatmap,
                spots: spots,
                selectedSpotId: spotId
            )
            exploreSession = session
            if let spot = spots.first(where: { $0.id == spotId }) {
                goToSpot(spot)
            }
        case let .getTemplate(cover, spots, spotId, showHeatmap):
            let session = LMExploreSession(
                phase: .result,
                freezeFrame: cover,
                showHeatmap: showHeatmap,
                spots: spots,
                selectedSpotId: spotId
            )
            exploreSession = session
            if let spot = spots.first(where: { $0.id == spotId }) {
                // History Path A: abandon suggestions returns to NORMAL, not RESULT.
                getTemplate(for: spot, bindReturnToExplore: false)
            }
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

/// Pending Path A/B action queued from Mine Scene History browse (pop → camera).
enum LMSceneExploreHistoryPending {
    case goToSpot(cover: UIImage, spots: [LMSceneExploreSpot], spotId: String, showHeatmap: Bool)
    case getTemplate(cover: UIImage, spots: [LMSceneExploreSpot], spotId: String, showHeatmap: Bool)

    private static var storage: LMSceneExploreHistoryPending?

    static func enqueue(_ action: LMSceneExploreHistoryPending) {
        storage = action
    }

    static func consume() -> LMSceneExploreHistoryPending? {
        let value = storage
        storage = nil
        return value
    }
}
