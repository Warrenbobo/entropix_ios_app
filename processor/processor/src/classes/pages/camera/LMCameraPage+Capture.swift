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
    
    // MARK: - Live Photo Video URL Storage
    /// 临时存储 Live Photo 视频 URL
    private static var capturedLivePhotoVideoURL: URL?
    
    /// 临时存储捕获的照片，等待 Live Photo 视频处理完成
    private static var capturedPhotoImage: UIImage?
    
    /// 临时存储原始照片数据（包含元数据）
    private static var capturedPhotoImageData: Data?
    
    /// 标记是否正在等待 Live Photo 视频处理
    private static var isWaitingForLivePhotoVideo = false
    
    /// 拍照方法
    func capturePhoto() {
        guard let photoOutput = photoOutput else {
            LMLogger.log("❌ Photo output not available")
            return
        }
        
        let photoSettings = AVCapturePhotoSettings()
        let flashMode = cameraControlsView.getCurrentFlashMode()
        if photoOutput.supportedFlashModes.contains(flashMode.avFlashMode) && !isUsingFrontCamera {
            photoSettings.flashMode = flashMode.avFlashMode
        }
        
        // 检查并设置 Live Photo
        let isLivePhotoEnabled = photoOutput.isLivePhotoCaptureSupported && cameraControlsView.getCurrentLivePhotoStatus()
        if isLivePhotoEnabled {
            let livePhotoMovieFileName = UUID().uuidString
            let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
            photoSettings.livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
            
            // 设置等待标志
            Self.isWaitingForLivePhotoVideo = true
            LMLogger.log("📸 Live Photo enabled for this capture")
        } else {
            Self.isWaitingForLivePhotoVideo = false
            LMLogger.log("📸 Static photo capture")
        }
        
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
        
        LMLogger.log("📸 Photo capture initiated")
    }
    
    /// 显示倒计时定时器
    func showCountdownTimer(duration: Int, completion: @escaping () -> Void) {
        // 创建倒计时标签
        let countdownLabel = UILabel()
        countdownLabel.font = UIFont.systemFont(ofSize: 80, weight: .bold)
        countdownLabel.textColor = .white
        countdownLabel.textAlignment = .center
        countdownLabel.tag = 7777 // 用于后续移除
        
        view.addSubview(countdownLabel)
        countdownLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        var remainingTime = duration
        countdownLabel.text = "\(remainingTime)"
        
        // 添加缩放动画
        countdownLabel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            countdownLabel.transform = .identity
        }
        
        // 创建定时器
        var timer: Timer?
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            remainingTime -= 1
            
            if remainingTime > 0 {
                countdownLabel.text = "\(remainingTime)"
                
                // 每次更新时添加缩放动画
                countdownLabel.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                    countdownLabel.transform = .identity
                }
            } else {
                // 倒计时结束
                timer?.invalidate()
                
                // 移除倒计时标签
                UIView.animate(withDuration: 0.2, animations: {
                    countdownLabel.alpha = 0
                    countdownLabel.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                }) { _ in
                    countdownLabel.removeFromSuperview()
                }
                
                // 执行拍照
                completion()
            }
        }
    }
    

    /// 根据设备方向旋转图片
    /// - Parameters:
    ///   - image: 原始图片
    ///   - deviceOrientation: 设备方向
    ///   - isFrontCamera: 是否为前摄
    /// - Returns: 旋转后的图片
    private func rotateImage(_ image: UIImage, forDeviceOrientation deviceOrientation: UIDeviceOrientation, isFrontCamera: Bool = false) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        
        // 根据设备方向确定图片方向
        let imageOrientation: UIImage.Orientation
        if isFrontCamera {
            switch deviceOrientation {
            case .portrait:
                imageOrientation = .leftMirrored
            case .landscapeLeft:
                imageOrientation = .downMirrored
            case .landscapeRight:
                imageOrientation = .upMirrored
            case .portraitUpsideDown:
                imageOrientation = .rightMirrored
            default:
                imageOrientation = .leftMirrored
            }
            LMLogger.log("🔄 Front camera image rotated for device orientation: \(deviceOrientation.rawValue) -> \(imageOrientation.rawValue)")
        } else {
            switch deviceOrientation {
            case .portrait:
                imageOrientation = .right
            case .landscapeLeft:
                imageOrientation = .up
            case .landscapeRight:
                imageOrientation = .down
            case .portraitUpsideDown:
                imageOrientation = .left
            default:
                imageOrientation = .right
            }
            LMLogger.log("🔄 Back camera image rotated for device orientation: \(deviceOrientation.rawValue) -> \(imageOrientation.rawValue)")
        }
        let rotatedImage = UIImage(
            cgImage: cgImage,
            scale: image.scale,
            orientation: imageOrientation
        )
        return rotatedImage
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension LMCameraPage: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            LMLogger.log("❌ Photo capture error: \(error.localizedDescription)")
            AppTheme.Toast.showText("Failed to capture photo: \(error.localizedDescription)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              var capturedImage = UIImage(data: imageData) else {
            LMLogger.log("❌ Failed to convert photo data to image")
            AppTheme.Toast.showText("Failed to process captured photo")
            return
        }
        
        // 获取当前设备方向
        let deviceOrientation = LMDeviceOrientationManager.shared.currentOrientation
        LMLogger.log("📱 Current device orientation: \(deviceOrientation.rawValue)")
        LMLogger.log("📱 Camera position: \(isUsingFrontCamera ? "Front" : "Back")")
        
        // 根据设备方向和相机位置旋转图片
        // 前摄会自动进行镜像翻转 + 旋转
        capturedImage = rotateImage(capturedImage, forDeviceOrientation: deviceOrientation, isFrontCamera: isUsingFrontCamera)
        
        LMLogger.log("✅ Photo captured successfully, size: \(capturedImage.size)")
        
        // 检查是否正在等待 Live Photo 视频处理
        if Self.isWaitingForLivePhotoVideo {
            // Live Photo 拍摄：保存照片和原始数据，等待视频处理完成
            view.makeToastActivity(.center)
            LMLogger.log("⏳ Live Photo capture - waiting for video processing...")
            Self.capturedPhotoImage = capturedImage
            Self.capturedPhotoImageData = imageData  // 保存原始数据（包含元数据）
        } else {
            // 普通照片拍摄：直接跳转预览
            LMLogger.log("📷 Static photo capture - navigating to preview")
            let photoData = CapturedPhotoData(image: capturedImage)
            
            DispatchQueue.main.async { [weak self] in
                self?.navigateToPhotoPreview(photoData: photoData)
            }
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // 播放快门音效
        AudioServicesPlaySystemSound(1108)
    }
    
    // MARK: - Live Photo Delegate Methods
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        LMLogger.log("📹 Live Photo movie recording finished")
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            LMLogger.log("❌ Live Photo processing error: \(error.localizedDescription)")
            view.hideToastActivity()
            Self.capturedLivePhotoVideoURL = nil
            
            // 如果正在等待视频，使用静态照片继续
            if Self.isWaitingForLivePhotoVideo, let capturedImage = Self.capturedPhotoImage {
                LMLogger.log("⚠️ Live Photo video failed, using static image")
                let photoData = CapturedPhotoData(image: capturedImage)
                
                DispatchQueue.main.async { [weak self] in
                    self?.navigateToPhotoPreview(photoData: photoData)
                }
                
                // 清理状态
                Self.capturedPhotoImage = nil
                Self.isWaitingForLivePhotoVideo = false
            }
        } else {
            LMLogger.log("✅ Live Photo movie processed successfully at: \(outputFileURL.path)")
            Self.capturedLivePhotoVideoURL = outputFileURL
            view.hideToastActivity()
            // 如果正在等待视频，现在可以创建完整的 Live Photo 数据并跳转
            if Self.isWaitingForLivePhotoVideo, let capturedImage = Self.capturedPhotoImage {
                LMLogger.log("🎬 Creating Live Photo data with video and original image data")
                
                let photoData = CapturedPhotoData(
                    image: capturedImage,
                    imageData: Self.capturedPhotoImageData,  // 传递原始数据
                    livePhotoVideoURL: outputFileURL,
                    isLivePhoto: true
                )
                
                DispatchQueue.main.async { [weak self] in
                    self?.navigateToPhotoPreview(photoData: photoData)
                }
                
                // 清理状态
                Self.capturedPhotoImage = nil
                Self.capturedPhotoImageData = nil
                Self.isWaitingForLivePhotoVideo = false
            }
        }
    }
    
    /// 跳转到照片预览页面
    private func navigateToPhotoPreview(photoData: CapturedPhotoData) {
        let previewPage = LMPhotoPreviewPage(photoData: photoData)
        navigationController?.pushViewController(previewPage, animated: true)
    }
}

// MARK: - Flash Mode Extension
extension LMFlashMode {
    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off:
            return .off
        case .auto:
            return .auto
        case .on:
            return .on
        }
    }
}
