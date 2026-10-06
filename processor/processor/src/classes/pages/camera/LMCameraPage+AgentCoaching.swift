//
//  LMCameraPage+AgentCoaching.swift
//  processor
//

import UIKit
import PhotosUI
import UniformTypeIdentifiers

extension LMCameraPage: LMAgentCoachingUIDelegate {

    /// Installs agent coaching HUD and wires controller delegate.
    func setupAgentCoachingHUDIfNeeded() {
        agentCoachingController.uiDelegate = self

        if scoreDonutOverlayView == nil {
            let size = LMCameraConstants.agentScoreDonutSize
            let donut = LMScoreDonutOverlayView(frame: .zero)
            view.addSubview(donut)
            donut.snp.makeConstraints { make in
                scoreDonutLeadingConstraint = make.leading
                    .equalToSuperview()
                    .offset(LMCameraConstants.agentScoreDonutLeading)
                    .constraint
                make.size.equalTo(CGSize(width: size, height: size))
                scoreDonutTopConstraint = make.top
                    .equalTo(view.safeAreaLayoutGuide.snp.top)
                    .offset(LMCameraConstants.agentScoreDonutAbsoluteTopOffset)
                    .constraint
            }
            donut.onDragBegan = { [weak self] in
                self?.setScoreDonutManualPositionEnabled(true)
            }
            donut.allowedDragBoundsProvider = { [weak self] in
                self?.scoreDonutAllowedCenterBounds() ?? .null
            }
            scoreDonutOverlayView = donut
        }

        if coachingBubbleView == nil {
            let bubble = LMCoachingBubbleView()
            view.addSubview(bubble)
            bubble.snp.makeConstraints { make in
                make.top.equalTo(topStatusBarView.snp.bottom)
                    .offset(LMCameraConstants.agentCoachingBubbleTopGap)
                make.leading.trailing.equalToSuperview()
            }
            coachingBubbleView = bubble
            bubble.onSkipTapped = { [weak self] in
                guard let self else { return }
                self.agentCoachingController.onSkipSuggestion(
                    currentInstruction: self.coachingBubbleView?.currentInstructionText
                )
            }
            bubble.onToggleReasoning = { [weak self] in
                self?.toggleCoachingReasoningExpanded()
            }
        }
    }

    /// Turns Framing and Pose overlays off (sidebar sync). Prefer per-tool toggles for user actions.
    func clearGuidanceOverlays() {
        boxAlignCompleteWorkItem?.cancel()
        boxAlignCompleteWorkItem = nil
        lineArtAutoDismissWorkItem?.cancel()
        lineArtAutoDismissWorkItem = nil
        isBoxGuidanceEnabled = false
        isLineArtGuidanceEnabled = false
        executionTool = .none
        applyGuidanceOverlays()
        refreshCoachingBubble()
    }

    private func setScoreDonutManualPositionEnabled(_ manual: Bool) {
        guard let donut = scoreDonutOverlayView else { return }
        if manual {
            // Freeze current frame, drop position constraints, own layout via frame/center.
            let frozen = donut.frame
            scoreDonutTopConstraint?.deactivate()
            scoreDonutLeadingConstraint?.deactivate()
            donut.translatesAutoresizingMaskIntoConstraints = true
            view.layoutIfNeeded()
            donut.frame = frozen
            donut.center = donut.clampCenter(donut.center)
            scoreDonutUsesManualPosition = true
            return
        }

        scoreDonutUsesManualPosition = false
        donut.translatesAutoresizingMaskIntoConstraints = false
        scoreDonutLeadingConstraint?.activate()
        scoreDonutTopConstraint?.activate()
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }

