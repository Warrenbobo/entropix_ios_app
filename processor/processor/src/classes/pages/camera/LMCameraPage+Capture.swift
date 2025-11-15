//
//  LMCameraPage+Capture.swift
//  processor
//
//  Photo capture functionality
//

import UIKit
import AVFoundation

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
        cameraBottomControlsView.showCaptureAnimation()
        
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
            showError("Camera not available on this device")
            return false
        }
        
        guard photoOutput != nil else {
            LMLogger.log("❌ Photo output not initialized")
            showError("Camera not ready. Please try again.")
            return false
        }
        
        guard let captureSession = captureSession, captureSession.isRunning else {
            LMLogger.log("❌ Capture session not running")
            showError("Camera session not active. Please restart the camera.")
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
            if isInspireMeCapture {
                hideProcessingOverlay()
                showError("Capture failed: \(error.localizedDescription)")
                isInspireMeCapture = false
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let capturedImage = UIImage(data: imageData) else {
            LMLogger.log("❌ Error processing photo data")
            if isInspireMeCapture {
                hideProcessingOverlay()
                showError("Failed to process image")
                isInspireMeCapture = false
            }
            return
        }
        
        // 根据当前选择的宽高比裁剪照片
        let croppedImage = cropImageToAspectRatio(capturedImage, ratio: currentAspectRatio)
        
        if isInspireMeCapture {
            isInspireMeCapture = false
            processInspireMeImage(croppedImage)
        } else {
            UIImageWriteToSavedPhotosAlbum(croppedImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
            LMLogger.log("✅ Photo captured successfully")
        }
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
        let alertController = UIAlertController(
            title: "Save Error",
            message: "Unable to save photo to your photo library.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
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
}
