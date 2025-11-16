//
//  LMSignInPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit
import AuthenticationServices
import Toast_Swift

class LMSignInPage: LMPageWrapper {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()  // 改为普通 UIView
    
    // 顶部品牌区域
    private let appIconImageView = UIImageView()
    private let appNameLabel = UILabel()
    private let appTaglineLabel = UILabel()
    
    // 登录表单区域
    private let usernameInputField = LMValidatedInputField()
    private let passwordInputField = LMValidatedInputField()
    private let forgotPasswordButton = UIButton()
    
    // 登录按钮
    private let primarySignInButton = UIButton()
    
    // 分隔符
    private let separatorView = UIView()
    private let separatorLabel = UILabel()
    
    // Apple登录按钮
    private let appleSignInButton = ASAuthorizationAppleIDButton(type: .default,
                                                                 style: .black)
    
    // 注册提示
    private let signUpPromptLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = "Sign In"
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        setupUserInteractionHandlers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}


extension LMSignInPage {
    
    private func setupUserInterfaceComponents() {
        setupScrollViewAndContentView()
        setupBrandingComponents()
        setupLoginFormComponents()
        setupSignInButtonComponent()
        setupSeparatorComponents()
        setupAppleSignInComponent()
        setupSignUpPromptComponent()
    }
    
