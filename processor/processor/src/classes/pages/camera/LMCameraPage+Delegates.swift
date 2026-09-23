//
//  LMCameraPage+Delegates.swift
//  processor
//
//  Delegate implementations for camera controls and preview
//

import UIKit
import AVFoundation
import Toast_Swift

// MARK: - Camera Preview Delegate
extension LMCameraPage: LMCameraPreviewViewDelegate {
    
    func cameraPreviewViewDidTapToFocus(at point: CGPoint) {
        guard let device = currentCameraDevice else { return }
        
        let devicePoint = cameraPreviewView.convertPointToDeviceCoordinates(point)
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            LMLogger.log("❌ Error setting focus: \(error)")
        }
    }
    
    func cameraPreviewViewDidPinchToZoom(scale: CGFloat) {
        guard let device = currentCameraDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            let currentZoomFactor = device.videoZoomFactor
            let newZoomFactor = min(max(currentZoomFactor * scale, 1.0), device.activeFormat.videoMaxZoomFactor)
            
            device.videoZoomFactor = newZoomFactor
            device.unlockForConfiguration()
        } catch {
            LMLogger.log("❌ Error setting zoom: \(error)")
        }
    }
}

// MARK: - Camera Controls Delegate
extension LMCameraPage: LMCameraControlsViewDelegate {
    
    func cameraControlsView(_ view: LMCameraControlsView, didChangeFlashMode mode: LMFlashMode) {
        guard ensureCameraPermissionForInteraction() else { return }
        LMLogger.log("⚡ Flash mode: \(mode.displayName)")
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didChangeAspectRatio ratio: LMAspectRatio) {
        guard ensureCameraPermissionForInteraction() else { return }
        LMLogger.log("📐 Aspect ratio: \(ratio.displayName)")
        // 更新预览画布的尺寸，而不是改变相机的输出尺寸
        updatePreviewCanvasAspectRatio(ratio)
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didChangeTimer duration: LMTimerDuration) {
        guard ensureCameraPermissionForInteraction() else { return }
        LMLogger.log("⏱️ Timer: \(duration.displayName)")
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didToggleLivePhoto enabled: Bool) {
        guard ensureCameraPermissionForInteraction() else { return }
        LMLogger.log("📸 Live Photo: \(enabled ? "ON" : "OFF")")
        configureLivePhotosMode(enabled)
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didToggleGrid enabled: Bool) {
        guard ensureCameraPermissionForInteraction() else { return }
        LMLogger.log("🔲 Grid: \(enabled ? "ON" : "OFF")")
        cameraPreviewView.setGridVisibility(enabled)
    }

    func cameraControlsView(_ view: LMCameraControlsView, didToggleBoxGuidance enabled: Bool) {
        guard ensureCameraPermissionForInteraction() else { return }
        LMLogger.log("📐 Framing guidance: \(enabled ? "ON" : "OFF")")
        setBoxGuidanceEnabledFromSidebar(enabled)
    }

    func cameraControlsView(_ view: LMCameraControlsView, didToggleLineArtGuidance enabled: Bool) {
        guard ensureCameraPermissionForInteraction() else { return }
        LMLogger.log("🧍 Pose guidance: \(enabled ? "ON" : "OFF")")
        setLineArtGuidanceEnabledFromSidebar(enabled)
    }

    func cameraControlsViewDidTapAgentToggle(_ view: LMCameraControlsView) {
        guard ensureCameraPermissionForInteraction() else { return }
        toggleAgentGuidance()
    }

    func cameraControlsViewDidTapFlipCamera(_ view: LMCameraControlsView) {
        guard ensureCameraPermissionForInteraction() else { return }
        LMLogger.log("🔄 Flipping camera")
        switchCameraPosition()
    }
    
    // MARK: - Configuration Methods
    // 注意：相机始终以原始比例捕获，宽高比的改变只影响预览画布的显示尺寸
    
