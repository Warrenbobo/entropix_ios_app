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
        guard currentCameraState == .normal else { return }
        presentAlbumPicker()
    }
    
    func cameraBottomControlsViewDidTapCaptureButton() {
        guard ensureCameraPermissionForInteraction() else { return }

        if agentGuidanceState == .agent && shutterRole == .instructReady {
            beginInstructRound()
            return
        }
        if shutterRole == .instructRunning { return }

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
                self?.hideProcessingOverlay()
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
