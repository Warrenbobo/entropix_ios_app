//
//  LMCameraPage+Delegates.swift
//  processor
//
//  Delegate implementations for camera controls and preview
//

import UIKit
import AVFoundation

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
        let alertController = UIAlertController(
            title: "Live Photos",
            message: "Live Photos is not supported on this device.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            self.cameraControlsView.updateLivePhotoStatus(false)
        }
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
}

// MARK: - Camera Bottom Controls Delegate
extension LMCameraPage: LMCameraBottomControlsViewDelegate {
    
    func cameraBottomControlsViewDidTapARGuidanceButton() {
        let isEnabled = cameraBottomControlsView.getCurrentARGuidanceStatus()
        LMLogger.log("🎯 AR Guidance: \(isEnabled ? "ON" : "OFF")")
        configureARGuidanceFeatures(isEnabled)
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
        
        let image = UIImage(cgImage: cgImage)
        
        LMLogger.log("✅ Frame captured from video stream, size: \(image.size)")
        
        // 在主线程处理图片
        DispatchQueue.main.async { [weak self] in
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
        let alertController = UIAlertController(
            title: "Inspire Me",
            message: "Tap to get AI-powered composition suggestions for your photo. Each use costs 1 Inspire Point.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
    
    func inspireMeButtonViewDidTapDisabledButton() {
        LMLogger.log("⚠️ Inspire Me button tapped while using front camera")
        
        // 显示前摄不可用提示
        let alertController = UIAlertController(
            title: "Inspire Me",
            message: "Inspire Me not available on front camera. Please switch to back camera to use this feature.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
}