    private func setupScrollViewAndContentView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // 直接添加所有组件到 contentView
        contentView.addSubview(appIconImageView)
        contentView.addSubview(appNameLabel)
        contentView.addSubview(appTaglineLabel)
        contentView.addSubview(usernameInputField)
        contentView.addSubview(passwordInputField)
        contentView.addSubview(forgotPasswordButton)
        contentView.addSubview(primarySignInButton)
        contentView.addSubview(separatorView)
        contentView.addSubview(separatorLabel)
        contentView.addSubview(appleSignInButton)
        contentView.addSubview(signUpPromptLabel)
    }
    
    private func setupBrandingComponents() {
        // 应用图标设置
        appIconImageView.image = UIImage(named: "app_logo_transparent_bg")
        
        // 应用名称设置
        appNameLabel.text = LMText.auth.appName
        appNameLabel.font = UIFont.systemFont(ofSize: 30, weight: .bold)
        appNameLabel.textColor = UIColor.label
        appNameLabel.textAlignment = .center
        appNameLabel.numberOfLines = 0
        
        // 应用标语设置
        appTaglineLabel.text = LMText.auth.appTagline
        appTaglineLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        appTaglineLabel.textColor = UIColor.systemGray
        appTaglineLabel.textAlignment = .center
        appTaglineLabel.numberOfLines = 0
    }
    
    private func setupLoginFormComponents() {
        
        // 配置用户名输入框（不显示标题）
        usernameInputField.configureInputFieldProperties(
            title: "",
            placeholder: "Username, email or mobile number",
            isSecure: false,
            keyboardType: .default
        )
        usernameInputField.returnKeyType = .next
        usernameInputField.delegate = self
        
        // 配置密码输入框（不显示标题）
        passwordInputField.configureInputFieldProperties(
            title: "",
            placeholder: "Password",
            isSecure: true,
            keyboardType: .default
        )
        passwordInputField.returnKeyType = .done
        passwordInputField.delegate = self
        
        // 忘记密码按钮设置
        forgotPasswordButton.setTitle(LMText.auth.forgotPassword, for: .normal)
        forgotPasswordButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        forgotPasswordButton.setTitleColor(UIColor.label, for: .normal)
        forgotPasswordButton.contentHorizontalAlignment = .trailing
        forgotPasswordButton.addTarget(self, action: #selector(handleForgotPasswordButtonTapped), for: .touchUpInside)
    }
    
    private func setupSignInButtonComponent() {
        
        // 主要登录按钮设置
        primarySignInButton.setTitle(LMText.auth.signIn, for: .normal)
        primarySignInButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        primarySignInButton.setTitleColor(UIColor.white, for: .normal)
        primarySignInButton.backgroundColor = UIColor.systemOrange
        primarySignInButton.layer.cornerRadius = 12
        primarySignInButton.addTarget(self, action: #selector(handlePrimarySignInButtonTapped), for: .touchUpInside)
        
        // 添加按钮触摸反馈效果
        addTouchFeedbackEffectToButton(primarySignInButton)
    }
    
    private func setupSeparatorComponents() {
        separatorView.backgroundColor = .hexColor("#EEEEEE")
        
        separatorLabel.backgroundColor = .white
        separatorLabel.text = LMText.auth.or
        separatorLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        separatorLabel.textColor = UIColor.systemGray2
        separatorLabel.textAlignment = .center
    }
    
    private func setupAppleSignInComponent() {
        // 添加事件监听
        appleSignInButton.addTarget(self, action: #selector(handleAppleSignInButtonTapped), for: .touchUpInside)
    }
    
    private func setupSignUpPromptComponent() {
        
        let attributedText = NSMutableAttributedString(
            string: "Don't have an account? Sign up",
            attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        
        let signUpRange = (attributedText.string as NSString).range(of: "Sign up")
        attributedText.addAttribute(.foregroundColor, value: UIColor.systemOrange, range: signUpRange)
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

extension LMSignInPage {
    
    private func configureLayoutConstraints() {
        configureScrollViewConstraints()
        configureBrandingSectionConstraints()
        configureLoginFormSectionConstraints()
        configureSignInButtonSectionConstraints()
        configureSeparatorSectionConstraints()
        configureAppleSignInSectionConstraints()
        configureSignUpPromptSectionConstraints()
    }
    
    private func configureScrollViewConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(24)
            make.width.equalTo(scrollView).offset(-48)
        }
    }
    
    private func configureBrandingSectionConstraints() {
        appIconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20)
            make.width.equalTo(100)
            make.height.equalTo(82)
        }
        
        appNameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(appIconImageView.snp.bottom).offset(26)
            make.leading.trailing.equalToSuperview()
        }
        
        appTaglineLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(appNameLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
        }
    }
    
    private func configureLoginFormSectionConstraints() {
        usernameInputField.snp.makeConstraints { make in
            make.top.equalTo(appTaglineLabel.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview()
        }
        
        passwordInputField.snp.makeConstraints { make in
            make.top.equalTo(usernameInputField.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview()
        }
        
        forgotPasswordButton.snp.makeConstraints { make in
            make.top.equalTo(passwordInputField.snp.bottom).offset(16)
            make.trailing.equalToSuperview()
            make.height.equalTo(30)
        }
    }
    
    private func configureSignInButtonSectionConstraints() {
        primarySignInButton.snp.makeConstraints { make in
            make.top.equalTo(forgotPasswordButton.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(50)
        }
    }
    
    private func configureSeparatorSectionConstraints() {
        separatorView.snp.makeConstraints { make in
            make.top.equalTo(primarySignInButton.snp.bottom).offset(30)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        separatorLabel.snp.makeConstraints { make in
            make.center.equalTo(separatorView)
            make.width.equalTo(80)
        }
    }
    
    private func configureAppleSignInSectionConstraints() {
        appleSignInButton.snp.makeConstraints { make in
            make.top.equalTo(separatorView.snp.bottom).offset(30)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(50)
        }
    }
    
    private func configureSignUpPromptSectionConstraints() {
        signUpPromptLabel.snp.makeConstraints { make in
            make.top.equalTo(appleSignInButton.snp.bottom).offset(30)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
        }
    }
}

extension LMSignInPage {
    
    private func configureDefaultContentAndStyles() {
        configureViewBackgroundAndAppearance()
        configureScrollViewProperties()
        configureKeyboardDismissalBehavior()
    }
    
    private func configureViewBackgroundAndAppearance() {
        view.backgroundColor = AppTheme.ThemeColor.background
    }
    
    private func configureScrollViewProperties() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
        scrollView.contentInsetAdjustmentBehavior = .automatic
    }
    
    private func configureKeyboardDismissalBehavior() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleViewTappedToDismissKeyboard))
        tapGesture.cancelsTouchesInView = false  // 关键：不取消其他视图的触摸事件
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupUserInteractionHandlers() {
        // 所有的交互处理器已在UI设置方法中配置
        print("User interaction handlers configured successfully")
    }
    
    private func updateGradientLayerFrames() {
        // 更新应用图标渐变层frame
        if let gradientLayer = appIconImageView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = appIconImageView.bounds
        }
        
        // 更新登录按钮渐变层frame
        if let gradientLayer = primarySignInButton.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = primarySignInButton.bounds
        }
    }
}

