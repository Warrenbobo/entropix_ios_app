//
//  LMCameraPage+AgentCoaching.swift
//  processor
//

import UIKit
import PhotosUI

extension LMCameraPage: LMAgentCoachingUIDelegate {

    /// Installs agent coaching HUD and wires controller delegate.
    func setupAgentCoachingHUDIfNeeded() {
        agentCoachingController.uiDelegate = self
        setupAgentLogButtonIfNeeded()

        if scoreDonutOverlayView == nil {
            let size = LMCameraConstants.agentScoreDonutSize
            let donut = LMScoreDonutOverlayView(frame: .zero)
            view.addSubview(donut)
            donut.snp.makeConstraints { make in
                make.leading.equalToSuperview().offset(LMCameraConstants.agentScoreDonutLeading)
                make.size.equalTo(CGSize(width: size, height: size))
                scoreDonutTopConstraint = make.top
                    .equalTo(view.safeAreaLayoutGuide.snp.top)
                    .offset(LMCameraConstants.agentScoreDonutAbsoluteTopOffset)
                    .constraint
            }
            donut.onDragBegan = { [weak self] in
                self?.setScoreDonutManualPositionEnabled(true)
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
            bubble.onDismissToolTapped = { [weak self] in
                self?.dismissActiveExecutionTool()
            }
        }
    }

    /// Clears the active box/line-art execution overlay (Android dismiss pill parity).
    func dismissActiveExecutionTool() {
        boxAlignCompleteWorkItem?.cancel()
        boxAlignCompleteWorkItem = nil
        executionTool = .none
        applyExecutionToolToOverlay()
        refreshCoachingBubble()
    }

    private func setScoreDonutManualPositionEnabled(_ manual: Bool) {
        if manual {
            scoreDonutTopConstraint?.deactivate()
            view.layoutIfNeeded()
            return
        }

        scoreDonutTopConstraint?.activate()
        view.setNeedsLayout()
        view.layoutIfNeeded()
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
        let agentOn = agentGuidanceState == .agent && isComposition

        cameraControlsView.setAgentToggleVisible(isComposition && currentReferenceImage != nil)
        cameraControlsView.setAgentToggleState(agentGuidanceState)
        cameraBottomControlsView.setARGuidanceContainerHidden(
            isComposition || currentCameraState == .showingSuggestions
        )
        if agentOn {
            updateShutterRoleForAgentState(agentCoachingController.agentState)
        } else {
            shutterRole = .captureDefault
            cameraBottomControlsView.setShutterRole(.captureDefault)
        }

        setupAgentCoachingHUDIfNeeded()
        updateCoachingBubbleVisibility()
        scoreDonutOverlayView?.setVisible(agentOn)
        if agentOn {
            refreshCoachingBubble()
        } else {
            hasUserTriggeredInstructInSession = false
            resetCoachingSessionUI()
        }

        if agentOn && referenceWarmupComplete {
            agentCoachingController.setReferenceImage(currentReferenceImage, bbox: currentReferenceBbox)
            // Eligibility = reference person mask present (LineArt image itself is lazy).
            agentCoachingController.setLineArtReady(
                LMHumanUnderstandingService.shared.referenceSnapshot != nil
            )
            agentCoachingController.startScoreLoop { [weak self] in
                self?.capturePreviewFrameForScoring()
            }
            if let score = agentCoachingController.latestScore {
                scoreDonutOverlayView?.apply(score: score)
            }
        } else {
            agentCoachingController.stopScoreLoop()
        }

        applyExecutionToolToOverlay()
    }

    func toggleAgentGuidance() {
        guard currentCameraState == .compositionSelected else { return }
        agentGuidanceState = agentGuidanceState.nextToggleState
        if agentGuidanceState == .agent {
            agentCoachingController.softResetAgentSession()
            shutterRole = .instructReady
            hasUserTriggeredInstructInSession = false
        } else {
            shutterRole = .captureDefault
            executionTool = .none
            hasUserTriggeredInstructInSession = false
        }
        syncAgentCoachingForCurrentState()
    }

    func beginInstructRound() {
        guard agentGuidanceState == .agent, shutterRole == .instructReady else { return }
        hasUserTriggeredInstructInSession = true
        resetCoachingSessionUI()
        agentCoachingController.markCoachingFinal(false)
        updateShutterRoleForAgentState(.running)

        agentCoachingController.runAgentRound { [weak self] in
            self?.capturePreviewFrameForScoring()
        }
    }

    /// Derives shutter role from agent state (Android `CameraUiState.shutterRole` parity).
    func updateShutterRoleForAgentState(_ state: LMAgentState) {
        guard agentGuidanceState == .agent, currentCameraState == .compositionSelected else { return }

        switch state {
        case .running:
            shutterRole = .instructRunning
        case .finished:
            shutterRole = .captureReady
        case .idle, .error:
            shutterRole = .instructReady
        }
        cameraBottomControlsView.setShutterRole(shutterRole)
        updateCoachingBubbleVisibility()
        refreshCoachingBubble(agentState: state, isFinished: state == .finished)
    }

    func enterCompositionSelected(
        with suggestion: LMCompositionSuggestion,
        image: UIImage?
    ) {
        compositionEntrySource = currentCameraState == .showingSuggestions ? .showingSuggestions : .normal

        if let image {
            currentReferenceImage = image
        }
        currentSuggestion = suggestion
        currentCameraState = .compositionSelected
        agentGuidanceState = .agent
        executionTool = .none
        shutterRole = .instructReady
        hasUserTriggeredInstructInSession = false
        referenceWarmupComplete = false
        resetCoachingSessionUI()

        inspireMeButtonView.isHidden = true
        hideSuggestionsCarousel()
        bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
        cameraBottomControlsView.setLayoutMode(.normal, animated: true)

        if let image {
            showReferenceImageInCorner(suggestion: suggestion)
        }

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
        let image = UIImage(contentsOfFile: imageURL.path)
            ?? (try? Data(contentsOf: imageURL)).flatMap { UIImage(data: $0) }
        enterCompositionSelected(with: suggestion, image: image)
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
        let orientation = LMOrientationMatcher.orientationForCapture()
        return LMPreviewFramePipeline.makeUIImage(
            from: pixelBuffer,
            orientationPolicy: .locked(orientation),
            isFrontCamera: isUsingFrontCamera
        )
    }

    /**
     Generates Asset LineArt once for the current reference (plan §4.5).
     Cache hits return immediately; clears with `clearLineArtOverlay` / reference change.
     */
    func ensureLineArtReadyForCallout() {
        if currentReferenceLineArtImage != nil {
            arGuidanceView.setLineArtImage(currentReferenceLineArtImage)
            agentCoachingController.setLineArtReady(true)
            return
        }
        guard let image = currentReferenceImage else { return }

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
            }
        }
    }

    func applyExecutionToolToOverlay() {
        let overlay = LMARGuidanceOverlayDisplay(
            executionTool: executionTool,
            agentEnabled: agentGuidanceState == .agent
        )
        arGuidanceView.setOverlayDisplay(overlay)
        isARGuidanceActive = agentGuidanceState == .agent && executionTool != .none
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
        agentCoachingController.markCoachingFinal(false)
    }

    /// After box alignment holds, clear overlay and show the Android-parity coaching hint.
    func scheduleBoxAlignCoachingUpdateIfNeeded() {
        guard agentGuidanceState == .agent, executionTool == .box else { return }
        boxAlignCompleteWorkItem?.cancel()
        let policy = LMCoachingPolicyConfig.default
        let delay = TimeInterval(policy.executionToolsBoxAlignHoldMs + 300) / 1000
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.executionTool == .box, self.isCurrentlyAligned else { return }
            self.executionTool = .none
            self.applyExecutionToolToOverlay()
            self.coachingActionText = LMText.camera.agentBoxAlignedMessage
            self.coachingReasoningExpanded = false
            self.agentCoachingController.markCoachingFinal(true)
            self.refreshCoachingBubble(isFinal: true)
        }
        boxAlignCompleteWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Auto-dismiss line-art overlay after the policy hold (Android parity).
    func scheduleLineArtAutoDismissIfNeeded() {
        guard executionTool == .lineArt else { return }
        lineArtAutoDismissWorkItem?.cancel()
        let delay = TimeInterval(LMCoachingPolicyConfig.default.executionToolsLineArtAutoDismissMs) / 1000
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.executionTool == .lineArt else { return }
            self.dismissActiveExecutionTool()
        }
        lineArtAutoDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func toggleCoachingReasoningExpanded() {
        coachingReasoningExpanded.toggle()
        refreshCoachingBubble()
    }

    private func refreshCoachingBubble(
        agentState: LMAgentState? = nil,
        isFinished: Bool? = nil,
        isFinal: Bool? = nil
    ) {
        let resolvedState = agentState ?? agentCoachingController.agentState
        let resolvedFinished = isFinished ?? (resolvedState == .finished)
        let resolvedFinal = isFinal ?? agentCoachingController.coachingIsFinal
        let showSkip = agentCoachingController.skipEnabled &&
            resolvedFinal &&
            resolvedState != .running &&
            !coachingActionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        coachingBubbleView?.update(
            instruction: coachingActionText.isEmpty ? nil : coachingActionText,
            reasoning: coachingReasoningText.isEmpty ? nil : coachingReasoningText,
            reasoningExpanded: coachingReasoningExpanded,
            agentState: resolvedState,
            isFinished: resolvedFinished,
            showSkip: showSkip,
            executionTool: executionTool
        )
        updateCoachingBubbleVisibility()
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

    func agentCoaching(didUpdateAction displayText: String, isFinal: Bool) {
        coachingActionText = displayText
        if !displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            coachingReasoningExpanded = false
        }
        agentCoachingController.markCoachingFinal(isFinal)
        let state = isFinal && agentCoachingController.agentState == .running
            ? LMAgentState.running
            : agentCoachingController.agentState
        refreshCoachingBubble(agentState: state, isFinal: isFinal)
    }

    func agentCoaching(didSetExecutionTool tool: LMExecutionTool, instruction: String?) {
        executionTool = tool
        if tool == .lineArt {
            ensureLineArtReadyForCallout()
            scheduleLineArtAutoDismissIfNeeded()
        } else {
            lineArtAutoDismissWorkItem?.cancel()
            lineArtAutoDismissWorkItem = nil
        }
        if let instruction {
            coachingActionText = instruction
            coachingReasoningExpanded = false
            refreshCoachingBubble(agentState: .running, isFinal: false)
        }
        applyExecutionToolToOverlay()
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
}

// MARK: - PHPickerViewControllerDelegate
extension LMCameraPage: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self, let image = object as? UIImage else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("album_ref_\(UUID().uuidString).jpg")
            if let data = image.jpegData(compressionQuality: 0.92) {
                try? data.write(to: url)
            }
            DispatchQueue.main.async {
                self.enterCompositionSelectedFromAlbum(url)
            }
        }
    }
}
