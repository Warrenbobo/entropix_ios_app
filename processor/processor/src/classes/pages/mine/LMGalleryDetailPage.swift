//
//  LMGalleryDetailPage.swift
//  processor
//
//  Created by muz on 2025/11/9.
//

import UIKit
import SnapKit
import Photos
import PhotosUI

class LMGalleryDetailPage: UIViewController {
    
    public var fromCamera: Bool = false
    
    // MARK: - Properties
    private let galleryItem: GalleryItem
    
    // MARK: - UI Components
    private let photoImageView = UIImageView()
    private var livePhotoView: PHLivePhotoView?
    private let livePhotoBadge = UIImageView()
    private let backButtonContainer = UIView()
    private let backIconImageView = UIImageView()
    private let backLabel = UILabel()
    private let downloadButton = UIButton(type: .custom)
    private let deleteButton = UIButton(type: .custom)
    private let successIndicator = UIView()
    
    // MARK: - Initialization
    init(item: GalleryItem) {
        self.galleryItem = item
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
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
        
        // Photo Display - Live Photo or Static Image
        if galleryItem.isLivePhoto {
            setupLivePhotoView()
        } else {
            photoImageView.image = galleryItem.image
            photoImageView.contentMode = .scaleAspectFit
            view.addSubview(photoImageView)
        }
        
        backButtonContainer.backgroundColor = UIColor(white: 0.25, alpha: 0.85)
        backButtonContainer.layer.cornerRadius = 22
        backButtonContainer.layer.borderWidth = 1
        backButtonContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        view.addSubview(backButtonContainer)
        
        // 配置左箭头图标
        let backImage = UIImage(named: "left_arrow_white")
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
        
        // Download Button
        downloadButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        downloadButton.layer.cornerRadius = 20
        downloadButton.layer.borderWidth = 1
        downloadButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        let downloadConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let downloadImage = UIImage(systemName: "arrow.down.circle", withConfiguration: downloadConfig)
        downloadButton.setImage(downloadImage, for: .normal)
        downloadButton.tintColor = .white
        
        view.addSubview(downloadButton)
        
        // Delete Button
        deleteButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        deleteButton.layer.cornerRadius = 20
        deleteButton.layer.borderWidth = 1
        deleteButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        let deleteConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let deleteImage = UIImage(systemName: "trash", withConfiguration: deleteConfig)
        deleteButton.setImage(deleteImage, for: .normal)
        deleteButton.tintColor = .white
        
        view.addSubview(deleteButton)
        
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
        livePhotoView.addGestureRecognizer(longPressGesture)
        livePhotoView.isUserInteractionEnabled = true
        
        LMLogger.log("✅ Live Photo view setup with long press gesture (Gallery)")
        
        // 加载 Live Photo
        loadLivePhoto()
    }
    
    @objc private func handleLivePhotoLongPress(_ gesture: UILongPressGestureRecognizer) {
        LMLogger.log("👆 Long press gesture detected (Gallery) - state: \(gesture.state.rawValue)")
        
        guard let livePhotoView = livePhotoView else {
            LMLogger.log("❌ livePhotoView is nil (Gallery)")
            return
        }
        
        switch gesture.state {
        case .began:
            LMLogger.log("🎬 Starting Live Photo playback (Gallery)")
            livePhotoView.startPlayback(with: .full)
            
        case .ended, .cancelled, .failed:
            LMLogger.log("⏸️ Stopping Live Photo playback (Gallery)")
            livePhotoView.stopPlayback()
            
        default:
            break
        }
    }
    
    private func loadLivePhoto() {
        guard let videoPath = galleryItem.livePhotoVideoPath,
              let imagePath = galleryItem.imagePath else {
            LMLogger.log("❌ Missing Live Photo data (videoPath or imagePath)")
            fallbackToStaticImage()
            return
        }
        
        let videoURL = URL(fileURLWithPath: videoPath)
        let imageURL = URL(fileURLWithPath: imagePath)
        
        // 检查视频文件是否存在
        guard FileManager.default.fileExists(atPath: videoPath) else {
            LMLogger.log("❌ Live Photo video file not found at: \(videoPath)")
            fallbackToStaticImage()
            return
        }
        
        // 检查图片文件是否存在
        guard FileManager.default.fileExists(atPath: imagePath) else {
            LMLogger.log("❌ Live Photo image file not found at: \(imagePath)")
            fallbackToStaticImage()
            return
        }
        
        // 生成 PHLivePhoto（直接使用原始文件，保留元数据）
        LMLogger.log("🎬 Loading Live Photo from Gallery...")
        LMLogger.log("📸 Image path: \(imagePath)")
        LMLogger.log("📹 Video path: \(videoPath)")
        
        PHLivePhoto.request(
            withResourceFileURLs: [imageURL, videoURL],
            placeholderImage: galleryItem.image,
            targetSize: .zero,
            contentMode: .aspectFit
        ) { [weak self] livePhoto, info in
            guard let self = self else { return }
            
            // 检查是否为降级版本
            let isDegraded = (info[PHLivePhotoInfoIsDegradedKey] as? Bool) ?? false
            let isCancelled = (info[PHLivePhotoInfoCancelledKey] as? Bool) ?? false
            
            LMLogger.log("📞 Live Photo callback (Gallery) - isDegraded: \(isDegraded), isCancelled: \(isCancelled)")
            
            if isCancelled {
                LMLogger.log("⚠️ Live Photo generation was cancelled in Gallery")
                DispatchQueue.main.async {
                    self.fallbackToStaticImage()
                }
                return
            }
            
            if let livePhoto = livePhoto {
                DispatchQueue.main.async {
                    self.livePhotoView?.livePhoto = livePhoto
                    if isDegraded {
                        LMLogger.log("⚠️ Live Photo loaded in Gallery (degraded version)")
                    } else {
                        LMLogger.log("✅ Live Photo loaded in Gallery (final version)")
                        LMLogger.log("📊 Live Photo size: \(livePhoto.size)")
                    }
                }
            } else {
                // 只有在非降级版本失败时才降级到静态图片
                if !isDegraded {
                    LMLogger.log("❌ Failed to create Live Photo in Gallery (final version)")
                    LMLogger.log("📋 Info: \(info)")
                    
                    // 检查错误信息
                    if let error = info[PHLivePhotoInfoErrorKey] as? Error {
                        LMLogger.log("❌ Error: \(error.localizedDescription)")
                    }
                    
                    DispatchQueue.main.async {
                        self.fallbackToStaticImage()
                    }
                }
            }
        }
    }
    