extension LMSignInPage {
    
    @objc private func handlePrimarySignInButtonTapped() {
        print("Primary sign in button tapped")
        performUserAuthenticationWithCredentials()
    }
    
    @objc private func handleAppleSignInButtonTapped() {
        LMLogger.log("🍎 ========== Apple sign in button tapped ==========")
        initiateAppleSignInAuthenticationProcess()
    }
    
    @objc private func handleForgotPasswordButtonTapped() {
        print("Forgot password button tapped")
        presentForgotPasswordViewController()
    }
    
    @objc private func handleSignUpPromptLabelTapped() {
        print("Sign up prompt tapped")
        navigateToSignUpViewController()
    }
    
    @objc private func handleViewTappedToDismissKeyboard() {
        view.endEditing(true)
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

extension LMSignInPage: LMValidatedInputFieldDelegate {
    
    func validatedInputFieldDidChangeText(_ inputField: LMValidatedInputField, text: String) {
        inputField.clearErrorMessageDisplay()
        validateFormInputsAndUpdateSignInButtonState()
    }
    
    func validatedInputFieldDidBeginEditing(_ inputField: LMValidatedInputField) {
        // 输入框获得焦点时的处理
    }
    
    func validatedInputFieldDidEndEditing(_ inputField: LMValidatedInputField) {
        // 输入框失去焦点时进行验证
        validateIndividualInputFieldAndShowErrors(inputField)
    }
    
    func validatedInputFieldShouldReturn(_ inputField: LMValidatedInputField) -> Bool {
        if inputField == usernameInputField {
            passwordInputField.becomeFirstResponder()
        } else if inputField == passwordInputField {
            inputField.resignFirstResponder()
            handlePrimarySignInButtonTapped()
        }
        return true
    }
}

extension LMSignInPage {
    
    private func validateFormInputsAndUpdateSignInButtonState() {
        let isUsernameValid = validateUsernameInputField()
        let isPasswordValid = validatePasswordInputField()
        let isFormValid = isUsernameValid && isPasswordValid
        
        updateSignInButtonEnabledState(isFormValid)
    }
    
    private func validateUsernameInputField() -> Bool {
        guard let username = usernameInputField.text, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return username.count >= 3
    }
    
    private func validatePasswordInputField() -> Bool {
        guard let password = passwordInputField.text, !password.isEmpty else {
            return false
        }
        return password.count >= 6
    }
    
    private func updateSignInButtonEnabledState(_ isEnabled: Bool) {
        primarySignInButton.isEnabled = isEnabled
        primarySignInButton.alpha = isEnabled ? 1.0 : 0.6
        primarySignInButton.backgroundColor = isEnabled ? UIColor.systemOrange : UIColor.systemGray4
    }
    
    private func validateIndividualInputFieldAndShowErrors(_ inputField: LMValidatedInputField) {
        switch inputField {
        case usernameInputField:
            if !validateUsernameInputField() {
                inputField.displayErrorMessageWithText("Username is required (minimum 3 characters)")
            }
        case passwordInputField:
            if !validatePasswordInputField() {
                inputField.displayErrorMessageWithText("Password is required (minimum 6 characters)")
            }
        default:
            break
        }
    }
}

// MARK: - Authentication Service Methods
extension LMSignInPage {
    
    private func performUserAuthenticationWithCredentials() {
        // 验证表单输入
        let isUsernameValid = validateUsernameInputField()
        let isPasswordValid = validatePasswordInputField()
        guard isUsernameValid && isPasswordValid else {
            presentInvalidCredentialsAlert()
            return
        }
        let identifier = usernameInputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordInputField.text ?? ""
        updateSignInButtonEnabledState(false)
        showLoadingIndicator()
        LMUserManager.shared.login(identifier: identifier, password: password) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.hideLoadingIndicator()
                switch result {
                case .success(let loginResponse):
                    LMLogger.log("✅ Login successful: \(loginResponse.user.username)")
                    self.handleSuccessfulAuthenticationResponse(loginResponse: loginResponse)
                case .failure(let error):
                    LMLogger.log("❌ Login failed: \(error.localizedDescription)")
                    self.handleAuthenticationFailure(error: error)
                }
            }
        }
    }
    
