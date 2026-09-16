//
//  LMVersionUpdateDialog.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

struct LMVersionUpdateDialogConfig {
    let title: String
    let intro: String
    let details: String
    let cancelButtonText: String
    let confirmButtonText: String
    let onCancel: (() -> Void)?
    let onConfirm: (() -> Void)?
}

final class LMVersionUpdateDialog: UIView {

    private let config: LMVersionUpdateDialogConfig
    private var onDismiss: (() -> Void)?

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.hexColor("#FFF9F7")
        view.layer.cornerRadius = 28
        view.layer.masksToBounds = true
        return view
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage.lmSymbol("rocket.fill", pointSize: 36)
        imageView.tintColor = .systemOrange
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = UIColor.hexColor("#303646")
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let introLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.hexColor("#495163")
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = UIColor.hexColor("#758096")
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
    }()

    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        button.backgroundColor = UIColor.hexColor("#FF5353")
        button.layer.cornerRadius = 24
        button.layer.masksToBounds = true
        return button
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitleColor(UIColor.hexColor("#B7BECC"), for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        return button
    }()

    init(config: LMVersionUpdateDialogConfig) {
        self.config = config
        super.init(frame: .zero)
        setupUI()
        configureContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.hexColor("#000000", alpha: 0.4)

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(AppTheme.Screen.width * 0.7)
        }

        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(introLabel)
        containerView.addSubview(detailsLabel)
        containerView.addSubview(confirmButton)
        containerView.addSubview(cancelButton)

        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.centerX.equalToSuperview()
            make.size.equalTo(60)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(28)
            make.trailing.equalToSuperview().offset(-28)
        }

        introLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(18)
            make.leading.equalToSuperview().offset(28)
            make.trailing.equalToSuperview().offset(-28)
        }

        detailsLabel.snp.makeConstraints { make in
            make.top.equalTo(introLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(28)
            make.trailing.equalToSuperview().offset(-28)
        }

        confirmButton.snp.makeConstraints { make in
            make.top.equalTo(detailsLabel.snp.bottom).offset(28)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(48)
        }

        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(confirmButton.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
            make.height.greaterThanOrEqualTo(24)
            make.bottom.equalToSuperview().offset(-20)
        }

        confirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
    }

    private func configureContent() {
        titleLabel.text = config.title
        introLabel.attributedText = formattedContentText(
            config.intro,
            textColor: UIColor.hexColor("#495163")
        )
        detailsLabel.attributedText = formattedContentText(
            config.details,
            textColor: UIColor.hexColor("#758096")
        )
        confirmButton.setTitle(config.confirmButtonText, for: .normal)
        cancelButton.setTitle(config.cancelButtonText, for: .normal)
    }

    private func formattedContentText(_ text: String,
                                      textColor: UIColor) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.alignment = .left
        return NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )
    }

    @objc private func handleConfirm() {
        config.onConfirm?()
        dismiss()
    }

    @objc private func handleCancel() {
        config.onCancel?()
        dismiss()
    }

    func show(onDismiss: (() -> Void)? = nil) {
        self.onDismiss = onDismiss

        guard let window = AppTheme.Screen.window() else { return }
        frame = window.bounds
        alpha = 0
        window.addSubview(self)

        containerView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.containerView.transform = .identity
        }
    }

    func dismiss() {
        UIView.animate(withDuration: 0.18, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
            self.containerView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { _ in
            self.removeFromSuperview()
            self.onDismiss?()
        }
    }
}
