//
//  LMSignInPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

class LMSignInPage: LMPageWrapper {
    
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    
    // 顶部品牌区域
    private let brandingSectionView = UIView()
    private let appIconImageView = UIImageView()
    private let appNameLabel = UILabel()
    private let appTaglineLabel = UILabel()
    
    // 登录表单区域
    private let loginFormSectionView = UIView()
    private let usernameInputField = LMValidatedInputField()
    private let passwordInputField = LMValidatedInputField()
    private let forgotPasswordButton = UIButton()
    
    // 登录按钮区域
    private let signInButtonSectionView = UIView()
    private let primarySignInButton = UIButton()
    
    // 分隔符区域
    private let separatorSectionView = UIView()
    private let separatorLabel = UILabel()
    
    // Apple登录区域
    private let appleSignInSectionView = UIView()
    private let appleSignInButton = UIButton()
    
    // 注册提示区域
    private let signUpPromptSectionView = UIView()
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
        setupScrollViewAndContentStack()
        setupBrandingSectionComponents()
        setupLoginFormSectionComponents()
        setupSignInButtonSectionComponents()
        setupSeparatorSectionComponents()
        setupAppleSignInSectionComponents()
        setupSignUpPromptSectionComponents()
    }
    
    private func setupScrollViewAndContentStack() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        contentStackView.axis = .vertical
        contentStackView.spacing = 32
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        
        // 添加所有主要区域到堆栈视图
        contentStackView.addArrangedSubview(brandingSectionView)
        contentStackView.addArrangedSubview(loginFormSectionView)
        contentStackView.addArrangedSubview(signInButtonSectionView)
        contentStackView.addArrangedSubview(separatorSectionView)
        contentStackView.addArrangedSubview(appleSignInSectionView)
        contentStackView.addArrangedSubview(signUpPromptSectionView)
    }
    
    private func setupBrandingSectionComponents() {
        brandingSectionView.addSubview(appIconImageView)
        brandingSectionView.addSubview(appNameLabel)
        brandingSectionView.addSubview(appTaglineLabel)
        
        // 应用图标设置
        appIconImageView.backgroundColor = UIColor.systemPurple
        appIconImageView.layer.cornerRadius = 20
        appIconImageView.clipsToBounds = true
        appIconImageView.contentMode = .center
        appIconImageView.image = UIImage(systemName: "camera.fill")
        appIconImageView.tintColor = UIColor.white
        
        // 应用名称设置
        appNameLabel.text = "InspireCam"
        appNameLabel.font = UIFont.systemFont(ofSize: 30, weight: .bold)
        appNameLabel.textColor = UIColor.label
        appNameLabel.textAlignment = .center
        appNameLabel.numberOfLines = 0
        
        // 应用标语设置
        appTaglineLabel.text = "Unlock your creative potential"
        appTaglineLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        appTaglineLabel.textColor = UIColor.systemGray
        appTaglineLabel.textAlignment = .center
        appTaglineLabel.numberOfLines = 0
    }
    
    private func setupLoginFormSectionComponents() {
        loginFormSectionView.addSubview(usernameInputField)
        loginFormSectionView.addSubview(passwordInputField)
        loginFormSectionView.addSubview(forgotPasswordButton)
        
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
        forgotPasswordButton.setTitle("Forgot password?", for: .normal)
        forgotPasswordButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        forgotPasswordButton.setTitleColor(UIColor.label, for: .normal)
        forgotPasswordButton.contentHorizontalAlignment = .trailing
        forgotPasswordButton.addTarget(self, action: #selector(handleForgotPasswordButtonTapped), for: .touchUpInside)
    }
    
    private func setupSignInButtonSectionComponents() {
        signInButtonSectionView.addSubview(primarySignInButton)
        
        // 主要登录按钮设置
        primarySignInButton.setTitle("Sign In", for: .normal)
        primarySignInButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        primarySignInButton.setTitleColor(UIColor.white, for: .normal)
        primarySignInButton.backgroundColor = UIColor.systemOrange
        primarySignInButton.layer.cornerRadius = 12
        primarySignInButton.addTarget(self, action: #selector(handlePrimarySignInButtonTapped), for: .touchUpInside)
        
        // 添加按钮触摸反馈效果
        addTouchFeedbackEffectToButton(primarySignInButton)
    }
    
    private func setupSeparatorSectionComponents() {
        separatorSectionView.addSubview(separatorLabel)
        
        separatorLabel.text = "or"
        separatorLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        separatorLabel.textColor = UIColor.systemGray2
        separatorLabel.textAlignment = .center
    }
    
    private func setupAppleSignInSectionComponents() {
        appleSignInSectionView.addSubview(appleSignInButton)
        
        // Apple登录按钮设置
        appleSignInButton.setTitle("🍎 Apple", for: .normal)
        appleSignInButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        appleSignInButton.setTitleColor(UIColor.label, for: .normal)
        appleSignInButton.backgroundColor = UIColor.systemBackground
        appleSignInButton.layer.cornerRadius = 12
        appleSignInButton.layer.borderWidth = 2
        appleSignInButton.layer.borderColor = UIColor.systemGray5.cgColor
        appleSignInButton.addTarget(self, action: #selector(handleAppleSignInButtonTapped), for: .touchUpInside)
        
        // 添加按钮触摸反馈效果
        addTouchFeedbackEffectToButton(appleSignInButton)
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
        
        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(24)
            make.width.equalTo(scrollView).offset(-48)
        }
    }
    
    private func configureBrandingSectionConstraints() {
        appIconImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(48)
            make.size.equalTo(80)
        }
        
        appNameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(appIconImageView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
        }
        
        appTaglineLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(appNameLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-24)
        }
    }
    
    private func configureLoginFormSectionConstraints() {
        usernameInputField.snp.makeConstraints { make in
            make.top.equalToSuperview()
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
            make.bottom.equalToSuperview()
        }
    }
    
    private func configureSignInButtonSectionConstraints() {
        primarySignInButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(50)
        }
    }
    
    private func configureSeparatorSectionConstraints() {
        separatorLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func configureAppleSignInSectionConstraints() {
        appleSignInButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(48)
        }
    }
    
    private func configureSignUpPromptSectionConstraints() {
        signUpPromptLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
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
        print("Apple sign in button tapped")
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
        // 清除之前的错误信息
        inputField.clearErrorMessageDisplay()
        
        // 实时验证并更新按钮状态
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
        
        let username = usernameInputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordInputField.text ?? ""
        
        // 禁用登录按钮，防止重复提交
        updateSignInButtonEnabledState(false)
        
        // 模拟网络请求
        simulateAuthenticationNetworkRequest(username: username, password: password)
    }
    
    private func simulateAuthenticationNetworkRequest(username: String, password: String) {
        print("Authenticating user: \(username)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // 模拟登录成功
            self.handleSuccessfulAuthenticationResponse()
        }
    }
    
    private func handleSuccessfulAuthenticationResponse() {
        print("Authentication successful")
        
        // 重新启用登录按钮
        validateFormInputsAndUpdateSignInButtonState()
        
        // 导航到主界面
        navigateToMainApplicationInterface()
    }
    
    private func initiateAppleSignInAuthenticationProcess() {
        print("Initiating Apple Sign In process")
        
        // 禁用Apple登录按钮
        appleSignInButton.isEnabled = false
        appleSignInButton.alpha = 0.6
        
        // 模拟Apple登录
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.handleSuccessfulAuthenticationResponse()
            self.appleSignInButton.isEnabled = true
            self.appleSignInButton.alpha = 1.0
        }
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
        if let mainRootPage = AppTheme.Screen.mainPage {
            AppTheme.Screen.window()?.rootViewController = mainRootPage
        }
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
}
