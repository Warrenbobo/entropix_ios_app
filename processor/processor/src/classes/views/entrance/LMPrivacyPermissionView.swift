//
//  LMPrivacyPermissionView.swift
//  processor
//
//  首次安装隐私授权弹窗视图
//

import UIKit
import SnapKit

protocol LMPrivacyPermissionViewDelegate: AnyObject {
    func privacyPermissionViewDidAgree(_ view: LMPrivacyPermissionView)
    func privacyPermissionViewDidReject(_ view: LMPrivacyPermissionView)
    func privacyPermissionViewDidTapPrivacyPolicy(_ view: LMPrivacyPermissionView)
    func privacyPermissionViewDidTapTermsOfService(_ view: LMPrivacyPermissionView)
}

class LMPrivacyPermissionView: UIView {
    
    // MARK: - Properties
    weak var delegate: LMPrivacyPermissionViewDelegate?
    
    // MARK: - UI Components
    private let backgroundOverlay = UIView()
    private let contentContainer = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let linksTextView = UITextView()
    private let agreeButton = UIButton(type: .system)
    private let rejectButton = UIButton(type: .system)
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // 背景遮罩
        backgroundOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        addSubview(backgroundOverlay)
        
        // 内容容器
        contentContainer.backgroundColor = .white
        contentContainer.layer.cornerRadius = 20
        contentContainer.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentContainer.clipsToBounds = true
        addSubview(contentContainer)
        
        // 标题
        titleLabel.text = LMText.entrance.privacyPermission
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        contentContainer.addSubview(titleLabel)
        
        // 描述文本
        descriptionLabel.text = LMText.entrance.privacyDescription
        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .left
        contentContainer.addSubview(descriptionLabel)
        
        // 链接文本
        setupLinksTextView()
        contentContainer.addSubview(linksTextView)
        
        // 同意按钮
        agreeButton.setTitle(LMText.entrance.agree, for: .normal)
        agreeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        agreeButton.setTitleColor(.white, for: .normal)
        agreeButton.backgroundColor = UIColor.systemBlue
        agreeButton.layer.cornerRadius = 25
        agreeButton.addTarget(self, action: #selector(agreeButtonTapped), for: .touchUpInside)
        contentContainer.addSubview(agreeButton)
        
        // 拒绝按钮
        rejectButton.setTitle(LMText.entrance.rejectAndExit, for: .normal)
        rejectButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        rejectButton.setTitleColor(.secondaryLabel, for: .normal)
        rejectButton.backgroundColor = .clear
        rejectButton.addTarget(self, action: #selector(rejectButtonTapped), for: .touchUpInside)
        contentContainer.addSubview(rejectButton)
    }
    
    private func setupLinksTextView() {
        linksTextView.isEditable = false
        linksTextView.isScrollEnabled = false
        linksTextView.backgroundColor = .clear
        linksTextView.textContainerInset = .zero
        linksTextView.textContainer.lineFragmentPadding = 0
        
        let fullText = LMText.entrance.viewPrivacyAndTerms
        let attributedString = NSMutableAttributedString(string: fullText)
        
        // 基础样式
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.alignment = .left
        
        attributedString.addAttributes([
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraphStyle
        ], range: NSRange(location: 0, length: fullText.count))
        
        // Privacy Policy 链接
        if let privacyRange = fullText.range(of: "Privacy Policy") {
            let nsRange = NSRange(privacyRange, in: fullText)
            attributedString.addAttributes([
                .foregroundColor: UIColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: "privacy://"
            ], range: nsRange)
        }
        
        // Terms of Service 链接
        if let termsRange = fullText.range(of: "Terms of Service") {
            let nsRange = NSRange(termsRange, in: fullText)
            attributedString.addAttributes([
                .foregroundColor: UIColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .link: "terms://"
            ], range: nsRange)
        }
        
        linksTextView.attributedText = attributedString
        linksTextView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        linksTextView.delegate = self
    }
    
    private func setupConstraints() {
        // 背景遮罩
        backgroundOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 标题
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(contentContainer).offset(30)
            make.leading.trailing.equalTo(contentContainer).inset(24)
        }
        
        // 描述文本
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.leading.trailing.equalTo(contentContainer).inset(24)
        }
        
        // 链接文本
        linksTextView.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(16)
            make.leading.trailing.equalTo(contentContainer).inset(24)
        }
        
        // 同意按钮
        agreeButton.snp.makeConstraints { make in
            make.top.equalTo(linksTextView.snp.bottom).offset(36)
            make.leading.trailing.equalTo(contentContainer).inset(24)
            make.height.equalTo(50)
        }
        
        // 拒绝按钮
        rejectButton.snp.makeConstraints { make in
            make.top.equalTo(agreeButton.snp.bottom).offset(12)
            make.centerX.equalTo(contentContainer)
            make.height.equalTo(30)
            make.bottom.equalTo(contentContainer.safeAreaLayoutGuide).offset(-20)
        }
        
        // 内容容器 - 自适应高度，底部对齐
        contentContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    // MARK: - Actions
    @objc private func agreeButtonTapped() {
        delegate?.privacyPermissionViewDidAgree(self)
    }
    
    @objc private func rejectButtonTapped() {
        delegate?.privacyPermissionViewDidReject(self)
    }
    
    // MARK: - Public Methods
    func show(in parentView: UIView, animated: Bool = true) {
        parentView.addSubview(self)
        self.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        if animated {
            self.alpha = 0
            contentContainer.transform = CGAffineTransform(translationX: 0, y: 300)
            
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                self.alpha = 1
                self.contentContainer.transform = .identity
            }
        }
    }
    
    func hide(animated: Bool = true, completion: (() -> Void)? = nil) {
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
                self.alpha = 0
                self.contentContainer.transform = CGAffineTransform(translationX: 0, y: 300)
            } completion: { _ in
                self.removeFromSuperview()
                completion?()
            }
        } else {
            self.removeFromSuperview()
            completion?()
        }
    }
}

// MARK: - UITextViewDelegate
extension LMPrivacyPermissionView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if URL.scheme == "privacy" {
            delegate?.privacyPermissionViewDidTapPrivacyPolicy(self)
            return false
        } else if URL.scheme == "terms" {
            delegate?.privacyPermissionViewDidTapTermsOfService(self)
            return false
        }
        return true
    }
}
