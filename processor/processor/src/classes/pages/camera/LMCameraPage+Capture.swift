//
//  LMCameraPage+Capture.swift
//  processor
//
//  Photo capture functionality
//

import UIKit
import AVFoundation
import Toast_Swift

// MARK: - Photo Capture
extension LMCameraPage {
    
    func capturePhoto() {
        guard validateCameraState() else { return }
        guard let photoOutput = photoOutput else { return }
        
        let photoSettings = AVCapturePhotoSettings()
        
        // 配置闪光灯
        let currentFlashMode = cameraControlsView.getCurrentFlashMode()
        switch currentFlashMode {
        case .auto:
            photoSettings.flashMode = .auto
        case .on:
            photoSettings.flashMode = .on
        case .off:
            photoSettings.flashMode = .off
        }
        
        // 配置 Live Photos
        if cameraControlsView.getCurrentLivePhotoStatus() && photoOutput.isLivePhotoCaptureSupported {
            photoSettings.livePhotoMovieFileURL = createLivePhotoMovieURL()
        }
        
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
        
        LMLogger.log("📸 Photo capture initiated")
    }
    
    func validateCameraState() -> Bool {
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard cameraAuthStatus == .authorized else {
            LMLogger.log("❌ Camera permission not granted: \(cameraAuthStatus.rawValue)")
            showPermissionSettingsAlert()
            return false
        }
        
        guard AVCaptureDevice.default(for: .video) != nil else {
            LMLogger.log("❌ No camera device available")
            showAlert("Camera not available on this device", style: .error)
            return false
        }
        
        guard photoOutput != nil else {
            LMLogger.log("❌ Photo output not initialized")
            showAlert("Camera not ready. Please try again.", style: .error)
            return false
        }
        
        guard let captureSession = captureSession, captureSession.isRunning else {
            LMLogger.log("❌ Capture session not running")
            showAlert("Camera session not active. Please restart the camera.", style: .error)
            return false
        }
        
        return true
    }
    
