//
//  LMWelcomeAuthenticationView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

protocol LMWelcomeAuthenticationViewDelegate: AnyObject {
    // 点击邮箱登录
    func welcomeAuthenticationViewDidTapSignInWithEmail()
    // 点击苹果登录
    func welcomeAuthenticationViewDidTapContinueWithApple()
    // 点击用户服务协议
    func welcomeAuthenticationViewDidTapTermsOfService()
    // 点击隐私政策
    func welcomeAuthenticationViewDidTapPrivacyPolicy()
    // 点击注册
    func welcomeAuthenticationViewDidTapSignUpPrompt()
}

class LMWelcomeAuthenticationView: UIView {
    
    private let contentStackView = UIStackView()
    
    private let welcomeSectionView = UIView()
    private let userAvatarImageView = UIImageView()
    private let welcomeTitleLabel = UILabel()
    private let welcomeSubtitleLabel = UILabel()
    
    private let authenticationSectionView = UIView()
    private let signInWithEmailButton = UIButton()
    private let continueWithAppleButton = UIButton()
    
    private let termsOfServiceSectionView = UIView()
    private let termsOfServiceLabel = UILabel()
    
    private let signUpPromptSectionView = UIView()
    private let signUpPromptLabel = UILabel()
    
    weak var delegate: LMWelcomeAuthenticationViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureDefaultContentAndStyles()
        setupUserInterfaceComponents()
        configureLayoutConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LMWelcomeAuthenticationView {
    
    private func configureDefaultContentAndStyles() {
        backgroundColor = .white
        layer.cornerRadius = 8
        layer.masksToBounds = true
    }
    
    private func setupUserInterfaceComponents() {
        setupContentStackViewConfiguration()
        setupWelcomeSectionComponents()
        setupAuthenticationSectionComponents()
        setupTermsOfServiceSectionComponents()
        setupSignUpPromptSectionComponents()
    }
    
    private func setupContentStackViewConfiguration() {
        addSubview(contentStackView)
        
        contentStackView.axis = .vertical
        contentStackView.spacing = 32
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        
        // 添加所有主要区域到堆栈视图
        contentStackView.addArrangedSubview(welcomeSectionView)
        contentStackView.addArrangedSubview(authenticationSectionView)
        contentStackView.addArrangedSubview(termsOfServiceSectionView)
        contentStackView.addArrangedSubview(signUpPromptSectionView)
    }
    
    private func setupWelcomeSectionComponents() {
        welcomeSectionView.addSubview(userAvatarImageView)
        welcomeSectionView.addSubview(welcomeTitleLabel)
        welcomeSectionView.addSubview(welcomeSubtitleLabel)
        
        // 用户头像设置
        userAvatarImageView.backgroundColor = UIColor.systemGray5
        userAvatarImageView.layer.cornerRadius = 50
        userAvatarImageView.clipsToBounds = true
        userAvatarImageView.contentMode = .scaleAspectFill
        userAvatarImageView.image = UIImage(systemName: "person.circle.fill")
        userAvatarImageView.tintColor = UIColor.systemGray3
        
        // 欢迎标题设置
        welcomeTitleLabel.text = "Welcome to InspireCam"
        welcomeTitleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        welcomeTitleLabel.textColor = UIColor.label
        welcomeTitleLabel.textAlignment = .center
        welcomeTitleLabel.numberOfLines = 0
        
        // 欢迎副标题设置
        welcomeSubtitleLabel.text = "Sign in to discover full features"
        welcomeSubtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        welcomeSubtitleLabel.textColor = UIColor.secondaryLabel
        welcomeSubtitleLabel.textAlignment = .center
        welcomeSubtitleLabel.numberOfLines = 0
    }
    
    private func setupAuthenticationSectionComponents() {
        authenticationSectionView.addSubview(signInWithEmailButton)
        authenticationSectionView.addSubview(continueWithAppleButton)
        
        // 邮箱登录按钮设置
        signInWithEmailButton.setTitle("📧 Sign in with Email", for: .normal)
        signInWithEmailButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        signInWithEmailButton.setTitleColor(UIColor.white, for: .normal)
        signInWithEmailButton.backgroundColor = UIColor.systemBlue
        signInWithEmailButton.layer.cornerRadius = 8
        signInWithEmailButton.addTarget(self, action: #selector(handleSignInWithEmailButtonTapped), for: .touchUpInside)
        
        // Apple登录按钮设置
        continueWithAppleButton.setTitle("🍎 Continue with Apple", for: .normal)
        continueWithAppleButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        continueWithAppleButton.setTitleColor(UIColor.white, for: .normal)
        continueWithAppleButton.backgroundColor = UIColor.black
        continueWithAppleButton.layer.cornerRadius = 8
        continueWithAppleButton.addTarget(self, action: #selector(handleContinueWithAppleButtonTapped), for: .touchUpInside)
        
        // 添加按钮触摸反馈效果
        addTouchFeedbackEffectToButton(signInWithEmailButton)
        addTouchFeedbackEffectToButton(continueWithAppleButton)
    }
    
    private func setupTermsOfServiceSectionComponents() {
        termsOfServiceSectionView.addSubview(termsOfServiceLabel)
        
        let attributedText = NSMutableAttributedString(
            string: "By continuing, you agree to our Terms of Service and Privacy Policy",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        
        // 设置链接样式
        let termsRange = (attributedText.string as NSString).range(of: "Terms of Service")
        let privacyRange = (attributedText.string as NSString).range(of: "Privacy Policy")
        
        attributedText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: termsRange)
        attributedText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: privacyRange)
        
        termsOfServiceLabel.attributedText = attributedText
        termsOfServiceLabel.textAlignment = .center
        termsOfServiceLabel.numberOfLines = 0
        termsOfServiceLabel.isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTermsOfServiceLabelTapped(_:)))
        termsOfServiceLabel.addGestureRecognizer(tapGesture)
    }
    
