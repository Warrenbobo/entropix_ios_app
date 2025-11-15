//
//  LMGalleryDetailPage.swift
//  processor
//
//  Created by Kiro on 2025/11/9.
//

import UIKit
import SnapKit

class LMGalleryDetailPage: UIViewController {
    
    // MARK: - Properties
    private let galleryItem: GalleryItem
    
    // MARK: - UI Components
    private let photoImageView = UIImageView()
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
        photoImageView.image = galleryItem.image
        photoImageView.contentMode = .scaleAspectFit
        view.addSubview(photoImageView)
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
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func downloadButtonTapped() {
        guard let image = galleryItem.image else { return }
        
        // Save to photo library
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showError(message: "Failed to save: \(error.localizedDescription)")
        } else {
            showSuccessIndicator()
        }
    }
    
    @objc private func deleteButtonTapped() {
        let alert = UIAlertController(
            title: "Are you sure to delete this photo from gallery?",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDelete()
        })
        
        present(alert, animated: true)
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
        
        // TODO: Call API to delete from server
        // For now, simulate deletion with delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            loadingAlert.dismiss(animated: true) {
                LMLogger.log("✅ Gallery item deleted successfully")
                self?.navigationController?.popViewController(animated: true)
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
        let alert = UIAlertController(title: LMText.common.error, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
