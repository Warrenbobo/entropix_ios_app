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
        LMLogger.log("⚡ Flash mode: \(mode.displayName)")
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didChangeAspectRatio ratio: LMAspectRatio) {
        LMLogger.log("📐 Aspect ratio: \(ratio.displayName)")
        // 更新预览画布的尺寸，而不是改变相机的输出尺寸
        updatePreviewCanvasAspectRatio(ratio)
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didChangeTimer duration: LMTimerDuration) {
        LMLogger.log("⏱️ Timer: \(duration.displayName)")
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didToggleLivePhoto enabled: Bool) {
        LMLogger.log("📸 Live Photo: \(enabled ? "ON" : "OFF")")
        configureLivePhotosMode(enabled)
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didToggleGrid enabled: Bool) {
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
        let config = LMAlertDialogConfig(
            title: "Live Photos",
            message: "Live Photos is not supported on this device.",
            cancelButtonText: "",
            confirmButtonText: "OK",
            confirmButtonStyle: .normal,
            onConfirm: { [weak self] in
                self?.cameraControlsView.updateLivePhotoStatus(false)
            }
        )
        let dialog = LMAlertDialog(config: config)
        dialog.show(on: self)
    }
}

// MARK: - Camera Bottom Controls Delegate
extension LMCameraPage: LMCameraBottomControlsViewDelegate {
    
    func cameraBottomControlsViewDidTapARGuidanceButton() {
        let isActive = cameraBottomControlsView.isARGuidanceActive()
        LMLogger.log("🎯 AR Guidance: \(isActive ? "ON" : "OFF")")
        
        // 如果在 Show Suggestions 状态下开启 AR Guidance，需要先显示 Reference Image
        if isActive && currentCameraState == .showingSuggestions {
            // 检查是否有选中的构图
            guard let selectedSuggestion = suggestionsCarouselView?.getSelectedSuggestion() else {
                LMLogger.log("⚠️ No suggestion selected, cannot enable AR Guidance")
                // 将 AR Guidance 状态改回 available（关闭状态）
                cameraBottomControlsView.setARGuidanceAvailable(true)
                showToast("Please select a composition first")
                return
            }
            
            // 进入 Composition Selected 状态并显示 Reference Image
            enterCompositionSelectedStateFromSuggestion(with: selectedSuggestion)
        }
        
        configureARGuidanceFeatures(isActive)
    }
    
    /// 从Show Suggestions进入Composition Selected状态
    private func enterCompositionSelectedStateFromSuggestion(with suggestion: LMCompositionSuggestion) {
        guard let image = UIImage(named: suggestion.similarImageUrl ?? "") else {
            LMLogger.log("❌ Suggestion没有图片")
            showToast("Failed to load reference image")
            return
        }
        
        // 设置当前Reference Image
        currentReferenceImage = image
        currentSuggestion = suggestion
        
        // 更新状态
        currentCameraState = .compositionSelected
        
        // 隐藏Suggestions轮播
        suggestionsCarouselView?.isHidden = true
        
        // 显示Reference Image（左下角）
        // TODO: 实现Reference Image显示逻辑
        
        // 检测人物并显示AR引导
        detectPersonAndShowGuidance(in: image)
        
        LMLogger.log("✅ 从Show Suggestions进入Composition Selected状态")
    }
    
    func cameraBottomControlsViewDidTapUnavailableARGuidance() {
        LMLogger.log("⚠️ User tapped unavailable AR Guidance button")
        showToast("AR Guidance is only available after using Inspire Me")
    }
    
    func cameraBottomControlsViewDidTapCaptureButton() {
        let timerDuration = cameraControlsView.getCurrentTimerDuration().seconds
        
        if timerDuration > 0 {
            LMLogger.log("⏱️ Starting \(timerDuration)s timer capture")
            showCountdownTimer(duration: timerDuration, completion: capturePhoto)
        } else {
            capturePhoto()
        }
    }
    
    func cameraBottomControlsViewDidTapFlipCameraButton() {
        LMLogger.log("🔄 Flipping camera")
        switchCameraPosition()
    }
}

// MARK: - Video Data Output Delegate
extension LMCameraPage: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
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
                self?.hideProcessingOverlay()
                self?.showAlert("Failed to capture frame from video stream", style: .error)
            }
            return
        }
        
        // 转换为 UIImage
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            LMLogger.log("❌ Failed to create CGImage from CIImage")
            DispatchQueue.main.async { [weak self] in
                self?.hideProcessingOverlay()
                self?.showAlert("Failed to process captured frame", style: .error)
            }
            return
        }
        
        // 获取正确的图片方向
        let imageOrientation = getImageOrientation()
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: imageOrientation)
        
        LMLogger.log("✅ Frame captured from video stream, size: \(image.size), orientation: \(imageOrientation.rawValue)")
        
        // 在主线程处理图片
        DispatchQueue.main.async { [weak self] in
            self?.processInspireMeImage(image)
        }
    }
    
    /// 根据设备方向和相机位置获取正确的图片方向
    private func getImageOrientation() -> UIImage.Orientation {
        let isFrontCamera = isUsingFrontCamera
        return isFrontCamera ? .leftMirrored : .right
    }
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 可选：记录丢帧情况
        // LMLogger.log("⚠️ Video frame dropped")
    }
}

// MARK: - Inspire Me Button Delegate
extension LMCameraPage: LMInspireMeButtonViewDelegate {
    
    func inspireMeButtonViewDidTapButton() {
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
        LMLogger.log("❓ Inspire Me question button tapped")
        
        // 显示 Inspire Me 功能说明
        showToast("Tap to get AI-powered composition suggestions for your photo. Each use costs 1 Inspire Point.")
    }
    
    func inspireMeButtonViewDidTapDisabledButton() {
        LMLogger.log("⚠️ Inspire Me button tapped while using front camera")
        
        // 显示前摄不可用提示
        showToast("Inspire Me not available on front camera. Please switch to back camera to use this feature.")
    }
}