    // 登录成功
    private func handleSuccessfulAuthenticationResponse(loginResponse: LMLoginResponse) {
        LMLogger.log("✅ Authentication successful")
        validateFormInputsAndUpdateSignInButtonState()
        navigateToMainApplicationInterface()
    }
    
    // 登录失败
    private func handleAuthenticationFailure(error: Error) {
        // 重新启用登录按钮
        validateFormInputsAndUpdateSignInButtonState()
        
        // 显示错误提示
        let nsError = error as NSError
        let errorMessage = nsError.localizedDescription
        
        presentAuthenticationErrorAlert(message: errorMessage)
    }
    
    private func initiateAppleSignInAuthenticationProcess() {
        LMLogger.log("🍎 Initiating Apple Sign In process")
        
        // 禁用Apple登录按钮
        appleSignInButton.isEnabled = false
        appleSignInButton.alpha = 0.6
        
        // 使用 LMAppleAuthManager 进行 Apple 登录（统一使用 LMLoginResponse）
        LMAppleAuthManager.shared.signInWithApple { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // 重新启用Apple登录按钮
                self.appleSignInButton.isEnabled = true
                self.appleSignInButton.alpha = 1.0
                
                switch result {
                case .success(let loginResponse):
                    LMLogger.log("✅ Apple login successful")
                    self.handleSuccessfulAppleAuthenticationResponse(loginResponse: loginResponse)
                    
                case .failure(let error):
                    LMLogger.log("❌ Apple login failed: \(error.localizedDescription)")
                    // 如果用户取消登录，不显示错误提示
                    if (error as NSError).code != 1001 {
                        self.presentAuthenticationErrorAlert(message: error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func handleSuccessfulAppleAuthenticationResponse(loginResponse: LMLoginResponse) {
        LMLogger.log("✅ Apple authentication successful")
        
        // 导航到主界面
        navigateToMainApplicationInterface()
    }
    
    // MARK: - Loading Indicator
    
    private func showLoadingIndicator() {
        // 禁用按钮交互
        primarySignInButton.isEnabled = false
        primarySignInButton.setTitle("Signing in...", for: .normal)
        
        // 显示 Toast loading activity
        view.makeToastActivity(.center)
    }
    
    private func hideLoadingIndicator() {
        // 恢复按钮文本
        primarySignInButton.setTitle(LMText.auth.signIn, for: .normal)
        
        // 隐藏 Toast loading activity
        view.hideToastActivity()
        
        // 重新验证表单以更新按钮状态
        validateFormInputsAndUpdateSignInButtonState()
    }
}

extension LMSignInPage {
    
    private func presentForgotPasswordViewController() {
        let forgotPasswordVC = LMForgotPasswordPage()
        navigationController?.pushViewController(forgotPasswordVC, animated: true)
    }
    
    private func navigateToSignUpViewController() {
        let signUpVC = LMSignUpPage()
        navigationController?.pushViewController(signUpVC,
                                                 animated: true)
    }
    
    private func navigateToMainApplicationInterface() {
        // 跳转到主界面
        let mainPage = LMNavigationWrapper(rootViewController: LMMinePage())
        AppTheme.Screen.window()?.rootViewController = mainPage
    }
    
    private func presentInvalidCredentialsAlert() {
        let alertController = UIAlertController(
            title: "Invalid Credentials",
            message: "Please check your username and password.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
    
    private func presentAuthenticationErrorAlert(message: String) {
        let alertController = UIAlertController(
            title: "Sign In Failed",
            message: message,
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
}

extension LMSignInPage {
    
    func prefillUsernameFieldWithValue(_ username: String) {
        usernameInputField.text = username
        validateFormInputsAndUpdateSignInButtonState()
    }
    
    func configureAppBrandingInformation(appName: String, tagline: String, icon: UIImage?) {
        appNameLabel.text = appName
        appTaglineLabel.text = tagline
        if let icon = icon {
            appIconImageView.image = icon
        }
    }
    
    func resetFormInputFieldsToDefaultState() {
        usernameInputField.text = ""
        passwordInputField.text = ""
        
        usernameInputField.clearErrorMessageDisplay()
        passwordInputField.clearErrorMessageDisplay()
        
        validateFormInputsAndUpdateSignInButtonState()
        view.endEditing(true)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
}
