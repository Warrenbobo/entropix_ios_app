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
        updateCameraPreviewAspectRatio(ratio)
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
    
    func updateCameraPreviewAspectRatio(_ ratio: LMAspectRatio) {
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        let preset: AVCaptureSession.Preset = (ratio == .ratio9_16) ? .hd1920x1080 : .photo
        if captureSession.canSetSessionPreset(preset) {
            captureSession.sessionPreset = preset
        }
        
        captureSession.commitConfiguration()
    }
    
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
    
    func cameraBottomControlsViewDidTapInspireButton() {
        LMLogger.log("🎯 Inspire button tapped")
        
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