    func createLivePhotoMovieURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "LivePhoto_\(Date().timeIntervalSince1970).mov"
        return documentsDirectory.appendingPathComponent(fileName)
    }
    
    func showCountdownTimer(duration: Int, completion: @escaping () -> Void) {
        let countdownLabel = UILabel()
        countdownLabel.font = UIFont.systemFont(ofSize: 60, weight: .bold)
        countdownLabel.textColor = UIColor.white
        countdownLabel.textAlignment = .center
        countdownLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        countdownLabel.layer.cornerRadius = 50
        countdownLabel.clipsToBounds = true
        
        view.addSubview(countdownLabel)
        countdownLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(100)
        }
        
        var remainingTime = duration
        countdownLabel.text = "\(remainingTime)"
        
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            remainingTime -= 1
            
            if remainingTime > 0 {
                countdownLabel.text = "\(remainingTime)"
                
                UIView.animate(withDuration: 0.3) {
                    countdownLabel.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                } completion: { _ in
                    UIView.animate(withDuration: 0.3) {
                        countdownLabel.transform = CGAffineTransform.identity
                    }
                }
            } else {
                timer.invalidate()
                countdownLabel.removeFromSuperview()
                completion()
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension LMCameraPage: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            LMLogger.log("❌ Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let capturedImage = UIImage(data: imageData) else {
            LMLogger.log("❌ Error processing photo data")
            return
        }
        // 根据当前选择的宽高比裁剪照片
        let croppedImage = cropImageToAspectRatio(capturedImage, ratio: currentAspectRatio)
        // 进入照片预览
        showPhotoPreview(image: croppedImage)
    }
    
    // MARK: - Live Photo Delegate Method
    func photoOutput(_ output: AVCapturePhotoOutput, 
                     didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, 
                     duration: CMTime, 
                     photoDisplayTime: CMTime, 
                     resolvedSettings: AVCaptureResolvedPhotoSettings, 
                     error: Error?) {
        if let error = error {
            LMLogger.log("❌ Error processing Live Photo movie: \(error)")
            return
        }
        
        LMLogger.log("✅ Live Photo movie processed successfully at: \(outputFileURL.path)")
        
        // 这里可以选择保存Live Photo视频到相册
        // 目前只记录日志，不做额外处理
        // 如果需要保存，可以使用 PHPhotoLibrary 来保存 Live Photo
    }
    
    /// 根据宽高比裁剪图片
    private func cropImageToAspectRatio(_ image: UIImage, ratio: LMAspectRatio) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        var targetWidth: CGFloat
        var targetHeight: CGFloat
        
        switch ratio {
        case .ratio3_4:
            // 3:4 比例
            if imageWidth / imageHeight > 3.0 / 4.0 {
                // 图片太宽，裁剪宽度
                targetHeight = imageHeight
                targetWidth = targetHeight * 3.0 / 4.0
            } else {
                // 图片太高，裁剪高度
                targetWidth = imageWidth
                targetHeight = targetWidth * 4.0 / 3.0
            }
            
        case .ratio1_1:
            // 1:1 比例（正方形）
            let size = min(imageWidth, imageHeight)
            targetWidth = size
            targetHeight = size
            
        case .ratio9_16:
            // 9:16 比例
            if imageWidth / imageHeight > 9.0 / 16.0 {
                // 图片太宽，裁剪宽度
                targetHeight = imageHeight
                targetWidth = targetHeight * 9.0 / 16.0
            } else {
                // 图片太高，裁剪高度
                targetWidth = imageWidth
                targetHeight = targetWidth * 16.0 / 9.0
            }
        }
        
        // 计算裁剪区域（居中裁剪）
        let x = (imageWidth - targetWidth) / 2.0
        let y = (imageHeight - targetHeight) / 2.0
        let cropRect = CGRect(x: x, y: y, width: targetWidth, height: targetHeight)
        
        // 执行裁剪
        if let croppedCGImage = cgImage.cropping(to: cropRect) {
            let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
            LMLogger.log("✂️ Image cropped to \(ratio.displayName) - Original: \(imageWidth)x\(imageHeight), Cropped: \(targetWidth)x\(targetHeight)")
            return croppedImage
        }
        
        LMLogger.log("⚠️ Failed to crop image, returning original")
        return image
    }
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            LMLogger.log("❌ Error saving photo: \(error)")
            showPhotoSaveErrorAlert()
        } else {
            LMLogger.log("✅ Photo saved successfully")
            showPhotoSavedConfirmation()
        }
    }
    
    func showPhotoSaveErrorAlert() {
        showToast("Unable to save photo to your photo library.")
    }
    
    func showPhotoSavedConfirmation() {
        let checkmarkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmarkView.tintColor = UIColor.systemGreen
        checkmarkView.backgroundColor = UIColor.white
        checkmarkView.layer.cornerRadius = 25
        checkmarkView.clipsToBounds = true
        
        view.addSubview(checkmarkView)
        checkmarkView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(50)
        }
        
        checkmarkView.alpha = 0
        checkmarkView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        UIView.animate(withDuration: 0.3, animations: {
            checkmarkView.alpha = 1
            checkmarkView.transform = CGAffineTransform.identity
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.0, animations: {
                checkmarkView.alpha = 0
                checkmarkView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            }) { _ in
                checkmarkView.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Photo Preview
    
    /// 显示照片预览页面
    func showPhotoPreview(image: UIImage) {
        LMLogger.log("📸 Showing photo preview")
        
        // 创建 GalleryItem
        let galleryItem = GalleryItem(
            image: image,
            title: nil,
            id: UUID().uuidString
        )
        
        // 创建预览页面
        let previewPage = LMGalleryDetailPage(item: galleryItem)
        previewPage.fromCamera = true
        // 如果在 showSuggestion 状态，重置相机状态
        if currentCameraState == .showingSuggestions || currentCameraState == .compositionSelected {
            LMLogger.log("🔄 Resetting camera state from \(currentCameraState) to normal")
            resetCameraToNormalState()
        }
        
        // 推送到预览页面
        navigationController?.pushViewController(previewPage, animated: true)
        
        LMLogger.log("✅ Navigated to photo preview page")
    }
    
    /// 重置相机到初始状态
    func resetCameraToNormalState() {
        LMLogger.log("🔄 Starting camera state reset...")
        
        // 清理 Show Suggestions 相关视图
        if let suggestionsContainer = view.viewWithTag(ViewTag.suggestionsContainer.rawValue) {
            suggestionsContainer.removeFromSuperview()
            LMLogger.log("  ✓ Removed suggestions container")
        }
        suggestionsCarouselView = nil
        suggestionsContainerView = nil
        
        // 停止轮询
        pollTimer?.invalidate()
        pollTimer = nil
        LMLogger.log("  ✓ Stopped polling timer")
        
        // 清理参考图
        if let referenceImageView = view.viewWithTag(ViewTag.referenceImageView.rawValue) {
            referenceImageView.removeFromSuperview()
            LMLogger.log("  ✓ Removed reference image")
        }
        
        // 清理 AR 引导相关视图
        if let arFrame = view.viewWithTag(ViewTag.arGuidanceFrame.rawValue) {
            arFrame.removeFromSuperview()
        }
        if let personFrame = view.viewWithTag(ViewTag.personDetectionFrame.rawValue) {
            personFrame.removeFromSuperview()
        }
        if let arLine = view.viewWithTag(ViewTag.arGuidanceLine.rawValue) {
            arLine.removeFromSuperview()
        }
        if let arHint = view.viewWithTag(ViewTag.arHintLabel.rawValue) {
            arHint.removeFromSuperview()
        }
        LMLogger.log("  ✓ Removed AR guidance views")
        
        // 重置状态变量
        currentCameraState = .normal
        currentTaskId = nil
        currentSuggestions = []
        currentSuggestion = nil
        isARGuidanceActive = false
        LMLogger.log("  ✓ Reset state variables")
        
        // 恢复 Inspire Me 按钮显示
        inspireMeButtonView.isHidden = false
        LMLogger.log("  ✓ Restored Inspire Me button visibility")
        
        // 恢复底部控制栏高度约束
        bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
        LMLogger.log("  ✓ Restored bottom controls height constraint to \(LMCameraConstants.bottomControlsHeight)")
        
        // 恢复快门按钮到正常尺寸（切换到 normal 布局模式）
        cameraBottomControlsView.setLayoutMode(.normal, animated: true)
        LMLogger.log("  ✓ Restored shutter button size (normal layout mode)")
        
        // 关闭 AR 引导按钮
        cameraBottomControlsView.setARGuidanceEnabled(false)
        LMLogger.log("  ✓ Disabled AR guidance button")
        
        // 应用布局变化（使用动画）
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            self.view.layoutIfNeeded()
        }
        
        LMLogger.log("✅ Camera state reset to normal completed")
    }
}
