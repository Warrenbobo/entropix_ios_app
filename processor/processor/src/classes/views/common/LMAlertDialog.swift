//
//  LMAlertDialog.swift
//  processor
//
//  Created on 2025
//  Global reusable alert dialog component
//

import UIKit
import SnapKit

/// Configuration for alert dialog appearance and behavior
struct LMAlertDialogConfig {
    let image: UIImage?
    let title: String
    let message: String?
    let cancelButtonText: String?
    let confirmButtonText: String?
    let confirmButtonStyle: ButtonStyle
    let onCancel: (() -> Void)?
    let onConfirm: (() -> Void)?
    
    enum ButtonStyle {
        case destructive  // Red background
        case normal       // Gray background
        case gradient     // Gradient background (like Inspire Me button)
    }
    
    init(
        image: UIImage? = nil,
        title: String,
        message: String? = nil,
        cancelButtonText: String? = nil,
        confirmButtonText: String? = "OK",
        confirmButtonStyle: ButtonStyle = .destructive,
        onCancel: (() -> Void)? = nil,
        onConfirm: (() -> Void)? = nil
    ) {
        self.image = image
        self.title = title
        self.message = message
        self.cancelButtonText = cancelButtonText
        self.confirmButtonText = confirmButtonText
        self.confirmButtonStyle = confirmButtonStyle
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }
}

extension LMAlertDialog {
    
    /// 显示自定义弹窗
    public static func showAlert(title: String,
                                 message: String,
                                 cancelText: String? = nil,
                                 confirmText: String? = nil,
                                 confirmStyle: LMAlertDialogConfig.ButtonStyle = .normal,
                                 onConfirm: @escaping (() -> Void),
                                 onCancel: (() -> Void)? = nil) {
        let config = LMAlertDialogConfig(
            title: title,
            message: message,
            cancelButtonText: cancelText,
            confirmButtonText: confirmText,
            confirmButtonStyle: confirmStyle,
            onCancel: onCancel,
            onConfirm: onConfirm
        )
        // Hide cancel button by making it invisible
        let dialog = LMAlertDialog(config: config)
        dialog.show()
    }
    
    /// 显示提醒弹窗
    public static func showConfirmAlert(_ message: String,
                                        onConfirm: (() -> Void)? = nil) {
        let config = LMAlertDialogConfig(
            title: "Kind Tips",
            message: message,
            confirmButtonText: LMText.common.ok,
            confirmButtonStyle: .normal,
            onConfirm: onConfirm
        )
        // Hide cancel button by making it invisible
        let dialog = LMAlertDialog(config: config)
        dialog.show()
    }
    
    public static func showGeneralAlert(_ message: String,
                                        title: String = "Kind Tips",
                                        cancelText: String = LMText.common.cancel,
                                        confirmText: String = LMText.common.ok,
                                        onConfirm: @escaping (() -> Void),
                                        onCancel: (() -> Void)? = nil) {
        let config = LMAlertDialogConfig(
            title: title,
            message: message,
            cancelButtonText: cancelText,
            confirmButtonText: confirmText,
            confirmButtonStyle: .normal,
            onCancel: onCancel,
            onConfirm: onConfirm
        )
        // Hide cancel button by making it invisible
        let dialog = LMAlertDialog(config: config)
        dialog.show()
    }
}


/// Global alert dialog view with customizable content and actions
class LMAlertDialog: UIView {
    
