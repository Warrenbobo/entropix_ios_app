//
//  LMSignUpPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

class LMSignUpPage: LMPageWrapper {
    
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    
    private let brandingSectionView = UIView()
    private let appIconImageView = UIImageView()
    private let createAccountTitleLabel = UILabel()
    private let createAccountSubtitleLabel = UILabel()
    
    private let registrationFormSectionView = UIView()
    private let usernameInputField = LMValidatedInputField()
    private let emailInputField = LMValidatedInputField()
    private let passwordInputField = LMValidatedInputField()
    private let confirmPasswordInputField = LMValidatedInputField()
    
    private let termsAgreementSectionView = UIView()
    private let termsAgreementCheckbox = UIButton()
    private let termsAgreementLabel = UILabel()
    
    private let signUpButtonSectionView = UIView()
    private let primarySignUpButton = UIButton()
    
    private let loginPromptSectionView = UIView()
    private let loginPromptLabel = UILabel()
    
    private var isTermsAgreed = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = "Create Account"
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

extension LMSignUpPage {
    
    private func setupUserInterfaceComponents() {
        setupScrollViewAndContentStack()
        setupBrandingSectionComponents()
        setupRegistrationFormSectionComponents()
        setupTermsAgreementSectionComponents()
        setupSignUpButtonSectionComponents()
        setupLoginPromptSectionComponents()
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
        contentStackView.addArrangedSubview(registrationFormSectionView)
        contentStackView.addArrangedSubview(termsAgreementSectionView)
        contentStackView.addArrangedSubview(signUpButtonSectionView)
        contentStackView.addArrangedSubview(loginPromptSectionView)
    }
    
    private func setupBrandingSectionComponents() {
        brandingSectionView.addSubview(appIconImageView)
        brandingSectionView.addSubview(createAccountTitleLabel)
        brandingSectionView.addSubview(createAccountSubtitleLabel)
        
        // 应用图标设置
        appIconImageView.image = UIImage(named: "app_logo_transparent_bg")
        
        // 创建账户标题设置
        createAccountTitleLabel.text = "Create Account"
        createAccountTitleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        createAccountTitleLabel.textColor = UIColor.label
        createAccountTitleLabel.textAlignment = .center
        createAccountTitleLabel.numberOfLines = 0
        
        // 创建账户副标题设置
        createAccountSubtitleLabel.text = "Join us to discover your creativity"
        createAccountSubtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        createAccountSubtitleLabel.textColor = UIColor.secondaryLabel
        createAccountSubtitleLabel.textAlignment = .center
        createAccountSubtitleLabel.numberOfLines = 0
    }
    
    private func setupRegistrationFormSectionComponents() {
        registrationFormSectionView.addSubview(usernameInputField)
        registrationFormSectionView.addSubview(emailInputField)
        registrationFormSectionView.addSubview(passwordInputField)
        registrationFormSectionView.addSubview(confirmPasswordInputField)
        
        // 配置用户名输入框
        usernameInputField.configureInputFieldProperties(
            title: "Username",
            placeholder: "Enter your username",
            isSecure: false,
            keyboardType: .default
        )
        usernameInputField.returnKeyType = .next
        usernameInputField.delegate = self
        
        // 配置邮箱输入框
        emailInputField.configureInputFieldProperties(
            title: "Email",
            placeholder: "Enter your email",
            isSecure: false,
            keyboardType: .emailAddress
        )
        emailInputField.returnKeyType = .next
        emailInputField.delegate = self
        
        // 配置密码输入框
        passwordInputField.configureInputFieldProperties(
            title: "Password",
            placeholder: "Enter your password",
            isSecure: true,
            keyboardType: .default
        )
        passwordInputField.returnKeyType = .next
        passwordInputField.delegate = self
        
        // 配置确认密码输入框
        confirmPasswordInputField.configureInputFieldProperties(
            title: "Confirm Password",
            placeholder: "Confirm your password",
            isSecure: true,
            keyboardType: .default
        )
        confirmPasswordInputField.returnKeyType = .done
        confirmPasswordInputField.delegate = self
    }
    
