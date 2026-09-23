//
//  LMPhotoPreviewPage.swift
//  processor
//
//  Created by muz on 2025/11/30.
//  照片预览页面 - 拍照后的预览和操作界面
//

import UIKit
import SnapKit
import Photos
import PhotosUI

class LMPhotoPreviewPage: UIViewController, UIGestureRecognizerDelegate {
    
    // MARK: - Properties
    private let photoData: CapturedPhotoData
    
    // MARK: - UI Components
    private let photoImageView = UIImageView()
    private var livePhotoView: PHLivePhotoView?
    private let livePhotoBadge = UIImageView()
    private let backButtonContainer = UIView()
    private let backIconImageView = UIImageView()
    private let backLabel = UILabel()
    private let downloadButton = UIButton(type: .custom)
    private let successIndicator = UIView()
    
    // MARK: - Initialization
    init(photoData: CapturedPhotoData) {
        self.photoData = photoData
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewHierarchy()
        setupLayout()
        setupActions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    // MARK: - View Hierarchy Configuration
    private func configureViewHierarchy() {
        view.backgroundColor = .black
        
        LMLogger.log("📸 Photo Preview - isLivePhoto: \(photoData.isLivePhoto)")
        LMLogger.log("📸 Photo Preview - hasVideoURL: \(photoData.livePhotoVideoURL != nil)")
        
        // Photo Display - Live Photo or Static Image
        if photoData.isLivePhoto {
            LMLogger.log("🎬 Setting up Live Photo view")
            setupLivePhotoView()
        } else {
            LMLogger.log("📷 Setting up static image view")
            photoImageView.image = photoData.image
            photoImageView.contentMode = .scaleAspectFit
            view.addSubview(photoImageView)
        }
        
        // Back Button Container
        backButtonContainer.backgroundColor = UIColor(white: 0.25, alpha: 0.85)
        backButtonContainer.layer.cornerRadius = 22
        backButtonContainer.layer.borderWidth = 1
        backButtonContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        view.addSubview(backButtonContainer)
        
        // 配置左箭头图标
        let backImage = UIImage.lmSymbol("chevron.left", pointSize: 18)
        backIconImageView.image = backImage
        backIconImageView.tintColor = .white
        backIconImageView.contentMode = .scaleAspectFit
        backButtonContainer.addSubview(backIconImageView)
        
        // 配置 Back 文字
        backLabel.text = LMText.common.back
        backLabel.textColor = .white
        backLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        backButtonContainer.addSubview(backLabel)
        
        // 添加点击手势
        let backTapGesture = UITapGestureRecognizer(target: self, action: #selector(backButtonTapped))
        backButtonContainer.addGestureRecognizer(backTapGesture)
        backButtonContainer.isUserInteractionEnabled = true
        
        // Download Button (保存到相册)
        downloadButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        downloadButton.layer.cornerRadius = 20
        downloadButton.layer.borderWidth = 1
        downloadButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        let downloadConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let downloadImage = UIImage(systemName: "arrow.down.circle", withConfiguration: downloadConfig)
        downloadButton.setImage(downloadImage, for: .normal)
        downloadButton.tintColor = .white
        
        view.addSubview(downloadButton)
        
        // Success Indicator
        successIndicator.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        successIndicator.layer.cornerRadius = 20
        successIndicator.isHidden = true
        
        let checkmarkImageView = UIImageView()
        let checkConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: checkConfig)
        checkmarkImageView.tintColor = UIColor.hexColor("#10b981")
        
        let messageLabel = UILabel()
        messageLabel.text = LMText.settings.downloaded
        messageLabel.textColor = .white
        messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        
        successIndicator.addSubview(checkmarkImageView)
        successIndicator.addSubview(messageLabel)
        view.addSubview(successIndicator)
        
        checkmarkImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.leading.equalTo(checkmarkImageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
    }
    
    // MARK: - Live Photo Setup
    private func setupLivePhotoView() {
        let livePhotoView = PHLivePhotoView()
        livePhotoView.contentMode = .scaleAspectFit
        livePhotoView.backgroundColor = .black
        view.addSubview(livePhotoView)
        self.livePhotoView = livePhotoView
        
        livePhotoView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let badgeConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        livePhotoBadge.image = UIImage(systemName: "livephoto", withConfiguration: badgeConfig)
        livePhotoBadge.tintColor = .white
        livePhotoBadge.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        livePhotoBadge.layer.cornerRadius = 6
        livePhotoBadge.contentMode = .center
        livePhotoBadge.clipsToBounds = true
        view.addSubview(livePhotoBadge)
        
        livePhotoBadge.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-6)
            make.trailing.equalTo(view).offset(-12)
            make.width.equalTo(40)
            make.height.equalTo(28)
        }
        
        // 添加长按手势来播放 Live Photo
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLivePhotoLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.3
        longPressGesture.delegate = self
        livePhotoView.addGestureRecognizer(longPressGesture)
        livePhotoView.isUserInteractionEnabled = true
        
        LMLogger.log("✅ Live Photo view setup with long press gesture")
        
        // 生成 Live Photo
        generateLivePhoto()
    }
    