    /**
     Hard safe window for the donut **center** (user proposal + Skip overlap fix).

     | Edge | Bound |
     |------|--------|
     | Top | Below coaching HUD (or status bar if HUD hidden) |
     | Bottom | Above bottom shutter / Get Tips bar |
     | Leading | Screen inset |
     | Trailing | Clear of right tool rail |
     */
    private func scoreDonutAllowedCenterBounds() -> CGRect {
        let half = LMCameraConstants.agentScoreDonutSize / 2
        let margin: CGFloat = 8

        let statusBottom = view.safeAreaInsets.top + LMCameraConstants.topStatusBarHeight
        var topLimit = statusBottom
        if let bubble = coachingBubbleView, !bubble.isHidden, bubble.alpha > 0.01 {
            // Prefer laid-out bubble bottom; fall back to expected strip if height is still 0.
            let bubbleBottom = bubble.frame.maxY
            if bubbleBottom > statusBottom {
                topLimit = bubbleBottom
            } else {
                topLimit = statusBottom
                    + LMCameraConstants.agentCoachingBubbleTopGap
                    + LMCameraConstants.agentCoachingBubbleCollapsedHeight
            }
        }

        let minY = topLimit + half + margin
        let bottomLimit = cameraBottomControlsView.frame.minY > 0
            ? cameraBottomControlsView.frame.minY
            : view.bounds.height - view.safeAreaInsets.bottom
        let maxY = max(minY, bottomLimit - half - margin)

        let minX = half + margin
        let trailingLimit = cameraControlsView.frame.minX > margin
            ? cameraControlsView.frame.minX
            : view.bounds.width
        let maxX = max(minX, trailingLimit - half - margin)

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Re-clamps a user-dragged donut after HUD layout changes (e.g. Skip ack).
    private func reclampScoreDonutIfNeeded() {
        guard scoreDonutUsesManualPosition, let donut = scoreDonutOverlayView, !donut.isHidden else { return }
        view.layoutIfNeeded()
        donut.center = donut.clampCenter(donut.center)
    }

    /// Bubble stays hidden until the first instruct tap; then remains visible with the latest answer.
    func shouldShowCoachingInstructionBubble() -> Bool {
        guard agentGuidanceState == .agent, currentCameraState == .compositionSelected else { return false }
        return hasUserTriggeredInstructInSession
    }

    func updateCoachingBubbleVisibility() {
        coachingBubbleView?.setVisible(shouldShowCoachingInstructionBubble())
    }

    func syncAgentCoachingForCurrentState() {
        let isComposition = currentCameraState == .compositionSelected
        // Agent is always on in composition-selected (§5); no sidebar toggle.
        if isComposition {
            agentGuidanceState = .agent
        }
        let agentOn = agentGuidanceState == .agent && isComposition

        cameraControlsView.setAgentToggleVisible(false)
        cameraControlsView.setAgentToggleState(agentGuidanceState)
        cameraControlsView.setGuidanceToolTogglesVisible(isComposition)
        cameraControlsView.setBoxGuidanceEnabled(isBoxGuidanceEnabled)
        cameraControlsView.setLineArtGuidanceEnabled(isLineArtGuidanceEnabled)
        cameraBottomControlsView.setARGuidanceContainerHidden(
            isComposition || currentCameraState == .showingSuggestions
        )
        // Wait for Stage A/B warmup so Get Tips cannot fire with a nil controller reference
        // (common after Album picker dismiss / accidental tap while models still load).
        cameraBottomControlsView.setGetTipsVisible(
            agentOn && currentReferenceImage != nil && referenceWarmupComplete
        )

        if agentOn {
            updateShutterRoleForAgentState(agentCoachingController.agentState)
        } else {
            shutterRole = .captureDefault
            cameraBottomControlsView.setShutterRole(.captureDefault)
            cameraBottomControlsView.setGetTipsVisible(false)
            if currentCameraState == .normal || currentCameraState == .exploreGoToSpot {
                let mode = (currentCameraState == .exploreGoToSpot)
                    ? LMPreShootPlanMode.composition
                    : preShootPlanMode
                cameraBottomControlsView.applyPreShootShutterAppearance(mode)
            }
        }

        setupAgentCoachingHUDIfNeeded()
        updateCoachingBubbleVisibility()
        scoreDonutOverlayView?.setVisible(agentOn)
        if agentOn {
            refreshCoachingBubble()
            // Show placeholder until the first live tick publishes.
            if agentCoachingController.displayableScore == nil {
                scoreDonutOverlayView?.apply(score: nil)
            }
        } else {
            hasUserTriggeredInstructInSession = false
            resetCoachingSessionUI()
            instructProgressCoordinator.stop()
            // Restore default donut placement when leaving agent composition.
            setScoreDonutManualPositionEnabled(false)
        }

        if agentOn && referenceWarmupComplete {
            agentCoachingController.setReferenceImage(currentReferenceImage, bbox: currentReferenceBbox)
            // Eligibility = reference person mask present (LineArt image itself is lazy).
            agentCoachingController.setLineArtReady(
                LMHumanUnderstandingService.shared.referenceSnapshot != nil
            )
            // Idempotent: will not tear down an already-running live loop.
            agentCoachingController.startScoreLoop { [weak self] in
                self?.capturePreviewFrameForScoring()
            }
            if let score = agentCoachingController.displayableScore {
                scoreDonutOverlayView?.apply(score: score)
            }
        } else {
            agentCoachingController.stopScoreLoop()
        }

        applyExecutionToolToOverlay()
    }

    func toggleAgentGuidance() {
        // Agent toggle removed from composition-selected (§5); keep no-op for legacy side rail.
        guard currentCameraState == .compositionSelected else { return }
        agentGuidanceState = .agent
        syncAgentCoachingForCurrentState()
    }

    func beginInstructRound() {
        guard currentCameraState == .compositionSelected else { return }
        agentGuidanceState = .agent

        if !LMLlmModuleSettingsStore.isConfigured(.arGuidance) {
            presentMissingModelConfig(for: .arGuidance)
            return
        }

        guard LMLlmCallQuotaStore.hasRemaining(for: .arGuidance) else {
            presentMissingModelConfig(for: .arGuidance)
            return
        }

        guard let reference = currentReferenceImage else {
            AppTheme.Toast.showText(LMText.camera.cameraNotReady)
            return
        }

        // Album / saved-idea entry can expose UI before Stage B finishes; block until ready.
        guard referenceWarmupComplete else {
            AppTheme.Toast.showText(LMText.camera.cameraNotReady)
            return
        }

        guard shutterRole == .instructReady || shutterRole == .captureReady || shutterRole == .captureDefault else {
            return
        }

        agentCoachingController.setReferenceImage(reference, bbox: currentReferenceBbox)

        hasUserTriggeredInstructInSession = true
        resetCoachingSessionUI()
        agentCoachingController.markCoachingFinal(false)
        updateShutterRoleForAgentState(.running)
        cameraBottomControlsView.setGetTipsRunning(true)

        instructProgressCoordinator.start { [weak self] phase in
            guard let self else { return }
            self.coachingBubbleView?.setVisible(true)
            self.coachingActionText = phase.displayText
            self.refreshCoachingBubble(agentState: .running, isFinal: false)
        }

        agentCoachingController.runAgentRound { [weak self] in
            self?.capturePreviewFrameForScoring()
        }
    }

    /// Derives shutter / Get Tips chrome from agent state — shutter stays photo-only.
    func updateShutterRoleForAgentState(_ state: LMAgentState) {
        guard agentGuidanceState == .agent, currentCameraState == .compositionSelected else { return }

        switch state {
        case .running:
            shutterRole = .instructRunning
            cameraBottomControlsView.setGetTipsRunning(true)
        case .finished:
            shutterRole = .instructReady
            cameraBottomControlsView.setGetTipsRunning(false)
            instructProgressCoordinator.stop()
        case .idle, .error:
            shutterRole = .instructReady
            cameraBottomControlsView.setGetTipsRunning(false)
            if state == .error {
                instructProgressCoordinator.stop()
            }
        }
        cameraBottomControlsView.setShutterRole(.captureDefault)
        updateCoachingBubbleVisibility()
        refreshCoachingBubble(agentState: state, isFinished: state == .finished)
    }

    func enterCompositionSelected(
        with suggestion: LMCompositionSuggestion,
        image: UIImage?
    ) {
        switch currentCameraState {
        case .showingSuggestions:
            compositionEntrySource = .showingSuggestions
        case .exploreGoToSpot:
            compositionEntrySource = .exploreGoToSpot
        default:
            compositionEntrySource = .normal
        }

        currentSuggestion = suggestion
        currentCameraState = .compositionSelected
        agentGuidanceState = .agent
        executionTool = .none
        isBoxGuidanceEnabled = false
        isLineArtGuidanceEnabled = false
        shutterRole = .instructReady
        hasUserTriggeredInstructInSession = false
        referenceWarmupComplete = false
        agentCoachingController.stopAll()
        agentCoachingController.resetAgentWindow()
        resetCoachingSessionUI()

        if let image {
            currentReferenceImage = image
            // Seed controller immediately so a late Get Tips tap never sees nil reference
            // while warmup still runs (warmup refreshes bbox / line-art eligibility).
            agentCoachingController.setReferenceImage(image, bbox: currentReferenceBbox)
            showReferenceImageInCorner(suggestion: suggestion)
        }

        preShootPlanButtonView.isHidden = true
        hideSuggestionsCarousel()
        // Explore Path A may leave chrome hidden; restore for composition-selected shutter / Get Tips.
        cameraBottomControlsView.isHidden = false
        cameraControlsView.isHidden = false
        bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
        updateCameraControlsVerticalOffsetForSuggestionsState()
        cameraBottomControlsView.setLayoutMode(.normal, animated: true)

        Task { await warmupReferenceForAgent(image: image ?? currentReferenceImage) }
        syncAgentCoachingForCurrentState()
    }

    func enterCompositionSelectedFromAlbum(_ imageURL: URL) {
        let suggestion = LMCompositionSuggestion(
            id: "album_\(Int(Date().timeIntervalSince1970 * 1000))",
            sceneType: nil,
            source: "album",
            ready: true,
            imageUrl: imageURL.absoluteString,
            width: nil,
            height: nil,
            rank: nil,
            score: nil
        )
        let image = Self.loadAlbumReferenceImageApplyingExif(at: imageURL)
        enterCompositionSelected(with: suggestion, image: image)
    }

    /**
     Loads an album reference using the file’s **EXIF orientation**.

     `UIImage(data:)` applies EXIF to `imageOrientation` / logical size (same as
     Photos preview). Then bakes pixels upright via `lmNormalizedImage()` so the
     corner card, bbox, and score share one geometry that matches the album.

     Does **not** use camera preview capture orientation (`LMPreviewFramePipeline`
     / `LMOrientationMatcher.previewEXIF`).
     */
    static func loadAlbumReferenceImageApplyingExif(at url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            return nil
        }
        return image.lmNormalizedImage()
    }