    private func setupSignUpPromptSectionComponents() {
        signUpPromptSectionView.addSubview(signUpPromptLabel)
        
        let attributedText = NSMutableAttributedString(
            string: "Don't have an account? Sign up",
            attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        
        let signUpRange = (attributedText.string as NSString).range(of: "Sign up")
        attributedText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: signUpRange)
        attributedText.addAttribute(.font, value: UIFont.systemFont(ofSize: 16, weight: .semibold), range: signUpRange)
        
        signUpPromptLabel.attributedText = attributedText
        signUpPromptLabel.textAlignment = .center
        signUpPromptLabel.isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSignUpPromptLabelTapped))
        signUpPromptLabel.addGestureRecognizer(tapGesture)
    }
    
    private func addTouchFeedbackEffectToButton(_ button: UIButton) {
        button.addTarget(self, action: #selector(handleButtonTouchDownAnimation(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(handleButtonTouchUpAnimation(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
}

extension LMWelcomeAuthenticationView {
    
    private func configureLayoutConstraints() {
        configureContentStackViewConstraints()
        configureWelcomeSectionConstraints()
        configureAuthenticationSectionConstraints()
        configureTermsOfServiceSectionConstraints()
        configureSignUpPromptSectionConstraints()
    }
    
    private func configureContentStackViewConstraints() {
        contentStackView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(-20)
        }
    }
    
    private func configureWelcomeSectionConstraints() {
        userAvatarImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(40)
            make.size.equalTo(100)
        }
        
        welcomeTitleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(userAvatarImageView.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview()
        }
        
        welcomeSubtitleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(welcomeTitleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
        }
    }
    
    private func configureAuthenticationSectionConstraints() {
        signInWithEmailButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.height.equalTo(50)
        }
        
        continueWithAppleButton.snp.makeConstraints { make in
            make.top.equalTo(signInWithEmailButton.snp.bottom).offset(16)
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
            make.height.equalTo(50)
            make.bottom.equalToSuperview()
        }
    }
    
    private func configureTermsOfServiceSectionConstraints() {
        termsOfServiceLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
        }
    }
    
    private func configureSignUpPromptSectionConstraints() {
        signUpPromptLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(20)
            make.trailing.equalTo(-20)
        }
    }
}

extension LMWelcomeAuthenticationView {
    
    @objc private func handleSignInWithEmailButtonTapped() {
        delegate?.welcomeAuthenticationViewDidTapSignInWithEmail()
    }
    
    @objc private func handleContinueWithAppleButtonTapped() {
        delegate?.welcomeAuthenticationViewDidTapContinueWithApple()
    }
    
    @objc private func handleTermsOfServiceLabelTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: termsOfServiceLabel)
        let attributedText = termsOfServiceLabel.attributedText!
        
        // 检测点击的是哪个链接
        if let termsRange = attributedText.string.range(of: "Terms of Service"),
           let privacyRange = attributedText.string.range(of: "Privacy Policy") {
            
            let termsNSRange = NSRange(termsRange, in: attributedText.string)
            let privacyNSRange = NSRange(privacyRange, in: attributedText.string)
            
            let textStorage = NSTextStorage(attributedString: attributedText)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: termsOfServiceLabel.bounds.size)
            
            textStorage.addLayoutManager(layoutManager)
            layoutManager.addTextContainer(textContainer)
            
            let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            
            if NSLocationInRange(characterIndex, termsNSRange) {
                delegate?.welcomeAuthenticationViewDidTapTermsOfService()
            } else if NSLocationInRange(characterIndex, privacyNSRange) {
                delegate?.welcomeAuthenticationViewDidTapPrivacyPolicy()
            }
        }
    }
    
    @objc private func handleSignUpPromptLabelTapped() {
        delegate?.welcomeAuthenticationViewDidTapSignUpPrompt()
    }
    
    @objc private func handleButtonTouchDownAnimation(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            button.alpha = 0.8
        }
    }
    
    @objc private func handleButtonTouchUpAnimation(_ button: UIButton) {
        UIView.animate(withDuration: 0.1) {
            button.transform = CGAffineTransform.identity
            button.alpha = 1.0
        }
    }
}

extension LMWelcomeAuthenticationView {
    
    func updateWelcomeMessageContent(title: String, subtitle: String) {
        welcomeTitleLabel.text = title
        welcomeSubtitleLabel.text = subtitle
    }
    
    func updateUserAvatarImageContent(_ image: UIImage?) {
        userAvatarImageView.image = image
    }
    
    func configureAuthenticationButtonsEnabled(_ enabled: Bool) {
        signInWithEmailButton.isEnabled = enabled
        continueWithAppleButton.isEnabled = enabled
        signInWithEmailButton.alpha = enabled ? 1.0 : 0.6
        continueWithAppleButton.alpha = enabled ? 1.0 : 0.6
    }
}
