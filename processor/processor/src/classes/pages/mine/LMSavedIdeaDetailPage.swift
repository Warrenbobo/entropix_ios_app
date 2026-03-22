//
//  LMSavedIdeaDetailPage.swift
//  processor
//
//  Created by muz on 2025/11/9.
//

import UIKit
import SnapKit
import AVFoundation

class LMSavedIdeaDetailPage: UIViewController {
    
    // MARK: - Properties
    private let savedIdea: GalleryItem
    private var isLiked: Bool = true
    
    // MARK: - UI Components
    private let photoImageView = UIImageView()
    private let watermarkImageView = UIImageView()
    private let backButtonContainer = UIView()
    private let backIconImageView = UIImageView()
    private let backLabel = UILabel()
    private let likeButton = UIButton(type: .system)
    private let goShotButton = UIButton(type: .system)
    
    // MARK: - Initialization
    init(item: GalleryItem) {
        self.savedIdea = item
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateWatermarkFrame()
    }
    
    // MARK: - View Hierarchy Configuration
    private func configureViewHierarchy() {
        view.backgroundColor = .black
        
        // Photo Image View
        photoImageView.image = savedIdea.image
        photoImageView.contentMode = .scaleAspectFit
        view.addSubview(photoImageView)

        watermarkImageView.image = UIImage(named: AppConfigs.Assets.watermarkBrand)
        watermarkImageView.contentMode = .scaleAspectFit
        watermarkImageView.alpha = 0.82
        watermarkImageView.isUserInteractionEnabled = false
        photoImageView.addSubview(watermarkImageView)
        
        // Back Button Container - 胶囊形状容器
        backButtonContainer.backgroundColor = UIColor(white: 0.25, alpha: 0.85)
        backButtonContainer.layer.cornerRadius = 22
        backButtonContainer.layer.borderWidth = 1
        backButtonContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        view.addSubview(backButtonContainer)
        
        // 配置左箭头图标
        let backConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let backImage = UIImage(systemName: "arrow.left", withConfiguration: backConfig)
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
        
        // Like Button
        likeButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        likeButton.layer.cornerRadius = 20
        likeButton.layer.borderWidth = 1
        likeButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        updateLikeButtonAppearance()
        
        view.addSubview(likeButton)
        
        // Go Shot Button
        goShotButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        goShotButton.layer.cornerRadius = 20
        goShotButton.layer.borderWidth = 1
        goShotButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        
        goShotButton.setTitle(LMText.settings.goShot, for: .normal)
        goShotButton.setTitleColor(.white, for: .normal)
        goShotButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        
        view.addSubview(goShotButton)
    }
    
    private func setupLayout() {
        photoImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
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
        
        goShotButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(40)
            make.width.greaterThanOrEqualTo(100)
        }
        
        likeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.trailing.equalTo(goShotButton.snp.leading).offset(-12)
            make.size.equalTo(40)
        }
    }
    
    private func setupActions() {
        likeButton.addTarget(self, action: #selector(likeButtonTapped), for: .touchUpInside)
        goShotButton.addTarget(self, action: #selector(goShotButtonTapped), for: .touchUpInside)
    }

    private func updateWatermarkFrame() {
        guard let image = photoImageView.image,
              let watermarkImage = watermarkImageView.image else {
            watermarkImageView.isHidden = true
            return
        }

        let displayedImageRect = LMImageAssetProcessor.displayedImageRect(
            for: image.size,
            inside: photoImageView.bounds
        )
        let watermarkFrame = LMImageAssetProcessor.watermarkFrame(
            watermarkSize: watermarkImage.size,
            inside: displayedImageRect
        )

        watermarkImageView.frame = watermarkFrame
        watermarkImageView.isHidden = watermarkFrame.isEmpty
    }
    
    private func updateLikeButtonAppearance() {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        if isLiked {
            let heartImage = UIImage(systemName: "heart.fill", withConfiguration: config)
            likeButton.setImage(heartImage, for: .normal)
            likeButton.tintColor = UIColor.hexColor("#ef4444")
        } else {
            let heartImage = UIImage(systemName: "heart", withConfiguration: config)
            likeButton.setImage(heartImage, for: .normal)
            likeButton.tintColor = .white
        }
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func likeButtonTapped() {
        if isLiked {
            // Show unlike confirmation
            showUnlikeConfirmation()
        } else {
            // Like the item
            isLiked = true
            updateLikeButtonAppearance()
            animateLikeButton()
        }
    }
    
    @objc private func goShotButtonTapped() {
        // Navigate to camera page with this idea as reference
        LMLogger.log("📸 Go Shot with idea: \(savedIdea.id)")
        
        // 使用便利初始化方法，传递 Saved Idea 数据
        let cameraPage = LMCameraPage(fromSavedIdea: savedIdea)
        navigationController?.pushViewController(cameraPage, animated: true)
    }
    
    private func showUnlikeConfirmation() {
        let dialog = LMAlertDialog.deleteConfirmation(
            title: LMText.profile.removeSavedIdeaConfirm,
            message: LMText.profile.actionCannotBeRecall
        ) { [weak self] in
            self?.performUnlike()
        }
        dialog.show()
    }
    
    private func performUnlike() {
        LMLogger.log("💔 Unliking saved idea: \(savedIdea.id)")
        
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
            
            let success = LMPhotoStorageManager.shared.deleteSavedIdea(byId: self.savedIdea.id)
            
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    if success {
                        LMLogger.log("✅ Saved idea deleted successfully from storage")
                        
                        // Update UI
                        self.isLiked = false
                        self.updateLikeButtonAppearance()
                        
                        // Navigate back to refresh the list
                        self.navigationController?.popViewController(animated: true)
                    } else {
                        LMLogger.log("❌ Failed to delete saved idea from storage")
                        self.showError(message: LMText.profile.failedToRemoveSavedIdea)
                    }
                }
            }
        }
    }
    
    private func showError(message: String) {
        LMAlertDialog.showGeneralAlert(message,
                                       title: LMText.common.error,
                                       onConfirm: {})
    }
    
    private func animateLikeButton() {
        UIView.animate(withDuration: 0.1, animations: {
            self.likeButton.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.likeButton.transform = .identity
            }
        }
    }
}
