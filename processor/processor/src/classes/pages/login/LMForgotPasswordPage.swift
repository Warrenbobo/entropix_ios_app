//
//  LMForgotPasswordPage.swift
//  processor
//
//  忘记密码页面 - 通过邮箱重置密码
//

import UIKit
import SnapKit
import Toast_Swift

class LMForgotPasswordPage: LMPageWrapper {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // UI Components
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let emailInputField = LMValidatedInputField()
    private let sendResetLinkButton = UIButton()
    private let backToSignInButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.auth.resetPassword
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}

// MARK: - Setup Methods
extension LMForgotPasswordPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(emailInputField)
        contentView.addSubview(sendResetLinkButton)
        contentView.addSubview(backToSignInButton)
        
        setupTitleLabel()
        setupDescriptionLabel()
        setupEmailInputField()
        setupSendResetLinkButton()
        setupBackToSignInButton()
    }
    
    private func setupTitleLabel() {
        titleLabel.text = LMText.auth.resetPassword
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = UIColor.label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
    }
    
    private func setupDescriptionLabel() {
        descriptionLabel.text = "Enter your email address and we'll send you a link to reset your password."
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = UIColor.secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
    }
    
    private func setupEmailInputField() {
        emailInputField.configureInputFieldProperties(
            title: "",
            placeholder: "Email address",
            isSecure: false,
            keyboardType: .emailAddress
        )
        emailInputField.returnKeyType = .done
        emailInputField.delegate = self
    }
    
    private func setupSendResetLinkButton() {
        sendResetLinkButton.setTitle(LMText.auth.sendResetLink, for: .normal)
        sendResetLinkButton.setTitleColor(.white, for: .normal)
        sendResetLinkButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        sendResetLinkButton.backgroundColor = UIColor.systemOrange
        sendResetLinkButton.layer.cornerRadius = 12
        sendResetLinkButton.isEnabled = false
        sendResetLinkButton.alpha = 0.6
        sendResetLinkButton.addTarget(self, action: #selector(handleSendResetLinkButtonTapped), for: .touchUpInside)
    }
    
    private func setupBackToSignInButton() {
        backToSignInButton.setTitle(LMText.auth.backToSignIn, for: .normal)
        backToSignInButton.setTitleColor(.systemBlue, for: .normal)
        backToSignInButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        backToSignInButton.addTarget(self, action: #selector(handleBackToSignInButtonTapped), for: .touchUpInside)
    }
}

// MARK: - Layout Configuration
extension LMForgotPasswordPage {
    
    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(40)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        emailInputField.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        sendResetLinkButton.snp.makeConstraints { make in
            make.top.equalTo(emailInputField.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(50)
        }
        
        backToSignInButton.snp.makeConstraints { make in
            make.top.equalTo(sendResetLinkButton.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-40)
        }
    }
}

// MARK: - Style Configuration
extension LMForgotPasswordPage {
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = AppTheme.ThemeColor.background
        scrollView.backgroundColor = UIColor.clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
        
        // 添加点击手势关闭键盘
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleViewTapped))
        view.addGestureRecognizer(tapGesture)
    }
}

// MARK: - Action Handlers
extension LMForgotPasswordPage {
    
    @objc private func handleViewTapped() {
        view.endEditing(true)
    }
    
    @objc private func handleBackToSignInButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func handleSendResetLinkButtonTapped() {
        // 清除之前的错误信息
        emailInputField.clearErrorMessageDisplay()
        
        // 验证邮箱
        guard validateEmail() else { return }
        
        // 发送重置链接
        sendPasswordResetLink()
    }
}

// MARK: - Validation Methods
extension LMForgotPasswordPage {
    
    private func validateEmail() -> Bool {
        guard let email = emailInputField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !email.isEmpty else {
            emailInputField.displayErrorMessageWithText(LMText.auth.emailRequired)
            return false
        }
        
        // 验证邮箱格式
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: email) else {
            emailInputField.displayErrorMessageWithText(LMText.auth.invalidEmail)
            return false
        }
        
        return true
    }
    
    private func updateSendResetLinkButtonState() {
        let email = emailInputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isEnabled = !email.isEmpty
        
        sendResetLinkButton.isEnabled = isEnabled
        sendResetLinkButton.alpha = isEnabled ? 1.0 : 0.6
        sendResetLinkButton.backgroundColor = isEnabled ? UIColor.systemOrange : UIColor.systemGray4
    }
}

// MARK: - Password Reset Logic
extension LMForgotPasswordPage {
    
    private func sendPasswordResetLink() {
        guard let email = emailInputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return
        }
        
        // 显示加载状态
        showLoadingIndicator()
        
        // 调用忘记密码API（注意：根据PRD，这个功能在MVP版本中可能不完整）
        // 目前我们使用发送邮箱验证码的API作为临时方案
        LMUserManager.shared.sendEmailVerification(email: email) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.hideLoadingIndicator()
                
                switch result {
                case .success:
                    LMLogger.log("✅ Password reset link sent to: \(email)")
                    self.showResetLinkSentSuccess(email: email)
                    
                case .failure(let error):
                    LMLogger.log("❌ Failed to send reset link: \(error.localizedDescription)")
                    self.showResetLinkError(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showLoadingIndicator() {
        sendResetLinkButton.isEnabled = false
        sendResetLinkButton.setTitle("Sending...", for: .normal)
        
        // 显示 Toast loading activity
        view.makeToastActivity(.center)
    }
    
    private func hideLoadingIndicator() {
        sendResetLinkButton.setTitle(LMText.auth.sendResetLink, for: .normal)
        
        // 隐藏 Toast loading activity
        view.hideToastActivity()
        
        // 重新验证以更新按钮状态
        updateSendResetLinkButtonState()
    }
    
    private func showResetLinkSentSuccess(email: String) {
        let alert = UIAlertController(
            title: LMText.common.success,
            message: LMText.auth.resetLinkSent,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LMText.common.ok, style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showResetLinkError(message: String) {
        let alert = UIAlertController(
            title: LMText.common.error,
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LMText.common.ok, style: .default))
        
        present(alert, animated: true)
    }
}

// MARK: - LMValidatedInputFieldDelegate
extension LMForgotPasswordPage: LMValidatedInputFieldDelegate {
    
    func validatedInputFieldDidChangeText(_ inputField: LMValidatedInputField, text: String) {
        // 清除错误信息
        inputField.clearErrorMessageDisplay()
        
        // 更新按钮状态
        updateSendResetLinkButtonState()
    }
    
    func validatedInputFieldDidBeginEditing(_ inputField: LMValidatedInputField) {
        // 清除错误信息
        inputField.clearErrorMessageDisplay()
    }
    
    func validatedInputFieldDidEndEditing(_ inputField: LMValidatedInputField) {
        // 可以在这里添加实时验证逻辑
    }
    
    func validatedInputFieldShouldReturn(_ inputField: LMValidatedInputField) -> Bool {
        if inputField == emailInputField {
            inputField.resignFirstResponder()
            if sendResetLinkButton.isEnabled {
                handleSendResetLinkButtonTapped()
            }
        }
        return true
    }
}
