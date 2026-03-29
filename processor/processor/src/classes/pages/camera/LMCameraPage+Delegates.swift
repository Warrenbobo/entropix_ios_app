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
    
    func cameraBottomControlsViewDidTapARGuidanceButton() {
        guard ensureCameraPermissionForInteraction() else { return }
        let buttonState = cameraBottomControlsView.getARGuidanceState()
        preferredARGuidanceButtonState = buttonState == .unavailable ? preferredARGuidanceButtonState : buttonState
        LMLogger.log("🎯 AR Guidance state: \(buttonState.logName)")
        
        // 隐藏 Step 3 引导（用户点击了 AR Guidance 按钮）
        hideARGuidanceGuide()
        
        // 仅 Box 模式需要 Step 4 引导
        if buttonState != .box {
            hideAlignBoxesGuide()
        }
        
        if buttonState == .box {
            // 延迟显示 Step 4，等待 AR Guidance 初始化完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAlignBoxesGuideIfNeeded()
            }
        }
        
        // 如果在 Show Suggestions 状态下开启 AR Guidance，需要先显示 Reference Image
        if buttonState.isEnabledGuidance && currentCameraState == .showingSuggestions {
            // 检查是否有选中的构图和对应的卡片视图
            guard let selectedCardView = suggestionsCarouselView?.getSelectedCardView(),
                  let selectedSuggestion = suggestionsCarouselView?.getSelectedSuggestion(),
                  let image = selectedCardView.displayedImage else {
                LMLogger.log("⚠️ No suggestion selected or image not loaded, cannot enable AR Guidance")
                cameraBottomControlsView.setARGuidanceState(.off)
                preferredARGuidanceButtonState = .off
                AppTheme.Toast.showText(LMText.camera.selectCompositionFirst)
                return
            }
            
            // 进入 Composition Selected 状态并显示 Reference Image
            enterCompositionSelectedStateFromSuggestion(with: selectedSuggestion, image: image)
            return
        }
        
        configureARGuidanceMode(buttonState)
    }
    
    /// 从Show Suggestions进入Composition Selected状态
    /// - Parameters:
    ///   - suggestion: 选中的构图方案
    ///   - image: 从卡片视图获取的已显示图片
    private func enterCompositionSelectedStateFromSuggestion(with suggestion: LMCompositionSuggestion, image: UIImage) {
        enterCompositionSelectedState(with: suggestion, image: image)
    }
    
    func cameraBottomControlsViewDidTapUnavailableARGuidance() {
        guard ensureCameraPermissionForInteraction() else { return }
        // 不做任何处理，unavailable 状态下点击无效果
        LMLogger.log("⚠️ User tapped unavailable AR Guidance button - ignored")
    }
    
    func cameraBottomControlsViewDidTapCaptureButton() {
        guard ensureCameraPermissionForInteraction() else { return }
        let timerDuration = cameraControlsView.getCurrentTimerDuration().seconds
        
        if timerDuration > 0 {
            LMLogger.log("⏱️ Starting \(timerDuration)s timer capture")
            showCountdownTimer(duration: timerDuration, completion: capturePhoto)
        } else {
            capturePhoto()
        }
    }
    
    func cameraBottomControlsViewDidTapFlipCameraButton() {
        guard ensureCameraPermissionForInteraction() else { return }
        LMLogger.log("🔄 Flipping camera")
        switchCameraPosition()
    }
}

// MARK: - Video Data Output Delegate
extension LMCameraPage: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            cacheLatestPreviewPixelBuffer(imageBuffer)
        }

        // 处理 Inspire Me 功能的帧捕获
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
                self?.hideProcessingOverlay()
                AppTheme.Toast.showText(LMText.camera.failedToCaptureFrame)
            }
            return
        }

        let deviceOrientation = inspireMeCaptureDeviceOrientation ?? LMOrientationMatcher.getCurrentDeviceOrientation()

        guard let image = makeInspireMeImage(from: imageBuffer, deviceOrientation: deviceOrientation) else {
            LMLogger.log("❌ Failed to create CGImage from CIImage")
            DispatchQueue.main.async { [weak self] in
                self?.isInspireMeCapture = false
                self?.inspireMeCaptureDeviceOrientation = nil
                self?.hideProcessingOverlay()
                AppTheme.Toast.showText(LMText.camera.failedToProcessFrame)
            }
            return
        }

        inspireMeCaptureDeviceOrientation = nil
        LMLogger.log("✅ Frame captured from video stream, size: \(image.size), deviceOrientation: \(deviceOrientation.rawValue)")
        
        // 在主线程处理图片
        DispatchQueue.main.async { [weak self] in
            self?.showProcessingOverlay(with: image)
            self?.processInspireMeImage(image)
        }
    }
    
    /// 根据设备方向和相机位置获取正确的图片方向
    func getImageOrientation(for deviceOrientation: UIDeviceOrientation) -> UIImage.Orientation {
        let isFrontCamera = isUsingFrontCamera
        
        // 使用与拍照一致的方向映射：先保证帧在“当前手持方向”下是正的
        // Inspire Me 后续会基于点击时的设备方向再旋转成“home键在下方”的竖屏图
        if isFrontCamera {
            switch deviceOrientation {
            case .portrait:
                return .leftMirrored
            case .landscapeLeft:
                return .downMirrored
            case .landscapeRight:
                return .upMirrored
            case .portraitUpsideDown:
                return .rightMirrored
            default:
                return .leftMirrored
            }
        } else {
            switch deviceOrientation {
            case .portrait:
                return .right
            case .landscapeLeft:
                return .up
            case .landscapeRight:
                return .down
            case .portraitUpsideDown:
                return .left
            default:
                return .right
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 可选：记录丢帧情况
        // LMLogger.log("⚠️ Video frame dropped")
    }
}

// MARK: - Inspire Me Button Delegate
extension LMCameraPage: LMInspireMeButtonViewDelegate {
    
    func inspireMeButtonViewDidTapButton() {
#if DEBUG
        if !debugShouldBypassInspireMePermissionCheck {
            guard ensureCameraPermissionForInteraction() else { return }
        }
#else
        guard ensureCameraPermissionForInteraction() else { return }
#endif
        LMLogger.log("🎯 Inspire Me button tapped")
        
        let subscriptionStatus = LMStoreManager.shared.currentSubscriptionStatus
        
        if subscriptionStatus == .free {
            let remainingPoints = getUserInspirePoints()
            if remainingPoints < 1 {
                showInsufficientPointsAlert()
                return
            }
        }
        
        handleInspireMeFeature()
    }
    
    func inspireMeButtonViewDidTapQuestionButton() {
        guard ensureCameraPermissionForInteraction() else { return }
        LMLogger.log("❓ Inspire Me question button tapped")
        showTutorialFromStart()
    }
    
    func inspireMeButtonViewDidTapDisabledButton() {
        guard ensureCameraPermissionForInteraction() else { return }
        LMLogger.log("⚠️ Inspire Me button tapped while using front camera")
        
        // 显示前摄不可用提示
        AppTheme.Toast.showText(LMText.camera.inspireMeFrontCameraHint)
    }
}