    private func setupTermsAgreementSectionComponents() {
        termsAgreementSectionView.addSubview(termsAgreementCheckbox)
        termsAgreementSectionView.addSubview(termsAgreementLabel)
        
        // 服务条款复选框设置
        termsAgreementCheckbox.setImage(UIImage(systemName: "square"), for: .normal)
        termsAgreementCheckbox.setImage(UIImage(systemName: "checkmark.square.fill"), for: .selected)
        termsAgreementCheckbox.tintColor = UIColor.systemBlue
        termsAgreementCheckbox.addTarget(self, action: #selector(handleTermsAgreementCheckboxTapped), for: .touchUpInside)
        
        // 服务条款文本设置
        let attributedText = NSMutableAttributedString(
            string: "By agreeing to the terms and conditions, you are entering into a legally binding contract with the service provider.",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        
        let termsRange = (attributedText.string as NSString).range(of: "terms and conditions")
        attributedText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: termsRange)
        attributedText.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: termsRange)
        
        termsAgreementLabel.attributedText = attributedText
        termsAgreementLabel.numberOfLines = 0
        termsAgreementLabel.isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTermsAgreementLabelTapped(_:)))
        termsAgreementLabel.addGestureRecognizer(tapGesture)
    }
    
    private func setupSignUpButtonSectionComponents() {
        signUpButtonSectionView.addSubview(primarySignUpButton)
        
        // 主要注册按钮设置
        primarySignUpButton.setTitle("Continue", for: .normal)
        primarySignUpButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        primarySignUpButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
        primarySignUpButton.backgroundColor = .clear
        primarySignUpButton.layer.cornerRadius = 8
        primarySignUpButton.layer.borderWidth = 1
        primarySignUpButton.layer.borderColor = UIColor.systemGray4.cgColor
        primarySignUpButton.isEnabled = false
        primarySignUpButton.addTarget(self, action: #selector(handlePrimarySignUpButtonTapped), for: .touchUpInside)
        
        // 添加按钮触摸反馈效果
        addTouchFeedbackEffectToButton(primarySignUpButton)
    }
    
    private func setupLoginPromptSectionComponents() {
        loginPromptSectionView.addSubview(loginPromptLabel)
        
        let attributedText = NSMutableAttributedString(
            string: "Already have an account? Login",
            attributes: [
                .font: UIFont.systemFont(ofSize: 16),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        
        let loginRange = (attributedText.string as NSString).range(of: "Login")
        attributedText.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: loginRange)
        attributedText.addAttribute(.font, value: UIFont.systemFont(ofSize: 16, weight: .semibold), range: loginRange)
        
        loginPromptLabel.attributedText = attributedText
        loginPromptLabel.textAlignment = .center
        loginPromptLabel.isUserInteractionEnabled = true
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleLoginPromptLabelTapped))
        loginPromptLabel.addGestureRecognizer(tapGesture)
    }
    
    private func addTouchFeedbackEffectToButton(_ button: UIButton) {
        button.addTarget(self, action: #selector(handleButtonTouchDownAnimation(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(handleButtonTouchUpAnimation(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
}

extension LMSignUpPage {
    
    private func configureLayoutConstraints() {
        configureScrollViewConstraints()
        configureBrandingSectionConstraints()
        configureRegistrationFormSectionConstraints()
        configureTermsAgreementSectionConstraints()
        configureSignUpButtonSectionConstraints()
        configureLoginPromptSectionConstraints()
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
            make.top.equalToSuperview().offset(20)
            make.width.equalTo(60)
            make.height.equalTo(50)
        }
        
        createAccountTitleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(appIconImageView.snp.bottom).offset(34)
            make.leading.trailing.equalToSuperview()
        }
        
        createAccountSubtitleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(createAccountTitleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
        }
    }
    
    private func configureRegistrationFormSectionConstraints() {
        usernameInputField.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        
        emailInputField.snp.makeConstraints { make in
            make.top.equalTo(usernameInputField.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview()
        }
        
        passwordInputField.snp.makeConstraints { make in
            make.top.equalTo(emailInputField.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview()
        }
        
        confirmPasswordInputField.snp.makeConstraints { make in
            make.top.equalTo(passwordInputField.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    private func configureTermsAgreementSectionConstraints() {
        termsAgreementCheckbox.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalToSuperview()
            make.size.equalTo(24)
        }
        
        termsAgreementLabel.snp.makeConstraints { make in
            make.leading.equalTo(termsAgreementCheckbox.snp.trailing).offset(12)
            make.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    private func configureSignUpButtonSectionConstraints() {
        primarySignUpButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(50)
        }
    }
    
    private func configureLoginPromptSectionConstraints() {
        loginPromptLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension LMSignUpPage {
    
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
}

extension LMSignUpPage {
    
    @objc private func handlePrimarySignUpButtonTapped() {
        print("Primary sign up button tapped")
        performUserRegistrationWithFormData()
    }
    
    @objc private func handleTermsAgreementCheckboxTapped() {
        isTermsAgreed.toggle()
        termsAgreementCheckbox.isSelected = isTermsAgreed
        validateFormInputsAndUpdateSignUpButtonState()
    }
    
    @objc private func handleTermsAgreementLabelTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: termsAgreementLabel)
        let attributedText = termsAgreementLabel.attributedText!
        
        if let termsRange = attributedText.string.range(of: "terms and conditions") {
            let termsNSRange = NSRange(termsRange, in: attributedText.string)
            
            let textStorage = NSTextStorage(attributedString: attributedText)
            let layoutManager = NSLayoutManager()
            let textContainer = NSTextContainer(size: termsAgreementLabel.bounds.size)
            
            textStorage.addLayoutManager(layoutManager)
            layoutManager.addTextContainer(textContainer)
            
            let characterIndex = layoutManager.characterIndex(for: location, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
            
            if NSLocationInRange(characterIndex, termsNSRange) {
                presentTermsAndConditionsViewController()
            }
        }
    }
    
    @objc private func handleLoginPromptLabelTapped() {
        print("Login prompt tapped")
        navigateToLoginViewController()
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

extension LMSignUpPage: LMValidatedInputFieldDelegate {
    
    func validatedInputFieldDidChangeText(_ inputField: LMValidatedInputField, text: String) {
        // 清除之前的错误信息
        inputField.clearErrorMessageDisplay()
        
        // 实时验证并更新按钮状态
        validateFormInputsAndUpdateSignUpButtonState()
    }
    
    func validatedInputFieldDidBeginEditing(_ inputField: LMValidatedInputField) {
        // 输入框获得焦点时的处理
    }
    
    func validatedInputFieldDidEndEditing(_ inputField: LMValidatedInputField) {
        // 输入框失去焦点时进行验证
        validateIndividualInputFieldAndShowErrors(inputField)
    }
    
    func validatedInputFieldShouldReturn(_ inputField: LMValidatedInputField) -> Bool {
        switch inputField {
        case usernameInputField:
            emailInputField.becomeFirstResponder()
        case emailInputField:
            passwordInputField.becomeFirstResponder()
        case passwordInputField:
            confirmPasswordInputField.becomeFirstResponder()
        case confirmPasswordInputField:
            inputField.resignFirstResponder()
            handlePrimarySignUpButtonTapped()
        default:
            inputField.resignFirstResponder()
        }
        return true
    }
}

extension LMSignUpPage {
    
    private func validateFormInputsAndUpdateSignUpButtonState() {
        let isUsernameValid = validateUsernameInputField()
        let isEmailValid = validateEmailInputField()
        let isPasswordValid = validatePasswordInputField()
        let isConfirmPasswordValid = validateConfirmPasswordInputField()
        let isFormValid = isUsernameValid && isEmailValid && isPasswordValid && isConfirmPasswordValid && isTermsAgreed
        
        updateSignUpButtonEnabledState(isFormValid)
    }
    
    private func validateIndividualInputFieldAndShowErrors(_ inputField: LMValidatedInputField) {
        switch inputField {
        case usernameInputField:
            if !validateUsernameInputField() {
                inputField.displayErrorMessageWithText("Username is required")
            }
        case emailInputField:
            if !validateEmailInputField() {
                inputField.displayErrorMessageWithText("Please enter a valid email address")
            }
        case passwordInputField:
            if !validatePasswordInputField() {
                inputField.displayErrorMessageWithText("Password must be at least 8 characters")
            }
        case confirmPasswordInputField:
            if !validateConfirmPasswordInputField() {
                inputField.displayErrorMessageWithText("Passwords do not match")
            }
        default:
            break
        }
    }
    
    private func validateUsernameInputField() -> Bool {
        guard let username = usernameInputField.text, !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return username.count >= 3
    }
    
    private func validateEmailInputField() -> Bool {
        guard let email = emailInputField.text, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func validatePasswordInputField() -> Bool {
        guard let password = passwordInputField.text, !password.isEmpty else {
            return false
        }
        return password.count >= 8
    }
    
    private func validateConfirmPasswordInputField() -> Bool {
        guard let password = passwordInputField.text,
              let confirmPassword = confirmPasswordInputField.text,
              !password.isEmpty, !confirmPassword.isEmpty else {
            return false
        }
        return password == confirmPassword
    }
    
    private func updateSignUpButtonEnabledState(_ isEnabled: Bool) {
        primarySignUpButton.isEnabled = isEnabled
        
        if isEnabled {
            primarySignUpButton.setTitleColor(UIColor.white, for: .normal)
            primarySignUpButton.backgroundColor = UIColor.systemOrange
            primarySignUpButton.layer.borderColor = UIColor.systemOrange.cgColor
        } else {
            primarySignUpButton.setTitleColor(UIColor.secondaryLabel, for: .normal)
            primarySignUpButton.backgroundColor = UIColor.systemGray5
            primarySignUpButton.layer.borderColor = UIColor.systemGray4.cgColor
        }
    }
}

extension LMSignUpPage {
    
    private func performUserRegistrationWithFormData() {
        guard validateAllFormInputsAndShowErrors() else {
            return
        }
        
        let username = usernameInputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let email = emailInputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let password = passwordInputField.text ?? ""
        
        // 禁用注册按钮，防止重复提交
        updateSignUpButtonEnabledState(false)
        
        // 模拟网络请求
        simulateRegistrationNetworkRequest(username: username, email: email, password: password)
    }
    
    private func validateAllFormInputsAndShowErrors() -> Bool {
        var isValid = true
        
        if !validateUsernameInputField() {
            usernameInputField.displayErrorMessageWithText("Username is required")
            isValid = false
        }
        
        if !validateEmailInputField() {
            emailInputField.displayErrorMessageWithText("Please enter a valid email address")
            isValid = false
        }
        
        if !validatePasswordInputField() {
            passwordInputField.displayErrorMessageWithText("Password must be at least 8 characters")
            isValid = false
        }
        
        if !validateConfirmPasswordInputField() {
            confirmPasswordInputField.displayErrorMessageWithText("Passwords do not match")
            isValid = false
        }
        
        if !isTermsAgreed {
            presentTermsAgreementRequiredAlert()
            isValid = false
        }
        
        return isValid
    }
    
    private func simulateRegistrationNetworkRequest(username: String, email: String, password: String) {
        
        LMApiClient.request(LMApi.User.register,
                            method: .post,
                            params: ["username": usernameInputField.text ?? "",
                                     "password": passwordInputField.text ?? "",
                                     "email": emailInputField.text ?? ""],
                            type: LMUserModel.self) { response in
            let signInModel = response.value
            print("-------------sigin user nickname is \(signInModel?.username ?? "")")
        }
    }
    
    private func handleSuccessfulRegistrationResponse() {
        print("Registration successful")
        
        // 重新启用注册按钮
        validateFormInputsAndUpdateSignUpButtonState()
        
        // 导航到主界面或登录页面
        navigateToMainApplicationInterface()
    }
}

extension LMSignUpPage {
    
    private func presentTermsAndConditionsViewController() {
        let termsVC = createTermsAndConditionsViewController()
        present(termsVC, animated: true)
    }
    
    private func navigateToLoginViewController() {
        navigationController?.popViewController(animated: true)
    }
    
    private func navigateToMainApplicationInterface() {
        if let mainRootPage = AppTheme.Screen.mainPage {
            AppTheme.Screen.window()?.rootViewController = mainRootPage
        }
    }
    
    private func presentTermsAgreementRequiredAlert() {
        let alertController = UIAlertController(
            title: "Terms Agreement Required",
            message: "Please agree to the terms and conditions to continue.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
}

extension LMSignUpPage {
    
    private func createTermsAndConditionsViewController() -> UIViewController {
        let termsVC = UIViewController()
        termsVC.view.backgroundColor = UIColor.systemBackground
        termsVC.title = "Terms and Conditions"
        return termsVC
    }
}

extension LMSignUpPage {
    
    func prefillRegistrationFormWithData(username: String? = nil, email: String? = nil) {
        if let username = username {
            usernameInputField.text = username
        }
        if let email = email {
            emailInputField.text = email
        }
        validateFormInputsAndUpdateSignUpButtonState()
    }
    
    func configureAppBrandingInformation(appName: String, tagline: String, icon: UIImage?) {
        createAccountTitleLabel.text = appName
        createAccountSubtitleLabel.text = tagline
        if let icon = icon {
            appIconImageView.image = icon
        }
    }
    
    func resetRegistrationFormToDefaultState() {
        usernameInputField.text = ""
        emailInputField.text = ""
        passwordInputField.text = ""
        confirmPasswordInputField.text = ""
        
        usernameInputField.clearErrorMessageDisplay()
        emailInputField.clearErrorMessageDisplay()
        passwordInputField.clearErrorMessageDisplay()
        confirmPasswordInputField.clearErrorMessageDisplay()
        
        isTermsAgreed = false
        termsAgreementCheckbox.isSelected = false
        
        validateFormInputsAndUpdateSignUpButtonState()
        view.endEditing(true)
    }
}