    @objc private func handleLivePhotoLongPress(_ gesture: UILongPressGestureRecognizer) {
        LMLogger.log("👆 Long press gesture detected - state: \(gesture.state.rawValue)")
        
        guard let livePhotoView = livePhotoView else {
            LMLogger.log("❌ livePhotoView is nil")
            return
        }
        
        switch gesture.state {
        case .began:
            LMLogger.log("🎬 Starting Live Photo playback")
            livePhotoView.startPlayback(with: .full)
            
        case .ended, .cancelled, .failed:
            LMLogger.log("⏸️ Stopping Live Photo playback")
            livePhotoView.stopPlayback()
            
        default:
            break
        }
    }
    
    private func generateLivePhoto() {
        guard let videoURL = photoData.livePhotoVideoURL else {
            LMLogger.log("❌ No Live Photo video URL")
            fallbackToStaticImage()
            return
        }
        
        // 检查视频文件是否存在
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            LMLogger.log("❌ Live Photo video file not found at: \(videoURL.path)")
            fallbackToStaticImage()
            return
        }
        
        LMLogger.log("📹 Video file exists at: \(videoURL.path)")
        
        // 保存图片到临时文件（使用原始数据以保留元数据）
        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        // 优先使用原始照片数据（包含 Live Photo 元数据）
        let imageData: Data
        if let originalData = photoData.imageData {
            LMLogger.log("✅ Using original image data with metadata")
            imageData = originalData
        } else {
            // 降级：使用 JPEG 编码（可能丢失元数据）
            LMLogger.log("⚠️ Using JPEG encoded data (metadata may be lost)")
            guard let jpegData = photoData.image.jpegData(compressionQuality: 1.0) else {
                LMLogger.log("❌ Failed to convert image to JPEG")
                fallbackToStaticImage()
                return
            }
            imageData = jpegData
        }
        
        do {
            try imageData.write(to: imageURL)
            LMLogger.log("✅ Temporary image saved at: \(imageURL.path)")
        } catch {
            LMLogger.log("❌ Failed to write image: \(error)")
            fallbackToStaticImage()
            return
        }
        
        // 生成 PHLivePhoto
        LMLogger.log("🎬 Generating Live Photo from resources...")
        LMLogger.log("📸 Image URL: \(imageURL.path)")
        LMLogger.log("📹 Video URL: \(videoURL.path)")
        
