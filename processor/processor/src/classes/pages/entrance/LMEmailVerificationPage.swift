//
//  LMEmailVerificationPage.swift
//  processor
//
//  邮箱验证页面
//

import UIKit
import SnapKit

class LMEmailVerificationPage: UIViewController {
    
    // MARK: - Properties
    private let email: String
    private var verificationCode: String = ""
    private var countdownTimer: Timer?
    private var remainingSeconds = 60
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let emailLabel = UILabel()
    
    private let codeInputStackView = UIStackView()
    private var codeTextFields: [UITextField] = []
    private let codeLength = 6
    
    private let resendButton = UIButton(type: .system)
    private let verifyButton = UIButton(type: .system)
    
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    // MARK: - Initialization
    init(email: String) {
        self.email = email
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewHierarchy()
        setupConstraints()
        startCountdown()
        
        // 自动聚焦第一个输入框
        codeTextFields.first?.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        countdownTimer?.invalidate()
    }
    
    // MARK: - View Hierarchy Configuration
    private func configureViewHierarchy() {
        view.backgroundColor = .systemBackground
        title = LMText.auth.emailVerification
        
        // 添加返回按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(handleCloseButtonTapped)
        )
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Title
        titleLabel.text = LMText.auth.verifyYourEmail
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        contentView.addSubview(titleLabel)
        
        // Description
        descriptionLabel.text = LMText.auth.verificationCodeSent
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        contentView.addSubview(descriptionLabel)
        
        // Email
        emailLabel.text = email
        emailLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        emailLabel.textColor = .systemBlue
        emailLabel.textAlignment = .center
        contentView.addSubview(emailLabel)
        
        // Code Input
        setupCodeInputFields()
        contentView.addSubview(codeInputStackView)
        
        // Resend Button
        resendButton.setTitle(LMText.auth.resendCode, for: .normal)
        resendButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        resendButton.addTarget(self, action: #selector(handleResendButtonTapped), for: .touchUpInside)
        contentView.addSubview(resendButton)
        
        // Verify Button
        verifyButton.setTitle(LMText.auth.verify, for: .normal)
        verifyButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        verifyButton.setTitleColor(.white, for: .normal)
        verifyButton.backgroundColor = .systemBlue
        verifyButton.layer.cornerRadius = 12
        verifyButton.isEnabled = false
        verifyButton.alpha = 0.5
        verifyButton.addTarget(self, action: #selector(handleVerifyButtonTapped), for: .touchUpInside)
        contentView.addSubview(verifyButton)
        
        // Loading Indicator
        loadingIndicator.hidesWhenStopped = true
        contentView.addSubview(loadingIndicator)
    }
    
    private func setupCodeInputFields() {
        codeInputStackView.axis = .horizontal
        codeInputStackView.spacing = 12
        codeInputStackView.distribution = .fillEqually
        
        for i in 0..<codeLength {
            let textField = UITextField()
            textField.textAlignment = .center
            textField.font = UIFont.systemFont(ofSize: 24, weight: .semibold)
            textField.keyboardType = .numberPad
            textField.layer.borderWidth = 2
            textField.layer.borderColor = UIColor.systemGray4.cgColor
            textField.layer.cornerRadius = 12
            textField.tag = i
            textField.delegate = self
            textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
            
            codeTextFields.append(textField)
            codeInputStackView.addArrangedSubview(textField)
        }
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(40)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        emailLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        codeInputStackView.snp.makeConstraints { make in
            make.top.equalTo(emailLabel.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(60)
        }
        
        resendButton.snp.makeConstraints { make in
            make.top.equalTo(codeInputStackView.snp.bottom).offset(24)
            make.centerX.equalToSuperview()
        }
        
        verifyButton.snp.makeConstraints { make in
            make.top.equalTo(resendButton.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(56)
            make.bottom.equalToSuperview().offset(-40)
        }
        
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalTo(verifyButton)
        }
    }
    
    // MARK: - Actions
    @objc private func handleCloseButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func handleResendButtonTapped() {
        guard remainingSeconds == 0 else { return }
        
        resendButton.isEnabled = false
        loadingIndicator.startAnimating()
        
        LMUserManager.shared.resendEmailVerification(email: email) { [weak self] result in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                self?.resendButton.isEnabled = true
                
                switch result {
                case .success:
                    self?.showAlert(title: LMText.common.success, message: LMText.auth.verificationCodeResent)
                    self?.startCountdown()
                case .failure(let error):
                    self?.showAlert(title: LMText.common.error, message: error.localizedDescription)
                }
            }
        }
    }
    
    @objc private func handleVerifyButtonTapped() {
        guard verificationCode.count == codeLength else { return }
        
        verifyButton.isEnabled = false
        loadingIndicator.startAnimating()
        
        LMUserManager.shared.verifyEmailCode(email: email, code: verificationCode) { [weak self] result in
            DispatchQueue.main.async {
                self?.loadingIndicator.stopAnimating()
                self?.verifyButton.isEnabled = true
                
                switch result {
                case .success:
                    self?.showAlert(title: LMText.common.success, message: LMText.auth.emailVerified) {
                        self?.dismiss(animated: true)
                    }
                case .failure(let error):
                    self?.showAlert(title: LMText.common.error, message: error.localizedDescription)
                    self?.clearCodeInput()
                }
            }
        }
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        guard let text = textField.text, !text.isEmpty else { return }
        
        // 只保留第一个字符
        if text.count > 1 {
            textField.text = String(text.prefix(1))
        }
        
        // 更新边框颜色
        textField.layer.borderColor = UIColor.systemBlue.cgColor
        
        // 自动跳转到下一个输入框
        if textField.tag < codeLength - 1 {
            codeTextFields[textField.tag + 1].becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        
        // 更新验证码
        updateVerificationCode()
    }
    
    // MARK: - Helper Methods
    private func updateVerificationCode() {
        verificationCode = codeTextFields.map { $0.text ?? "" }.joined()
        
        let isComplete = verificationCode.count == codeLength
        verifyButton.isEnabled = isComplete
        verifyButton.alpha = isComplete ? 1.0 : 0.5
    }
    
    private func clearCodeInput() {
        codeTextFields.forEach { textField in
            textField.text = ""
            textField.layer.borderColor = UIColor.systemGray4.cgColor
        }
        verificationCode = ""
        verifyButton.isEnabled = false
        verifyButton.alpha = 0.5
        codeTextFields.first?.becomeFirstResponder()
    }
    
    private func startCountdown() {
        remainingSeconds = 60
        resendButton.isEnabled = false
        updateResendButtonTitle()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.remainingSeconds -= 1
            self.updateResendButtonTitle()
            
            if self.remainingSeconds == 0 {
                self.countdownTimer?.invalidate()
                self.resendButton.isEnabled = true
            }
        }
    }
    
    private func updateResendButtonTitle() {
        if remainingSeconds > 0 {
            resendButton.setTitle("\(LMText.auth.resendCode) (\(remainingSeconds)s)", for: .normal)
        } else {
            resendButton.setTitle(LMText.auth.resendCode, for: .normal)
        }
    }
    
    private func showAlert(title: String, message: String, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LMText.common.ok, style: .default) { _ in
            completion?()
        })
        present(alert, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension LMEmailVerificationPage: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 只允许输入数字
        let allowedCharacters = CharacterSet.decimalDigits
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor.systemBlue.cgColor
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text?.isEmpty ?? true {
            textField.layer.borderColor = UIColor.systemGray4.cgColor
        }
    }
}