    func presentAlbumPicker() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    /**
     Stage A + B: await model preload, then warm reference features off the main thread.

     Score loop starts only after `referenceWarmupComplete` via `syncAgentCoachingForCurrentState`.
     */
    func warmupReferenceForAgent(image: UIImage?) async {
        guard let image else { return }

        // Stage A — no-op if camera `viewDidAppear` already finished preload.
        await LMCompositionModelPreloader.shared.preloadIfNeeded()

        let isLandscape = image.size.width > image.size.height
        _ = try? await LMHumanUnderstandingService.shared.analyzeReferenceOnce(
            image,
            shouldRotateToPortrait: isLandscape
        )

        let bbox = LMHumanUnderstandingService.shared.referenceSnapshot?.derivedBBox
        // Eligible when reference has a person mask; image generated on first .lineArt callout.
        let lineArtEligible = LMHumanUnderstandingService.shared.referenceSnapshot != nil

        // Stage B — encode / depth / edges / mask on a background queue (never MainActor).
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                LMCompositionAnalyzer.shared.warmupReference(image)
                continuation.resume()
            }
        }

        await MainActor.run {
            // LineArt is lazy (first callout only) — do not block warmup critical path.
            self.currentReferenceLineArtImage = nil
            self.arGuidanceView.clearLineArtImage()
            self.currentReferenceBbox = bbox
            self.agentCoachingController.setReferenceImage(image, bbox: bbox)
            self.agentCoachingController.setLineArtReady(lineArtEligible)
            self.referenceWarmupComplete = true
            self.configureARGuidanceForAgentEntry()
            self.syncAgentCoachingForCurrentState()
        }
    }

    func capturePreviewFrameForScoring() -> UIImage? {
        let pixelBuffer = previewFrameAccessQueue.sync { latestPreviewPixelBuffer }
        guard let pixelBuffer else { return nil }
        // Copy before AVFoundation recycles the camera ring buffer.
        guard let stable = LMPreviewFramePipeline.copyPixelBuffer(pixelBuffer) else { return nil }
        let orientation = LMOrientationMatcher.orientationForCapture()
        return LMPreviewFramePipeline.makeUIImage(
            from: stable,
            orientationPolicy: .locked(orientation),
            isFrontCamera: isUsingFrontCamera
        )
    }

    /**
     Generates Asset LineArt once for the current reference (plan §4.5).
     Cache hits return immediately; clears with `clearLineArtOverlay` / reference change.

     - Parameter completion: Invoked on the main queue with whether a line-art image is available.
     */
    func ensureLineArtReadyForCallout(completion: ((Bool) -> Void)? = nil) {
        if currentReferenceLineArtImage != nil {
            arGuidanceView.setLineArtImage(currentReferenceLineArtImage)
            agentCoachingController.setLineArtReady(true)
            completion?(true)
            return
        }
        guard let image = currentReferenceImage else {
            completion?(false)
            return
        }

        arGuidanceLineArtRequestId &+= 1
        let requestId = arGuidanceLineArtRequestId
        let mask = LMHumanUnderstandingService.shared.referenceSnapshot?.segmentationMask

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let canvasImage = image.lmARGuidanceCanvasImage()
            let lineArtImage: UIImage?
            if let mask {
                lineArtImage = LMImageAssetProcessor.generateLineArt(from: canvasImage, mask: mask)
            } else {
                lineArtImage = LMImageAssetProcessor.generateLineArt(from: canvasImage)
            }

            DispatchQueue.main.async {
                guard let self, requestId == self.arGuidanceLineArtRequestId else { return }
                self.currentReferenceLineArtImage = lineArtImage
                self.arGuidanceView.setLineArtImage(lineArtImage)
                // Keep eligibility true even if generation fails — router gate is person presence.
                self.agentCoachingController.setLineArtReady(
                    LMHumanUnderstandingService.shared.referenceSnapshot != nil
                )
                if lineArtImage != nil {
                    LMLogger.log("✅ LineArt prepared on first callout (cached for reference session)")
                } else {
                    LMLogger.log("⚠️ LineArt first callout generation failed")
                }
                completion?(lineArtImage != nil)
            }
        }
    }

    /// Applies Framing / Pose overlay flags and syncs sidebar highlight + live detection.
    func applyGuidanceOverlays() {
        let inComposition = currentCameraState == .compositionSelected
        let overlay = LMARGuidanceOverlayDisplay(
            showBox: isBoxGuidanceEnabled,
            showLineArt: isLineArtGuidanceEnabled,
            inCompositionSelected: inComposition
        )
        arGuidanceView.setOverlayDisplay(overlay)
        if isBoxGuidanceEnabled, let bbox = currentReferenceBbox, let image = currentReferenceImage {
            let canvasBbox = convertBboxToCanvas(bbox: bbox, imageSize: image.size)
            arGuidanceView.setReferenceBoxBounds(bbox: canvasBbox)
            arGuidanceView.setReferenceGuideReady(true)
            if isCurrentOrientationMatched() {
                arGuidanceView.showReferenceBox()
            }
        }
        if isLineArtGuidanceEnabled {
            arGuidanceView.setLineArtImage(currentReferenceLineArtImage)
        }
        isARGuidanceActive = inComposition && agentGuidanceState == .agent
            && (isBoxGuidanceEnabled || isLineArtGuidanceEnabled)
        cameraControlsView.setBoxGuidanceEnabled(isBoxGuidanceEnabled)
        cameraControlsView.setLineArtGuidanceEnabled(isLineArtGuidanceEnabled)
        syncExecutionToolRealtimeDetection()
        // Keep legacy single-tool field in sync for any remaining call sites / logs.
        if isBoxGuidanceEnabled && isLineArtGuidanceEnabled {
            executionTool = .box
        } else if isBoxGuidanceEnabled {
            executionTool = .box
        } else if isLineArtGuidanceEnabled {
            executionTool = .lineArt
        } else {
            executionTool = .none
        }
    }

    /// Legacy name — forwards to `applyGuidanceOverlays`.
    func applyExecutionToolToOverlay() {
        applyGuidanceOverlays()
    }

    /**
     Arms / disarms the blue live-person bbox when Framing is on.

     Composition entry may start with Framing off; enabling Framing must re-arm stream detection.
     */
    func syncExecutionToolRealtimeDetection() {
        guard currentCameraState == .compositionSelected,
              agentGuidanceState == .agent,
              isBoxGuidanceEnabled else {
            stopRealtimePersonDetection()
            hideLiveBox()
            return
        }

        guard arGuidanceState == .activeGuidance else { return }
        arGuidanceStartTime = Date()
        startRealtimePersonDetection()
    }

    // MARK: - Sidebar Framing / Pose

    /**
     User toggled Framing (optimistic ON). Ensures white-box cache, then applies overlay.

     - Parameter enabled: Desired Framing state from the sidebar.
     */
    func setBoxGuidanceEnabledFromSidebar(_ enabled: Bool) {
        guard currentCameraState == .compositionSelected else { return }
        if !enabled {
            boxAlignCompleteWorkItem?.cancel()
            boxAlignCompleteWorkItem = nil
            isBoxGuidanceEnabled = false
            applyGuidanceOverlays()
            return
        }

        isBoxGuidanceEnabled = true
        cameraControlsView.setBoxGuidanceEnabled(true)
        ensureFramingResourcesReady { [weak self] success in
            guard let self else { return }
            guard self.currentCameraState == .compositionSelected else { return }
            if success {
                self.applyGuidanceOverlays()
                if self.arGuidanceState == .disabled || self.arGuidanceState == .paused {
                    self.startARGuidanceSession()
                }
            } else {
                self.isBoxGuidanceEnabled = false
                self.applyGuidanceOverlays()
                AppTheme.Toast.showText(LMText.camera.arGuidanceNoPersonDetected)
            }
        }
    }

    /**
     User toggled Pose / line-art (optimistic ON).

     - Parameter enabled: Desired Pose state from the sidebar.
     */
    func setLineArtGuidanceEnabledFromSidebar(_ enabled: Bool) {
        guard currentCameraState == .compositionSelected else { return }
        if !enabled {
            isLineArtGuidanceEnabled = false
            applyGuidanceOverlays()
            return
        }

        isLineArtGuidanceEnabled = true
        cameraControlsView.setLineArtGuidanceEnabled(true)
        ensureLineArtReadyForCallout { [weak self] success in
            guard let self else { return }
            guard self.currentCameraState == .compositionSelected else { return }
            if success {
                self.applyGuidanceOverlays()
            } else {
                self.isLineArtGuidanceEnabled = false
                self.applyGuidanceOverlays()
                AppTheme.Toast.showText(LMText.camera.arGuidanceDetectionFailed)
            }
        }
    }

    /**
     Ensures a cached reference bbox for Framing; reuses warmup result when present.

     - Parameter completion: Main-queue callback with whether bbox is available.
     */
    func ensureFramingResourcesReady(completion: @escaping (Bool) -> Void) {
        if currentReferenceBbox != nil {
            completion(true)
            return
        }
        guard let image = currentReferenceImage else {
            completion(false)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let isLandscape = image.size.width > image.size.height
            _ = try? await LMHumanUnderstandingService.shared.analyzeReferenceOnce(
                image,
                shouldRotateToPortrait: isLandscape
            )
            let bbox = LMHumanUnderstandingService.shared.referenceSnapshot?.derivedBBox
            await MainActor.run {
                guard self.currentCameraState == .compositionSelected else { return }
                if let bbox {
                    self.currentReferenceBbox = bbox
                    self.agentCoachingController.setReferenceImage(image, bbox: bbox)
                    completion(true)
                } else {
                    completion(false)
                }
            }
        }
    }

    // MARK: - LMAgentCoachingUIDelegate

    func resetCoachingSessionUI() {
        boxAlignCompleteWorkItem?.cancel()
        boxAlignCompleteWorkItem = nil
        lineArtAutoDismissWorkItem?.cancel()
        lineArtAutoDismissWorkItem = nil
        coachingActionText = ""
        coachingReasoningText = ""
        coachingReasoningExpanded = false
        coachingShowSkipOverride = nil
        agentCoachingController.markCoachingFinal(false)
    }

    /// After box alignment holds, turn Framing off and show the coaching hint (sidebar syncs OFF).
    func scheduleBoxAlignCoachingUpdateIfNeeded() {
        guard agentGuidanceState == .agent, isBoxGuidanceEnabled else { return }
        boxAlignCompleteWorkItem?.cancel()
        let policy = LMCoachingPolicyConfig.default
        let delay = TimeInterval(policy.executionToolsBoxAlignHoldMs + 300) / 1000
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isBoxGuidanceEnabled, self.isCurrentlyAligned else { return }
            self.isBoxGuidanceEnabled = false
            self.applyGuidanceOverlays()
            self.coachingActionText = LMText.camera.agentBoxAlignedMessage
            self.coachingReasoningExpanded = false
            self.agentCoachingController.markCoachingFinal(true)
            self.refreshCoachingBubble(isFinal: true)
        }
        boxAlignCompleteWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func toggleCoachingReasoningExpanded() {
        coachingReasoningExpanded.toggle()
        refreshCoachingBubble()
    }

    private func refreshCoachingBubble(
        agentState: LMAgentState? = nil,
        isFinished: Bool? = nil,
        isFinal: Bool? = nil,
        showSkipOverride: Bool? = nil
    ) {
        let resolvedState = agentState ?? agentCoachingController.agentState
        let resolvedFinished = isFinished ?? (resolvedState == .finished)
        let resolvedFinal = isFinal ?? agentCoachingController.coachingIsFinal
        let computedShowSkip = agentCoachingController.skipEnabled &&
            resolvedFinal &&
            resolvedState != .running &&
            !coachingActionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let showSkip = showSkipOverride ?? coachingShowSkipOverride ?? computedShowSkip

        coachingBubbleView?.update(
            instruction: coachingActionText.isEmpty ? nil : coachingActionText,
            reasoning: coachingReasoningText.isEmpty ? nil : coachingReasoningText,
            reasoningExpanded: coachingReasoningExpanded,
            agentState: resolvedState,
            isFinished: resolvedFinished,
            showSkip: showSkip
        )
        updateCoachingBubbleVisibility()
        // Skip / height changes trigger layout — keep a dragged donut inside the HUD-safe window.
        view.layoutIfNeeded()
        reclampScoreDonutIfNeeded()
    }

    func agentCoaching(didUpdateReasoning reasoning: String) {
        let reasoningJustStarted = !reasoning.isEmpty && coachingReasoningText.isEmpty
        coachingReasoningText = reasoning
        if reasoningJustStarted && coachingActionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            coachingReasoningExpanded = true
        }
        refreshCoachingBubble(agentState: agentCoachingController.agentState)
    }

    func agentCoaching(didUpdateAgentState state: LMAgentState) {
        updateShutterRoleForAgentState(state)
    }

    func agentCoaching(didUpdateAction displayText: String, isFinal: Bool, showSkip: Bool?) {
        coachingActionText = displayText
        if !displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            coachingReasoningExpanded = false
        }
        if let showSkip {
            coachingShowSkipOverride = showSkip
        } else if isFinal {
            // New final tip — restore normal Skip eligibility.
            coachingShowSkipOverride = nil
        }
        agentCoachingController.markCoachingFinal(isFinal)
        let state = isFinal && agentCoachingController.agentState == .running
            ? LMAgentState.running
            : agentCoachingController.agentState
        refreshCoachingBubble(
            agentState: state,
            isFinal: isFinal,
            showSkipOverride: coachingShowSkipOverride
        )
    }

    func agentCoaching(didSetExecutionTool tool: LMExecutionTool, instruction: String?) {
        switch tool {
        case .none:
            break
        case .box:
            if !isBoxGuidanceEnabled {
                isBoxGuidanceEnabled = true
                ensureFramingResourcesReady { [weak self] success in
                    guard let self else { return }
                    if success {
                        self.applyGuidanceOverlays()
                    } else {
                        self.isBoxGuidanceEnabled = false
                        self.applyGuidanceOverlays()
                    }
                }
            }
            applyGuidanceOverlays()
        case .lineArt:
            if !isLineArtGuidanceEnabled {
                isLineArtGuidanceEnabled = true
                ensureLineArtReadyForCallout { [weak self] _ in
                    self?.applyGuidanceOverlays()
                }
            }
            applyGuidanceOverlays()
        }

        if let instruction {
            coachingActionText = instruction
            coachingReasoningExpanded = false
            refreshCoachingBubble(agentState: .running, isFinal: false)
        }
    }

    func agentCoaching(didUpdateCompositionScore score: LMCompositionScore?) {
        scoreDonutOverlayView?.apply(score: score)
    }

    func agentCoaching(didFinishWithCause cause: LMFinishCause) {
        coachingActionText = LMFinishCopy.display(cause)
        coachingReasoningExpanded = false
        agentCoachingController.markCoachingFinal(true)
        updateShutterRoleForAgentState(.finished)
    }

    func agentCoaching(didApplyExposureAction semanticAction: String) {
        LMLogger.log("Exposure action: \(semanticAction)")
    }

    func agentCoaching(didCompleteScoreModule phase: LMInstructProgressPhase) {
        instructProgressCoordinator.markModuleDone(phase)
    }

    func agentCoachingDidEnterThinking() {
        instructProgressCoordinator.enterThinking()
    }
}