    // MARK: - UI Components
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 24
        view.layer.masksToBounds = true
        return view
    }()
    
    private let imageContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .hexColor("#F5EEE1") // Beige background
        view.layer.cornerRadius = 40
        view.layer.masksToBounds = true
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .hexColor("#E87D42") // Orange color
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        label.textColor = .hexColor("#333333")
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        label.textColor = .hexColor("#808080")
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        return button
    }()
    
    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        return button
    }()
    
    private let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 16
        stackView.distribution = .fillEqually
        return stackView
    }()
    
    // MARK: - Properties
    
    private var config: LMAlertDialogConfig
    private var onDismiss: (() -> Void)?
    
    // MARK: - Initialization
    
    init(config: LMAlertDialogConfig) {
        self.config = config
        super.init(frame: .zero)
        setupUI()
        configureContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        backgroundColor = .hexColor("#000000", alpha: 0.5)
        
        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.equalToSuperview().offset(32)
            make.right.equalToSuperview().offset(-32)
        }
        
        // Setup button stack
        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(confirmButton)
        
        // Add button actions
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
    }
    
    private func configureContent() {
        // Clear existing content
        containerView.subviews.forEach { $0.removeFromSuperview() }
        
        var topView: UIView?
        
        // Add image if provided
        if let image = config.image {
            containerView.addSubview(imageContainerView)
            imageContainerView.addSubview(iconImageView)
            
            imageContainerView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(26)
                make.centerX.equalToSuperview()
                make.width.height.equalTo(80)
            }
            
            iconImageView.image = image
            iconImageView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.width.height.equalTo(40)
            }
            
            topView = imageContainerView
        }
        
        // Add title
        titleLabel.text = config.title
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            if let topView = topView {
                make.top.equalTo(topView.snp.bottom).offset(24)
            } else {
                make.top.equalToSuperview().offset(36)
            }
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
        }
        
        topView = titleLabel
        
        // Add message if provided
        if let message = config.message {
            messageLabel.text = message
            containerView.addSubview(messageLabel)
            messageLabel.snp.makeConstraints { make in
                make.top.equalTo(topView!.snp.bottom).offset(5)
                make.left.equalToSuperview().offset(24)
                make.right.equalToSuperview().offset(-24)
            }
            topView = messageLabel
        }
        
        // Configure buttons
        let showCancelButton = !(config.cancelButtonText?.isEmpty ?? true)
        
        cancelButton.setTitle(config.cancelButtonText, for: .normal)
        cancelButton.backgroundColor = .hexColor("#F2F2F2")
        cancelButton.setTitleColor(.hexColor("#333333"), for: .normal)
        
        confirmButton.setTitle(config.confirmButtonText, for: .normal)
        switch config.confirmButtonStyle {
        case .destructive:
            confirmButton.backgroundColor = .hexColor("#DE5C5C")
            confirmButton.setTitleColor(.white, for: .normal)
        case .normal:
            confirmButton.backgroundColor = .hexColor("#F2F2F2")
            confirmButton.setTitleColor(.hexColor("#333333"), for: .normal)
        case .gradient:
            // 使用与 Inspire Me 按钮相同的渐变色
            let gradientImage = UIImage.gradientImage(
                size: CGSize(width: 300, height: 52),
                colors: [UIColor.hexColor("#6680E6").cgColor,
                        UIColor.hexColor("#9966E6").cgColor],
                direction: .vertical
            )
            confirmButton.setBackgroundImage(gradientImage, for: .normal)
            confirmButton.setTitleColor(.white, for: .normal)
        }
        
        // Add button(s)
        if showCancelButton {
            // Show both buttons in stack
            containerView.addSubview(buttonStackView)
            buttonStackView.snp.makeConstraints { make in
                make.top.equalTo(topView!.snp.bottom).offset(32)
                make.left.equalToSuperview().offset(24)
                make.right.equalToSuperview().offset(-24)
                make.bottom.equalToSuperview().offset(-24)
                make.height.equalTo(52)
            }
        } else {
            // Show only confirm button (centered)
            containerView.addSubview(confirmButton)
            confirmButton.snp.makeConstraints { make in
                make.top.equalTo(topView!.snp.bottom).offset(32)
                make.left.equalToSuperview().offset(24)
                make.right.equalToSuperview().offset(-24)
                make.bottom.equalToSuperview().offset(-24)
                make.height.equalTo(52)
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleCancel() {
        config.onCancel?()
        dismiss()
    }
    
    @objc private func handleConfirm() {
        config.onConfirm?()
        dismiss()
    }
    
    // MARK: - Public Methods
    
    /// Show the dialog on the specified view controller
    func show(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss
        
        guard let window = AppTheme.Screen.window() else { return }
        
        self.frame = window.bounds
        self.alpha = 0
        window.addSubview(self)
        
        // Animate in
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
        }
    }
    
    /// Dismiss the dialog
    func dismiss() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
            self.onDismiss?()
        }
    }
}

// MARK: - Convenience Factory Methods

extension LMAlertDialog {
    
    /// Create a delete confirmation dialog
    static func deleteConfirmation(
        title: String,
        message: String,
        onConfirm: @escaping () -> Void
    ) -> LMAlertDialog {
        let config = LMAlertDialogConfig(
            title: title,
            message: message,
            cancelButtonText: LMLaunageManager.shared.common.cancel,
            confirmButtonText: LMLaunageManager.shared.common.ok,
            confirmButtonStyle: .destructive,
            onConfirm: onConfirm
        )
        return LMAlertDialog(config: config)
    }
    
    /// Create a warning dialog with icon
    static func warning(
        title: String,
        message: String,
        confirmButtonText: String,
        onConfirm: @escaping () -> Void
    ) -> LMAlertDialog {
        let warningIcon = UIImage(systemName: "exclamationmark.triangle.fill")
        let config = LMAlertDialogConfig(
            image: warningIcon,
            title: title,
            message: message,
            cancelButtonText: LMLaunageManager.shared.common.cancel,
            confirmButtonText: confirmButtonText,
            confirmButtonStyle: .destructive,
            onConfirm: onConfirm
        )
        return LMAlertDialog(config: config)
    }
    
    /// Create a camera back confirmation dialog with orange exclamation triangle
    static func cameraBackConfirmation(
        title: String,
        message: String,
        confirmButtonText: String,
        onConfirm: @escaping () -> Void
    ) -> LMAlertDialog {
        let warningIcon = UIImage(systemName: "exclamationmark.triangle.fill")
        let config = LMAlertDialogConfig(
            image: warningIcon,
            title: title,
            message: message,
            cancelButtonText: LMLaunageManager.shared.common.cancel,
            confirmButtonText: confirmButtonText,
            confirmButtonStyle: .destructive,
            onConfirm: onConfirm
        )
        return LMAlertDialog(config: config)
    }
    
    /// Create a generic confirmation dialog
    static func confirmation(
        title: String,
        message: String? = nil,
        cancelButtonText: String? = nil,
        confirmButtonText: String,
        confirmButtonStyle: LMAlertDialogConfig.ButtonStyle = .normal,
        onConfirm: @escaping () -> Void
    ) -> LMAlertDialog {
        let config = LMAlertDialogConfig(
            title: title,
            message: message,
            cancelButtonText: cancelButtonText ?? LMLaunageManager.shared.common.cancel,
            confirmButtonText: confirmButtonText,
            confirmButtonStyle: confirmButtonStyle,
            onConfirm: onConfirm
        )
        return LMAlertDialog(config: config)
    }
}
