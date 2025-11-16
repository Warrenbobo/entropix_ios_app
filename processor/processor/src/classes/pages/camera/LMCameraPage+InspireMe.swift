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
        
        guard validateCameraState() else {
            return
        }
        
        showProcessingOverlay()
        isInspireMeCapture = true
        
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
        
//        if detectImageBlur(image) {
//            hideProcessingOverlay()
//            showAlert("Image is too blurry. Please try again with better lighting or steadier hands.", style: .error)
//            return
//        }
        
//        LMLogger.log("✅ Image is sharp, proceeding with analysis...")
        
        let sceneFeature = analyzeSceneWithFastVLM(image)
        
        // 📝 记录数据到 LMTestDataManager
        LMTestDataManager.shared.recordInspireMeData(sceneFeature: sceneFeature, image: image)
        
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
        
        // 创建半透明遮罩，但不阻止用户交互
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayView.tag = ViewTag.processingOverlay.rawValue
        overlayView.isUserInteractionEnabled = false // 遮罩本身不拦截交互
        
        // 创建加载指示器容器
        let indicatorContainer = UIView()
        indicatorContainer.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        indicatorContainer.layer.cornerRadius = 16
        indicatorContainer.clipsToBounds = true
        
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        
        let label = UILabel()
        label.text = LMText.camera.analyzingScene
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        
        indicatorContainer.addSubview(spinner)
        indicatorContainer.addSubview(label)
        overlayView.addSubview(indicatorContainer)
        view.addSubview(overlayView)
        
        // 布局
        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        indicatorContainer.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(200)
            make.height.equalTo(120)
        }
        
        spinner.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(24)
        }
        
        label.snp.makeConstraints { make in
            make.top.equalTo(spinner.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }
        
        // 添加淡入动画
        overlayView.alpha = 0
        UIView.animate(withDuration: 0.2) {
            overlayView.alpha = 1
        }
        
        // 不禁用整个视图的交互，用户仍然可以操作相机
        // view.isUserInteractionEnabled = false // ❌ 移除这行
    }
    
    func hideProcessingOverlay() {
        if let overlayView = view.viewWithTag(ViewTag.processingOverlay.rawValue) {
            // 添加淡出动画
            UIView.animate(withDuration: 0.2, animations: {
                overlayView.alpha = 0
            }) { _ in
                overlayView.removeFromSuperview()
            }
        }
        // view.isUserInteractionEnabled = true // ❌ 移除这行
    }
}
