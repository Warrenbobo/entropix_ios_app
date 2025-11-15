//
//  LMCameraPage+InspireMe.swift
//  processor
//
//  Inspire Me feature implementation
//

import UIKit
import CoreML
import AVFoundation

// MARK: - Inspire Me Feature
extension LMCameraPage {
    
    func handleInspireMeFeature() {
        LMLogger.log("🎯 Starting Inspire Me feature...")
        
        guard validateCameraState(), let photoOutput = photoOutput else {
            return
        }
        
        showProcessingOverlay()
        isInspireMeCapture = true
        
        let photoSettings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
        
        LMLogger.log("📸 Inspire Me photo capture initiated")
    }
    
    func processInspireMeImage(_ image: UIImage) {
        LMLogger.log("📸 Processing Inspire Me image...")
        
        if detectImageBlur(image) {
            hideProcessingOverlay()
            showError("Image is too blurry. Please try again with better lighting or steadier hands.")
            return
        }
        
        LMLogger.log("✅ Image is sharp, proceeding with analysis...")
        
        let sceneFeature = analyzeSceneWithFastVLM(image)
        processAndUploadImage(image, sceneFeature: sceneFeature)
        syncInspirePointsToBackend()
    }
    
    func syncInspirePointsToBackend() {
        let subscriptionStatus = LMStoreManager.shared.currentSubscriptionStatus
        
        if subscriptionStatus == .free {
            LMLogger.log("📉 Decrementing Inspire Points for Free Plan user")
            inspireMeButtonView.decrementInspirePointsCount()
        }
    }
    
    func getUserInspirePoints() -> Int {
        return inspireMeButtonView.getCurrentInspirePoints()
    }
    
    func showInsufficientPointsAlert() {
        let alert = UIAlertController(
            title: "Out of Inspire Points",
            message: "Please subscribe or earn points by watching ads.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Watch Ads", style: .default) { _ in
            self.navigateToProfile()
        })
        
        alert.addAction(UIAlertAction(title: "Subscribe", style: .default) { _ in
            self.navigateToSubscription()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func navigateToProfile() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    func navigateToSubscription() {
        navigationController?.pushViewController(LMSubscriptionPage(), animated: true)
    }
}

// MARK: - Processing Overlay
extension LMCameraPage {
    
    func showProcessingOverlay() {
        hideProcessingOverlay()
        
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        overlayView.tag = ViewTag.processingOverlay.rawValue
        
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        
        let label = UILabel()
        label.text = LMText.camera.analyzingScene
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        
        overlayView.addSubview(spinner)
        overlayView.addSubview(label)
        view.addSubview(overlayView)
        
        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        spinner.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-20)
        }
        
        label.snp.makeConstraints { make in
            make.top.equalTo(spinner.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
        
        view.isUserInteractionEnabled = false
    }
    
    func hideProcessingOverlay() {
        view.viewWithTag(ViewTag.processingOverlay.rawValue)?.removeFromSuperview()
        view.isUserInteractionEnabled = true
    }
}