// MARK: - PHPickerViewControllerDelegate
extension LMCameraPage: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider else { return }

        // Prefer file representation so we can ignore EXIF via CGImageSource.
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] url, _ in
                guard let self, let url else {
                    self?.loadAlbumImageViaUIImageObject(from: provider)
                    return
                }
                let temp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("album_ref_\(UUID().uuidString).jpg")
                try? FileManager.default.removeItem(at: temp)
                try? FileManager.default.copyItem(at: url, to: temp)
                // Bake EXIF into upright pixels so card + score match Photos preview.
                if let normalized = Self.loadAlbumReferenceImageApplyingExif(at: temp),
                   let data = normalized.jpegData(compressionQuality: 0.92) {
                    try? data.write(to: temp)
                }
                DispatchQueue.main.async {
                    self.enterCompositionSelectedFromAlbum(temp)
                }
            }
            return
        }

        loadAlbumImageViaUIImageObject(from: provider)
    }

    /// Fallback when file representation is unavailable.
    private func loadAlbumImageViaUIImageObject(from provider: NSItemProvider) {
        guard provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            // Respect EXIF via UIImage, then bake upright (not preview-capture EXIF).
            let upright = image.lmNormalizedImage()
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("album_ref_\(UUID().uuidString).jpg")
            if let data = upright.jpegData(compressionQuality: 0.92) {
                try? data.write(to: url)
            }
            DispatchQueue.main.async {
                self.enterCompositionSelectedFromAlbum(url)
            }
        }
    }
}
