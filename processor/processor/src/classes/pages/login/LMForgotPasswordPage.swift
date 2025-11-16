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
    private let newPasswordInputField = LMValidatedInputField()
    private let confirmPasswordInputField = LMValidatedInputField()
    private let resetPasswordButton = UIButton()
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
        contentView.addSubview(newPasswordInputField)
        contentView.addSubview(confirmPasswordInputField)
        contentView.addSubview(resetPasswordButton)
        contentView.addSubview(backToSignInButton)
        
        setupTitleLabel()
        setupDescriptionLabel()
        setupEmailInputField()
        setupNewPasswordInputField()
        setupConfirmPasswordInputField()
        setupResetPasswordButton()
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
        descriptionLabel.text = "Enter your email and new password to reset your password."
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
        emailInputField.returnKeyType = .next
        emailInputField.delegate = self
    }
    
    private func setupNewPasswordInputField() {
        newPasswordInputField.configureInputFieldProperties(
            title: "",
            placeholder: "New password",
            isSecure: true,
            keyboardType: .default
        )
        newPasswordInputField.returnKeyType = .next
        newPasswordInputField.delegate = self
    }
    
    private func setupConfirmPasswordInputField() {
        confirmPasswordInputField.configureInputFieldProperties(
            title: "",
            placeholder: "Confirm new password",
            isSecure: true,
            keyboardType: .default
        )
        confirmPasswordInputField.returnKeyType = .done
        confirmPasswordInputField.delegate = self
    }
    
    private func setupResetPasswordButton() {
        resetPasswordButton.setTitle("Reset Password", for: .normal)
        resetPasswordButton.setTitleColor(.white, for: .normal)
        resetPasswordButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        resetPasswordButton.backgroundColor = UIColor.systemOrange
        resetPasswordButton.layer.cornerRadius = 12
        resetPasswordButton.isEnabled = false
        resetPasswordButton.alpha = 0.6
        resetPasswordButton.addTarget(self, action: #selector(handleResetPasswordButtonTapped), for: .touchUpInside)
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
        
        newPasswordInputField.snp.makeConstraints { make in
            make.top.equalTo(emailInputField.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        confirmPasswordInputField.snp.makeConstraints { make in
            make.top.equalTo(newPasswordInputField.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        resetPasswordButton.snp.makeConstraints { make in
            make.top.equalTo(confirmPasswordInputField.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(50)
        }
        
        backToSignInButton.snp.makeConstraints { make in
            make.top.equalTo(resetPasswordButton.snp.bottom).offset(24)
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
    
    @objc private func handleResetPasswordButtonTapped() {
        // 清除之前的错误信息
        emailInputField.clearErrorMessageDisplay()
        newPasswordInputField.clearErrorMessageDisplay()
        confirmPasswordInputField.clearErrorMessageDisplay()
        
        // 验证所有输入
        guard validateAllInputs() else { return }
        
        // 重置密码
        resetPassword()
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
    
    private func validateNewPassword() -> Bool {
        guard let password = newPasswordInputField.text, !password.isEmpty else {
            newPasswordInputField.displayErrorMessageWithText("Password is required")
            return false
        }
        
        // 密码至少8位
        guard password.count >= 8 else {
            newPasswordInputField.displayErrorMessageWithText("Password must be at least 8 characters")
            return false
        }
        
        // 至少包含一个字母
        let letterRegex = ".*[A-Za-z]+.*"
        let letterTest = NSPredicate(format: "SELF MATCHES %@", letterRegex)
        guard letterTest.evaluate(with: password) else {
            newPasswordInputField.displayErrorMessageWithText("Password must contain at least one letter")
            return false
        }
        
        // 至少包含一个数字
        let numberRegex = ".*[0-9]+.*"
        let numberTest = NSPredicate(format: "SELF MATCHES %@", numberRegex)
        guard numberTest.evaluate(with: password) else {
            newPasswordInputField.displayErrorMessageWithText("Password must contain at least one number")
            return false
        }
        
        return true
    }
    
    private func validateConfirmPassword() -> Bool {
        guard let password = newPasswordInputField.text,
              let confirmPassword = confirmPasswordInputField.text,
              !password.isEmpty, !confirmPassword.isEmpty else {
            confirmPasswordInputField.displayErrorMessageWithText("Please confirm your password")
            return false
        }
        
        guard password == confirmPassword else {
            confirmPasswordInputField.displayErrorMessageWithText("Passwords do not match")
            return false
        }
        
        return true
    }
    
    private func validateAllInputs() -> Bool {
        let isEmailValid = validateEmail()
        let isPasswordValid = validateNewPassword()
        let isConfirmPasswordValid = validateConfirmPassword()
        
        return isEmailValid && isPasswordValid && isConfirmPasswordValid
    }
    
    private func updateResetPasswordButtonState() {
        let email = emailInputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = newPasswordInputField.text ?? ""
        let confirmPassword = confirmPasswordInputField.text ?? ""
        let isEnabled = !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty
        
        resetPasswordButton.isEnabled = isEnabled
        resetPasswordButton.alpha = isEnabled ? 1.0 : 0.6
        resetPasswordButton.backgroundColor = isEnabled ? UIColor.systemOrange : UIColor.systemGray4
    }
}

// MARK: - Password Reset Logic
extension LMForgotPasswordPage {
    
    private func resetPassword() {
        guard let email = emailInputField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let newPassword = newPasswordInputField.text else {
            return
        }
        
        // 显示加载状态
        showLoadingIndicator()
        
        // 调用重置密码API
        LMUserManager.shared.resetPassword(email: email, newPassword: newPassword) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.hideLoadingIndicator()
                
                switch result {
                case .success:
                    LMLogger.log("✅ Password reset successfully for: \(email)")
                    self.showResetPasswordSuccess()
                    
                case .failure(let error):
                    LMLogger.log("❌ Failed to reset password: \(error.localizedDescription)")
                    self.showResetPasswordError(message: error.localizedDescription)
                }
            }
        }
    }
    
    private func showLoadingIndicator() {
        resetPasswordButton.isEnabled = false
        resetPasswordButton.setTitle("Resetting...", for: .normal)
        
        // 显示 Toast loading activity
        view.makeToastActivity(.center)
    }
    
    private func hideLoadingIndicator() {
        resetPasswordButton.setTitle("Reset Password", for: .normal)
        
        // 隐藏 Toast loading activity
        view.hideToastActivity()
        
        // 重新验证以更新按钮状态
        updateResetPasswordButtonState()
    }
    
    private func showResetPasswordSuccess() {
        let alert = UIAlertController(
            title: LMText.common.success,
            message: "Your password has been reset successfully. Please sign in with your new password.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LMText.common.ok, style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    private func showResetPasswordError(message: String) {
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
        updateResetPasswordButtonState()
    }
    
    func validatedInputFieldDidBeginEditing(_ inputField: LMValidatedInputField) {
        // 清除错误信息
        inputField.clearErrorMessageDisplay()
    }
    
    func validatedInputFieldDidEndEditing(_ inputField: LMValidatedInputField) {
        // 可以在这里添加实时验证逻辑
    }
    
    func validatedInputFieldShouldReturn(_ inputField: LMValidatedInputField) -> Bool {
        switch inputField {
        case emailInputField:
            newPasswordInputField.becomeFirstResponder()
        case newPasswordInputField:
            confirmPasswordInputField.becomeFirstResponder()
        case confirmPasswordInputField:
            inputField.resignFirstResponder()
            if resetPasswordButton.isEnabled {
                handleResetPasswordButtonTapped()
            }
        default:
            inputField.resignFirstResponder()
        }
        return true
    }
}
