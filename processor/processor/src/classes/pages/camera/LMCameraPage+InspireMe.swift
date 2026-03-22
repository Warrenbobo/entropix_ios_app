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
    
    /// 验证相机状态是否可以使用 Inspire Me 功能
    private func validateCameraState() -> Bool {
        // 检查当前相机页面状态，只有在 normal 状态下才能使用 Inspire Me
        guard currentCameraState == .normal else {
            LMLogger.log("⚠️ Cannot use Inspire Me - current state is \(currentCameraState), not normal")
            return false
        }
        
        // 检查是否正在使用后置摄像头
        guard !isUsingFrontCamera else {
            LMLogger.log("⚠️ Cannot use Inspire Me with front camera")
            AppTheme.Toast.showText(LMText.camera.inspireMeOnlyBackCamera)
            return false
        }
        
        // 检查相机会话是否正在运行
        guard let captureSession = captureSession, captureSession.isRunning else {
            LMLogger.log("⚠️ Camera session is not running")
            AppTheme.Toast.showText(LMText.camera.cameraNotReady)
            return false
        }
        
        // 检查是否已经在处理中
        guard !isInspireMeCapture else {
            LMLogger.log("⚠️ Inspire Me is already processing")
            return false
        }
        
        return true
    }
    
    func handleInspireMeFeature() {
        LMLogger.log("🎯 Starting Inspire Me feature...")
        
        // 隐藏 Step 1 引导（用户点击了 Inspire Me 按钮）
        hideInspireMeGuide()
        
        // 检查登录状态
        guard requireLogin(action: "use Inspire Me feature") else {
            return
        }
        
        guard validateCameraState() else {
            return
        }

        isInspireMeCapture = true
        
        // 记录点击瞬间的设备方向（后续用于把帧旋转到竖屏“home键在下方”的预览样式）
        inspireMeCaptureDeviceOrientation = LMOrientationMatcher.getCurrentDeviceOrientation()
        
        // 从相机流中获取当前帧图片
        captureFrameFromVideoStream()
        
        LMLogger.log("📸 Inspire Me capturing frame from video stream")
    }
    
    /// 从视频流中捕获当前帧
    private func captureFrameFromVideoStream() {
        // 设置标志，让视频流代理捕获下一帧
        shouldCaptureNextFrame = true
    }
    
    func processInspireMeImage(_ image: UIImage) {
        LMLogger.log("📸 Processing Inspire Me image...")
        currentProcessingSceneryImage = image
        updateProcessingOverlaySceneryImage(image)
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
        // First show the main alert
        let config = LMAlertDialogConfig(
            title: LMText.camera.outOfInspirePoints,
            message: LMText.camera.subscribeOrWatchAds,
            cancelButtonText: LMText.common.cancel,
            confirmButtonText: LMText.profile.watchAds,
            confirmButtonStyle: .normal,
            onConfirm: { [weak self] in
                self?.navigateToProfile()
            }
        )
        let dialog = LMAlertDialog(config: config)
        
        // Add a custom action sheet for multiple options
        // For now, we'll use the simpler two-button approach
        // TODO: Consider creating a custom action sheet component for 3+ options
        dialog.show()
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
        showProcessingOverlay(with: currentProcessingSceneryImage)
    }

    func showProcessingOverlay(with image: UIImage?) {
        hideProcessingOverlay()

        currentProcessingSceneryImage = image

        let overlayView = UIView()
        overlayView.backgroundColor = .clear
        overlayView.tag = ViewTag.processingOverlay.rawValue
        overlayView.isUserInteractionEnabled = false
        overlayView.clipsToBounds = true
        previewCanvasView.addSubview(overlayView)

        let sceneryImageView = UIImageView()
        sceneryImageView.contentMode = .scaleAspectFill
        sceneryImageView.clipsToBounds = true
        sceneryImageView.image = currentProcessingSceneryImage
        overlayView.addSubview(sceneryImageView)

        let dimmingView = UIView()
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        overlayView.addSubview(dimmingView)

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.transform = CGAffineTransform(scaleX: 1.65, y: 1.65)
        spinner.startAnimating()

        let label = UILabel()
        label.text = LMText.camera.processingInspiring
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0

        overlayView.addSubview(spinner)
        overlayView.addSubview(label)

        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        sceneryImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        spinner.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-20)
        }

        label.snp.makeConstraints { make in
            make.top.equalTo(spinner.snp.bottom).offset(22)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(24)
        }

        overlayView.alpha = 0
        UIView.animate(withDuration: 0.2) {
            overlayView.alpha = 1
        }
    }
    
    func updateProcessingOverlaySceneryImage(_ image: UIImage) {
        currentProcessingSceneryImage = image
        guard let overlayView = previewCanvasView.viewWithTag(ViewTag.processingOverlay.rawValue),
              let sceneryImageView = overlayView.subviews.compactMap({ $0 as? UIImageView }).first else {
            return
        }
        sceneryImageView.image = image
    }
    
    func hideProcessingOverlay() {
        currentProcessingSceneryImage = nil
        if let overlayView = previewCanvasView.viewWithTag(ViewTag.processingOverlay.rawValue) {
            UIView.animate(withDuration: 0.2, animations: {
                overlayView.alpha = 0
            }) { _ in
                overlayView.removeFromSuperview()
            }
        }
    }
}
