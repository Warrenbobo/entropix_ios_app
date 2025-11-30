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
        backLabel.text = "Back"
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
        
        // 加载 Live Photo
        loadLivePhoto()
    }
    
    private func loadLivePhoto() {
        guard let videoPath = galleryItem.livePhotoVideoPath,
              let image = galleryItem.image else {
            LMLogger.log("❌ Missing Live Photo data")
            fallbackToStaticImage()
            return
        }
        
        let videoURL = URL(fileURLWithPath: videoPath)
        
        // 检查视频文件是否存在
        guard FileManager.default.fileExists(atPath: videoPath) else {
            LMLogger.log("❌ Live Photo video file not found at: \(videoPath)")
            fallbackToStaticImage()
            return
        }
        
        // 保存图片到临时文件
        let imageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            LMLogger.log("❌ Failed to convert image to JPEG")
            fallbackToStaticImage()
            return
        }
        
        do {
            try imageData.write(to: imageURL)
        } catch {
            LMLogger.log("❌ Failed to write image: \(error)")
            fallbackToStaticImage()
            return
        }
        
        // 生成 PHLivePhoto
        LMLogger.log("🎬 Loading Live Photo from Gallery...")
        PHLivePhoto.request(
            withResourceFileURLs: [imageURL, videoURL],
            placeholderImage: image,
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
            
            LMLogger.log("📞 Live Photo callback (Gallery) - isDegraded: \(isDegraded), isCancelled: \(isCancelled)")
            
            if isCancelled {
                LMLogger.log("⚠️ Live Photo generation was cancelled in Gallery")
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
                        LMLogger.log("⚠️ Live Photo loaded in Gallery (degraded version)")
                        // 降级版本不删除临时文件，等待最终版本
                    } else {
                        LMLogger.log("✅ Live Photo loaded in Gallery (final version)")
                        LMLogger.log("📊 Live Photo size: \(livePhoto.size)")
                        // 只在收到最终版本后清理临时文件
                        LMLogger.log("🗑️ Cleaning up temporary image file in Gallery")
                        try? FileManager.default.removeItem(at: imageURL)
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
                    // 清理临时文件
                    try? FileManager.default.removeItem(at: imageURL)
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
        guard let livePhoto = livePhotoView?.livePhoto else {
            LMLogger.log("❌ Live Photo not loaded for saving")
            showError(message: "Live Photo not loaded")
            return
        }
        
        guard let videoPath = galleryItem.livePhotoVideoPath else {
            LMLogger.log("❌ No video path for Live Photo")
            showError(message: "Live Photo video not found")
            return
        }
        
        let videoURL = URL(fileURLWithPath: videoPath)
        
        LMLogger.log("📹 Saving Live Photo to library from Gallery...")
        
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            
            // 添加图片资源
            if let imageData = self.galleryItem.image?.jpegData(compressionQuality: 1.0) {
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
            }
            
            // 添加视频资源
            let videoOptions = PHAssetResourceCreationOptions()
            videoOptions.shouldMoveFile = false
            creationRequest.addResource(with: .pairedVideo, fileURL: videoURL, options: videoOptions)
            
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    LMLogger.log("✅ Live Photo saved to library successfully")
                    self?.showSuccessIndicator()
                } else if let error = error {
                    LMLogger.log("❌ Failed to save Live Photo: \(error.localizedDescription)")
                    self?.showError(message: "Failed to save: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showError(message: "Failed to save: \(error.localizedDescription)")
        } else {
            showSuccessIndicator()
        }
    }
    
    @objc private func deleteButtonTapped() {
        let dialog = LMAlertDialog.deleteConfirmation(
            title: "Are you sure to delete this photo from gallery?",
            message: "This action cannot be undone."
        ) { [weak self] in
            self?.performDelete()
        }
        dialog.show(on: self)
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
                        self.showError(message: "Failed to delete photo. Please try again.")
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
        let config = LMAlertDialogConfig(
            title: LMText.common.error,
            message: message,
            cancelButtonText: "",
            confirmButtonText: "OK",
            confirmButtonStyle: .normal,
            onConfirm: {}
        )
        let dialog = LMAlertDialog(config: config)
        dialog.show(on: self)
    }
}