        PHLivePhoto.request(
            withResourceFileURLs: [imageURL, videoURL],
            placeholderImage: photoData.image,
            targetSize: .zero,
            contentMode: .aspectFit
        ) { [weak self] livePhoto, info in
            guard let self = self else {
                // 清理临时文件
                try? FileManager.default.removeItem(at: imageURL)
                return
            }
            
            // 检查是否为降级版本
            let isDegraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false
            let isCancelled = (info[PHLivePhotoInfoCancelledKey] as? Bool) ?? false
            
            LMLogger.log("📞 Live Photo callback - isDegraded: \(isDegraded), isCancelled: \(isCancelled)")
            
            if isCancelled {
                LMLogger.log("⚠️ Live Photo generation was cancelled")
                DispatchQueue.main.async {
                    self.fallbackToStaticImage()
                }
                // 清理临时文件
                try? FileManager.default.removeItem(at: imageURL)
                return
            }
            
            if let livePhoto = livePhoto {
                DispatchQueue.main.async {
                    self.livePhotoView?.livePhoto = livePhoto
                    if isDegraded {
                        LMLogger.log("⚠️ Live Photo loaded (degraded version)")
                        // 降级版本不删除临时文件，等待最终版本
                    } else {
                        LMLogger.log("✅ Live Photo loaded successfully (final version)")
                        LMLogger.log("📊 Live Photo size: \(livePhoto.size)")
                        // 只在收到最终版本后清理临时文件
                        LMLogger.log("🗑️ Cleaning up temporary image file")
                        try? FileManager.default.removeItem(at: imageURL)
                    }
                }
            } else {
                // 只有在非降级版本失败时才降级到静态图片
                if !isDegraded {
                    LMLogger.log("❌ Failed to create Live Photo (final version)")
                    LMLogger.log("📋 Info: \(info)")
                    
                    // 检查错误信息
                    if let error = info[PHLivePhotoInfoErrorKey] as? Error {
                        LMLogger.log("❌ Error: \(error.localizedDescription)")
                    }
                    
                    // 降级到静态图片
                    DispatchQueue.main.async {
                        self.fallbackToStaticImage()
                    }
                    // 清理临时文件
                    try? FileManager.default.removeItem(at: imageURL)
                }
            }
        }
    }
    
    private func fallbackToStaticImage() {
        LMLogger.log("⚠️ Falling back to static image display")
        livePhotoView?.removeFromSuperview()
        livePhotoView = nil
        livePhotoBadge.isHidden = true
        
        photoImageView.image = photoData.image
        photoImageView.contentMode = .scaleAspectFit
        view.insertSubview(photoImageView, at: 0)
        
        photoImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupLayout() {
        if !photoData.isLivePhoto {
            photoImageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        backButtonContainer.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.equalToSuperview().offset(20)
            make.height.equalTo(44)
        }
        
        backIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(20)
        }
        
        backLabel.snp.makeConstraints { make in
            make.leading.equalTo(backIconImageView.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
        }
        
        downloadButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.trailing.equalToSuperview().offset(-20)
            make.size.equalTo(40)
        }
        
        successIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalTo(56)
        }
    }
    
    private func setupActions() {
        downloadButton.addTarget(self, action: #selector(downloadButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func downloadButtonTapped() {
        // 检查登录状态
        guard requireLogin(action: "download photo to album") else {
            return
        }
        
        // 检查相册权限
        checkPhotoLibraryPermission { [weak self] granted in
            guard let self = self else { return }
            
            if granted {
                if self.photoData.isLivePhoto {
                    self.saveLivePhotoToLibrary()
                } else {
                    self.saveToPhotoLibrary()
                }
            } else {
                self.showPhotoLibraryPermissionAlert()
            }
        }
    }
    
    // MARK: - Photo Library Operations
    private func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            completion(true)
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    completion(newStatus == .authorized || newStatus == .limited)
                }
            }
            
        case .denied, .restricted:
            completion(false)
            
        @unknown default:
            completion(false)
        }
    }
    
    private func saveToPhotoLibrary() {
        let watermarkedImage = LMImageAssetProcessor.watermarkedImage(from: photoData.image)
        UIImageWriteToSavedPhotosAlbum(
            watermarkedImage,
            self,
            #selector(image(_:didFinishSavingWithError:contextInfo:)),
            nil
        )
    }
    
    private func saveLivePhotoToLibrary() {
        guard let videoURL = photoData.livePhotoVideoURL else {
            LMLogger.log("❌ No Live Photo video URL for saving")
            showError(message: LMText.camera.failedToSaveLivePhoto)
            return
        }
        
        // 检查视频文件是否存在
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            LMLogger.log("❌ Live Photo video file not found at: \(videoURL.path)")
            showError(message: LMText.camera.livePhotoVideoNotFound)
            return
        }
        
        LMLogger.log("📹 Saving Live Photo to library...")
        LMLogger.log("📹 Image size: \(photoData.image.size)")
        LMLogger.log("📹 Video path: \(videoURL.path)")

        let photoResourceData: Data?
        if let originalImageData = photoData.imageData,
           let watermarkedImageData = LMImageAssetProcessor.watermarkedImageDataPreservingMetadata(
            from: photoData.image,
            originalImageData: originalImageData
           ) {
            photoResourceData = watermarkedImageData
            LMLogger.log("✅ Live Photo cover watermark applied with preserved metadata")
        } else if let originalImageData = photoData.imageData {
            photoResourceData = originalImageData
            LMLogger.log("⚠️ Failed to watermark Live Photo cover, falling back to original still image data")
        } else {
            photoResourceData = nil
            LMLogger.log("⚠️ Missing original Live Photo still image data, falling back to original flow")
        }
        
        // 使用 PHAssetCreationRequest 保存 Live Photo
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            
            // 添加图片资源（优先使用原始数据以保留元数据）
            if let photoResourceData {
                creationRequest.addResource(with: .photo, data: photoResourceData, options: nil)
                LMLogger.log("✅ Using Live Photo still image data for save")
            } else if let imageData = self.photoData.image.jpegData(compressionQuality: 1.0) {
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
                LMLogger.log("⚠️ Using JPEG encoded data (metadata may be lost)")
            }
            
            // 添加配对视频资源
            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.shouldMoveFile = false
            creationRequest.addResource(with: .pairedVideo, fileURL: videoURL, options: videoOptions)
            
            LMLogger.log("📹 Adding paired video resource")
            
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    LMLogger.log("✅ Live Photo saved to library successfully")
                    self?.showSuccessIndicator()
                } else if let error = error {
                    LMLogger.log("❌ Failed to save Live Photo: \(error.localizedDescription)")
                    self?.showError(message: "\(LMText.camera.failedToSaveLivePhoto): \(error.localizedDescription)")
                } else {
                    LMLogger.log("❌ Failed to save Live Photo: Unknown error")
                    self?.showError(message: LMText.camera.failedToSaveLivePhoto)
                }
            }
        }
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showError(message: "\(LMText.camera.failedToSavePhoto): \(error.localizedDescription)")
        } else {
            showSuccessIndicator()
        }
    }
    
    private func showPhotoLibraryPermissionAlert() {
        LMAlertDialog.showAlert(title: LMText.camera.photoLibraryAccessRequired,
                                message: LMText.camera.photoLibraryAccessRequiredMessage,
                                cancelText: LMText.common.cancel,
                                confirmText: LMText.common.openSettings,
                                onConfirm: {
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
    }
    
    // MARK: - UI Feedback
    private func showSuccessIndicator() {
        successIndicator.isHidden = false
        successIndicator.alpha = 0
        successIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.successIndicator.alpha = 1
            self.successIndicator.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, options: .curveEaseIn) {
                self.successIndicator.alpha = 0
                self.successIndicator.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            } completion: { _ in
                self.successIndicator.isHidden = true
            }
        }
    }
    
    private func showError(message: String) {
        LMAlertDialog.showGeneralAlert(message,
                                       title: LMText.common.error,
                                       onConfirm: {})
    }
}

// MARK: - UIGestureRecognizerDelegate
extension LMPhotoPreviewPage {
    
    /// 允许手势识别器与其他视图的触摸事件共存
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 如果触摸点在按钮上，不响应长按手势
        if touch.view is UIButton {
            LMLogger.log("👆 Touch on button, ignoring long press")
            return false
        }
        
        // 如果触摸点在按钮容器上，不响应长按手势
        if touch.view == backButtonContainer {
            LMLogger.log("👆 Touch on back button container, ignoring long press")
            return false
        }
        
        LMLogger.log("👆 Touch received for long press gesture")
        return true
    }
    
    /// 允许多个手势识别器同时工作
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