    func configureLivePhotosMode(_ enabled: Bool) {
        guard let photoOutput = photoOutput else { return }
        
        if enabled && !photoOutput.isLivePhotoCaptureSupported {
            showLivePhotosNotSupportedAlert()
            return
        }
        
        photoOutput.isLivePhotoCaptureEnabled = enabled
    }
    
    func showLivePhotosNotSupportedAlert() {
        LMAlertDialog.showGeneralAlert(LMText.camera.livePhotosNotSupported,
            title: LMText.camera.livePhotos,
            onConfirm: { [weak self] in
                self?.cameraControlsView.updateLivePhotoStatus(false)
            }
        )
    }
}

// MARK: - Camera Bottom Controls Delegate
extension LMCameraPage: LMCameraBottomControlsViewDelegate {
    
    func cameraBottomControlsViewDidTapMyReference() {
        guard ensureCameraPermissionForInteraction() else { return }
        switch currentCameraState {
        case .normal, .exploreGoToSpot:
            presentAlbumPicker()
        default:
            break
        }
    }

    func cameraBottomControlsViewDidTapGetTips() {
        guard ensureCameraPermissionForInteraction() else { return }
        guard currentCameraState == .compositionSelected else { return }
        beginInstructRound()
    }
    
    func cameraBottomControlsViewDidTapCaptureButton() {
        guard ensureCameraPermissionForInteraction() else { return }

        // Composition-selected: shutter is photo-only (Get Tips is separate).
        if currentCameraState == .compositionSelected {
            if shutterRole == .instructRunning { return }
            capturePhotoWithOptionalTimer()
            return
        }

        // SS-09: compact shutter still shoots while browsing suggestions.
        if currentCameraState == .showingSuggestions {
            capturePhotoWithOptionalTimer()
            return
        }

        switch currentCameraState {
        case .normal, .exploreGoToSpot:
            break
        default:
            return
        }

        let mode = (currentCameraState == .exploreGoToSpot)
            ? LMPreShootPlanMode.composition
            : preShootPlanMode

        switch mode {
        case .camera:
            capturePhotoWithOptionalTimer()
        case .findSpot:
            if isUsingFrontCamera {
                AppTheme.Toast.showText(LMText.camera.inspireMeFrontCameraHint)
                return
            }
            handleFindSpotFeature()
        case .composition:
            if isUsingFrontCamera {
                AppTheme.Toast.showText(LMText.camera.inspireMeFrontCameraHint)
                return
            }
            beginCompositionInspireFromPreShootPlan()
        }
    }

    /// Runs timer countdown when configured, otherwise captures immediately.
    private func capturePhotoWithOptionalTimer() {
        let timerDuration = cameraControlsView.getCurrentTimerDuration().seconds
        if timerDuration > 0 {
            LMLogger.log("⏱️ Starting \(timerDuration)s timer capture")
            showCountdownTimer(duration: timerDuration, completion: capturePhoto)
        } else {
            capturePhoto()
        }
    }
}

