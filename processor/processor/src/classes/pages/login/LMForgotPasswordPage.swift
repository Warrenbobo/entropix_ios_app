//
//  LMForgotPasswordPage.swift
//  processor
//
//  Created by muz on 2025/10/6.
//

import UIKit
import SnapKit

class LMForgotPasswordPage: LMPageWrapper {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let oldPasswordInputField = LMValidatedInputField()
    private let newPasswordInputField = LMValidatedInputField()
    private let confirmPasswordInputField = LMValidatedInputField()
    
    private let passwordRequirementLabel = UILabel()
    private let changePasswordButton = UIButton()
    
    private var oldPassword: String = ""
    private var newPassword: String = ""
    private var confirmPassword: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = "Change Password"
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        setupInputFieldDelegates()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false,
                                                     animated: animated)
        registerKeyboardNotifications()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        unregisterKeyboardNotifications()
    }
}

// MARK: - Setup Methods
extension LMForgotPasswordPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(oldPasswordInputField)
        contentView.addSubview(newPasswordInputField)
        contentView.addSubview(passwordRequirementLabel)
        contentView.addSubview(confirmPasswordInputField)
        contentView.addSubview(changePasswordButton)
        
        setupInputFieldsConfiguration()
        setupPasswordRequirementLabelConfiguration()
        setupChangePasswordButtonConfiguration()
    }
    
    private func setupInputFieldsConfiguration() {
        // 旧密码输入框
        oldPasswordInputField.configureInputFieldProperties(
            title: "Old Password",
            placeholder: "",
            isSecure: true,
            keyboardType: .default
        )
        oldPasswordInputField.returnKeyType = .next
        
        // 新密码输入框
        newPasswordInputField.configureInputFieldProperties(
            title: "New Password",
            placeholder: "",
            isSecure: true,
            keyboardType: .default
        )
        newPasswordInputField.returnKeyType = .next
        
        // 确认新密码输入框
        confirmPasswordInputField.configureInputFieldProperties(
            title: "Confirm New Password",
            placeholder: "",
            isSecure: true,
            keyboardType: .default
        )
        confirmPasswordInputField.returnKeyType = .done
    }
    
    private func setupPasswordRequirementLabelConfiguration() {
        passwordRequirementLabel.text = "Password must be at least 8 characters with\nat least one number and one letter."
        passwordRequirementLabel.font = UIFont.systemFont(ofSize: 14)
        passwordRequirementLabel.textColor = UIColor.systemGray
        passwordRequirementLabel.numberOfLines = 0
        passwordRequirementLabel.textAlignment = .left
    }
    
    private func setupChangePasswordButtonConfiguration() {
        changePasswordButton.setTitle("Change Password", for: .normal)
        changePasswordButton.setTitleColor(.white, for: .normal)
        changePasswordButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        changePasswordButton.backgroundColor = UIColor.systemBlue
        changePasswordButton.layer.cornerRadius = 12
        changePasswordButton.addTarget(self, action: #selector(handleChangePasswordButtonTapped), for: .touchUpInside)
        
        // 初始状态为禁用
        updateChangePasswordButtonState()
    }
    
    private func setupInputFieldDelegates() {
        oldPasswordInputField.delegate = self
        newPasswordInputField.delegate = self
        confirmPasswordInputField.delegate = self
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
        
        oldPasswordInputField.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        newPasswordInputField.snp.makeConstraints { make in
            make.top.equalTo(oldPasswordInputField.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        passwordRequirementLabel.snp.makeConstraints { make in
            make.top.equalTo(newPasswordInputField.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        confirmPasswordInputField.snp.makeConstraints { make in
            make.top.equalTo(passwordRequirementLabel.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        changePasswordButton.snp.makeConstraints { make in
            make.top.equalTo(confirmPasswordInputField.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(50)
            make.bottom.equalToSuperview().offset(-40)
        }
    }
}

// MARK: - Style Configuration
extension LMForgotPasswordPage {
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = UIColor.systemBackground
        scrollView.backgroundColor = UIColor.clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
    }
}

// MARK: - Action Handlers
extension LMForgotPasswordPage {
    
    @objc private func handleBackButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func handleChangePasswordButtonTapped() {
        // 清除之前的错误信息
        clearAllErrorMessages()
        
        // 验证输入
        guard validateAllInputs() else { return }
        
        // 执行密码修改逻辑
        performPasswordChange()
    }
}

// MARK: - Validation Methods
extension LMForgotPasswordPage {
    
    private func validateAllInputs() -> Bool {
        var isValid = true
        
        // 验证旧密码
        if oldPassword.isEmpty {
            oldPasswordInputField.displayErrorMessageWithText("Please enter your old password")
            isValid = false
        }
        
        // 验证新密码
        if newPassword.isEmpty {
            newPasswordInputField.displayErrorMessageWithText("Please enter a new password")
            isValid = false
        } else if !isValidPassword(newPassword) {
            newPasswordInputField.displayErrorMessageWithText("Password must be at least 8 characters with at least one number and one letter")
            isValid = false
        } else if newPassword == oldPassword {
            newPasswordInputField.displayErrorMessageWithText("New password must be different from old password")
            isValid = false
        }
        
        // 验证确认密码
        if confirmPassword.isEmpty {
            confirmPasswordInputField.displayErrorMessageWithText("Please confirm your new password")
            isValid = false
        } else if confirmPassword != newPassword {
            confirmPasswordInputField.displayErrorMessageWithText("Passwords do not match")
            isValid = false
        }
        
        return isValid
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        // 至少8个字符
        guard password.count >= 8 else { return false }
        
        // 至少包含一个数字
        let hasNumber = password.rangeOfCharacter(from: .decimalDigits) != nil
        
        // 至少包含一个字母
        let hasLetter = password.rangeOfCharacter(from: .letters) != nil
        
        return hasNumber && hasLetter
    }
    
    private func clearAllErrorMessages() {
        oldPasswordInputField.clearErrorMessageDisplay()
        newPasswordInputField.clearErrorMessageDisplay()
        confirmPasswordInputField.clearErrorMessageDisplay()
    }
    
    private func updateChangePasswordButtonState() {
        let isEnabled = !oldPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty
        
        changePasswordButton.isEnabled = isEnabled
        changePasswordButton.alpha = isEnabled ? 1.0 : 0.6
    }
}

// MARK: - Password Change Logic
extension LMForgotPasswordPage {
    
    private func performPasswordChange() {
        // 显示加载状态
        showLoadingState()
        
        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.hideLoadingState()
            
            // 模拟成功响应
            self.showPasswordChangeSuccess()
        }
    }
    
    private func showLoadingState() {
        changePasswordButton.isEnabled = false
        changePasswordButton.setTitle("Changing...", for: .normal)
        
        // 添加加载指示器
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = .white
        activityIndicator.tag = 999
        changePasswordButton.addSubview(activityIndicator)
        
        activityIndicator.snp.makeConstraints { make in
            make.trailing.equalTo(changePasswordButton.titleLabel!.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        
        activityIndicator.startAnimating()
    }
    
    private func hideLoadingState() {
        changePasswordButton.isEnabled = true
        changePasswordButton.setTitle("Change Password", for: .normal)
        
        // 移除加载指示器
        if let activityIndicator = changePasswordButton.viewWithTag(999) {
            activityIndicator.removeFromSuperview()
        }
    }
    
    private func showPasswordChangeSuccess() {
        let alert = UIAlertController(
            title: "Success",
            message: "Your password has been changed successfully.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
}

// MARK: - Keyboard Handling
extension LMForgotPasswordPage {
    
    private func registerKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKeyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func unregisterKeyboardNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func handleKeyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        
        UIView.animate(withDuration: animationDuration) {
            self.scrollView.contentInset.bottom = keyboardHeight
            self.scrollView.scrollIndicatorInsets.bottom = keyboardHeight
        }
    }
    
    @objc private func handleKeyboardWillHide(_ notification: Notification) {
        guard let animationDuration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: animationDuration) {
            self.scrollView.contentInset.bottom = 0
            self.scrollView.scrollIndicatorInsets.bottom = 0
        }
    }
}

// MARK: - LMValidatedInputFieldDelegate
extension LMForgotPasswordPage: LMValidatedInputFieldDelegate {
    
    func validatedInputFieldDidChangeText(_ inputField: LMValidatedInputField, text: String) {
        switch inputField {
        case oldPasswordInputField:
            oldPassword = text
        case newPasswordInputField:
            newPassword = text
        case confirmPasswordInputField:
            confirmPassword = text
        default:
            break
        }
        
        // 清除对应输入框的错误信息
        inputField.clearErrorMessageDisplay()
        
        // 更新按钮状态
        updateChangePasswordButtonState()
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
        case oldPasswordInputField:
            newPasswordInputField.becomeFirstResponder()
        case newPasswordInputField:
            confirmPasswordInputField.becomeFirstResponder()
        case confirmPasswordInputField:
            confirmPasswordInputField.resignFirstResponder()
            if changePasswordButton.isEnabled {
                handleChangePasswordButtonTapped()
            }
        default:
            break
        }
        
        return true
    }
}