    private func fallbackToStaticImage() {
        LMLogger.log("⚠️ Falling back to static image display in Gallery")
        livePhotoView?.removeFromSuperview()
        livePhotoView = nil
        livePhotoBadge.isHidden = true
        
        photoImageView.image = galleryItem.image
        photoImageView.contentMode = .scaleAspectFit
        view.insertSubview(photoImageView, at: 0)
        
        photoImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupLayout() {
        if !galleryItem.isLivePhoto {
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
        
        deleteButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.trailing.equalToSuperview().offset(-20)
            make.size.equalTo(40)
        }
        
        downloadButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.trailing.equalTo(deleteButton.snp.leading).offset(-12)
            make.size.equalTo(40)
        }
        
        successIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalTo(56)
        }
    }
    
    private func setupActions() {
        downloadButton.addTarget(self, action: #selector(downloadButtonTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        if fromCamera {
            navigationController?.popToRootViewController(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    @objc private func downloadButtonTapped() {
        guard let image = galleryItem.image else { return }
        
        // Save to photo library
        if galleryItem.isLivePhoto {
            saveLivePhotoToLibrary()
        } else {
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }
    
    private func saveLivePhotoToLibrary() {
        guard let videoPath = galleryItem.livePhotoVideoPath,
              let imagePath = galleryItem.imagePath else {
            LMLogger.log("❌ Missing Live Photo data for saving")
            showError(message: LMText.camera.livePhotoDataNotFound)
            return
        }
        
        let videoURL = URL(fileURLWithPath: videoPath)
        let imageURL = URL(fileURLWithPath: imagePath)
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: videoPath) else {
            LMLogger.log("❌ Live Photo video file not found at: \(videoPath)")
            showError(message: LMText.camera.livePhotoVideoNotFound)
            return
        }
        
        guard FileManager.default.fileExists(atPath: imagePath) else {
            LMLogger.log("❌ Live Photo image file not found at: \(imagePath)")
            showError(message: LMText.camera.livePhotoImageNotFound)
            return
        }
        
        LMLogger.log("📹 Saving Live Photo to library from Gallery...")
        LMLogger.log("📸 Image path: \(imagePath)")
        LMLogger.log("📹 Video path: \(videoPath)")
        
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            
            // 使用原始图片文件（包含 Live Photo 元数据）
            let imageOptions = PHAssetResourceCreationOptions()
            imageOptions.shouldMoveFile = false
            creationRequest.addResource(with: .photo, fileURL: imageURL, options: imageOptions)
            
            // 添加配对视频资源
            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.shouldMoveFile = false
            creationRequest.addResource(with: .pairedVideo, fileURL: videoURL, options: videoOptions)
            
            LMLogger.log("✅ Live Photo resources added to creation request")
            
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    LMLogger.log("✅ Live Photo saved to library successfully")
                    self?.showSuccessIndicator()
                } else if let error = error {
                    let nsError = error as NSError
                    LMLogger.log("❌ Failed to save Live Photo: \(error.localizedDescription)")
                    LMLogger.log("❌ Error code: \(nsError.code), domain: \(nsError.domain)")
                    LMLogger.log("❌ Error info: \(nsError.userInfo)")
                    self?.showError(message: "\(LMText.camera.failedToSaveLivePhoto): \(error.localizedDescription)")
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
    
    @objc private func deleteButtonTapped() {
        LMAlertDialog.showGeneralAlert(LMText.profile.actionCannotBeUndone,
                                       title: LMText.profile.deletePhotoConfirm) { [weak self] in
            self?.performDelete()
        }
    }
    
    private func performDelete() {
        LMLogger.log("🗑️ Deleting gallery item: \(galleryItem.id)")
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: nil, message: LMText.settings.deleting, preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        loadingIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor).isActive = true
        loadingIndicator.bottomAnchor.constraint(equalTo: loadingAlert.view.bottomAnchor, constant: -20).isActive = true
        present(loadingAlert, animated: true)
        
        // Delete from CoreData
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let success = LMPhotoStorageManager.shared.deletePhoto(byId: self.galleryItem.id)
            
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    if success {
                        LMLogger.log("✅ Gallery item deleted successfully from storage")
                        self.navigationController?.popViewController(animated: true)
                    } else {
                        LMLogger.log("❌ Failed to delete gallery item from storage")
                        self.showError(message: LMText.camera.failedToSavePhoto)
                    }
                }
            }
        }
    }
    
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