// MARK: - Video Data Output Delegate
extension LMCameraPage: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            cacheLatestPreviewPixelBuffer(imageBuffer)
        }

        if shouldCaptureNextFrame {
            handleInspireMeFrameCapture(sampleBuffer)
            return
        }
        
        // 处理 AR Guidance 功能的实时检测
        if isARGuidanceActive {
            processARGuidanceFrame(sampleBuffer)
        }
    }
    
    /// 处理 Inspire Me 的帧捕获
    private func handleInspireMeFrameCapture(_ sampleBuffer: CMSampleBuffer) {
        // 重置标志，避免重复捕获
        shouldCaptureNextFrame = false
        
        // 从 sample buffer 中提取图片
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            LMLogger.log("❌ Failed to get image buffer from sample buffer")
            DispatchQueue.main.async { [weak self] in
                self?.isInspireMeCapture = false
                self?.inspireMeCaptureDeviceOrientation = nil
                self?.finishInspireProcessingFailed()
                AppTheme.Toast.showText(LMText.camera.failedToCaptureFrame)
            }
            return
        }

        let deviceOrientation = inspireMeCaptureDeviceOrientation ?? LMOrientationMatcher.orientationForCapture()

        guard let image = LMPreviewFramePipeline.makeUIImage(
            from: imageBuffer,
            orientationPolicy: .locked(deviceOrientation),
            isFrontCamera: isUsingFrontCamera
        ) else {
            LMLogger.log("❌ Failed to create CGImage from CIImage")
            DispatchQueue.main.async { [weak self] in
                self?.isInspireMeCapture = false
                self?.inspireMeCaptureDeviceOrientation = nil
                self?.finishInspireProcessingFailed()
                AppTheme.Toast.showText(LMText.camera.failedToProcessFrame)
            }
            return
        }

        inspireMeCaptureDeviceOrientation = nil
        LMLogger.log("✅ Frame captured from video stream, size: \(image.size), deviceOrientation: \(deviceOrientation.rawValue)")
        
        // 在主线程处理图片
        DispatchQueue.main.async { [weak self] in
            // Direct Gemini: skip long Inspiring freeze — placeholders appear ASAP.
            if !LMFeatureFlagsManager.inspireMeDirectGeminiEnabled {
                self?.showProcessingOverlay(with: image)
            }
            self?.processInspireMeImage(image)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 可选：记录丢帧情况
        // LMLogger.log("⚠️ Video frame dropped")
    }
}

// MARK: - Pre-Shoot Plan Button Delegate
extension LMCameraPage: LMPreShootPlanButtonViewDelegate {

    /// Mode chip tap opens the 1×3 selector (shutter executes the mode).
    func preShootPlanButtonDidTap() {
#if DEBUG
        if !debugShouldBypassInspireMePermissionCheck {
            guard ensureCameraPermissionForInteraction() else { return }
        }
#else
        guard ensureCameraPermissionForInteraction() else { return }
#endif
        guard preShootPlanModeSwitchEnabled, currentCameraState != .exploreGoToSpot else { return }
        presentPreShootPlanModeSheet()
    }

    func preShootPlanButtonDidTapDisabled() {
        guard ensureCameraPermissionForInteraction() else { return }
        AppTheme.Toast.showText(LMText.camera.inspireMeFrontCameraHint)
    }

    func preShootPlanButtonDidTapHint() {
        guard ensureCameraPermissionForInteraction() else { return }
        showTutorialFromStart()
    }

    /// Composition-mode gate then existing Inspire Me pipeline.
    func beginCompositionInspireFromPreShootPlan() {
        if currentCameraState == .exploreGoToSpot {
            // Path B: composing ends Explore session and writes history.
            endExploreSessionWritingHistory()
            currentCameraState = .normal
        }

        if LMFeatureFlagsManager.inspireMeDirectGeminiEnabled {
            if !LMLlmModuleSettingsStore.isConfigured(.ideaInspiration) {
                presentMissingModelConfig(for: .ideaInspiration)
                return
            }
            if !LMLlmCallQuotaStore.hasRemaining(for: .ideaInspiration) {
                presentMissingModelConfig(for: .ideaInspiration)
                return
            }
            handleInspireMeFeature()
            return
        }

        // FRAMAIST_BACKEND_DISABLED — skip FramAist subscription / inspire-points gates.
        handleInspireMeFeature()
        /*
        if !LMFeatureFlagsManager.backendApiEnabled {
            handleInspireMeFeature()
            return
        }

        let subscriptionStatus = LMStoreManager.shared.currentSubscriptionStatus
        if subscriptionStatus == .free {
            let remainingPoints = getUserInspirePoints()
            if remainingPoints < 1 {
                showInsufficientPointsAlert()
                return
            }
        }
        handleInspireMeFeature()
        */
    }
}
