//
//  LMValidatedInputField.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

protocol LMValidatedInputFieldDelegate: AnyObject {
    func validatedInputFieldDidChangeText(_ inputField: LMValidatedInputField, text: String)
    func validatedInputFieldDidBeginEditing(_ inputField: LMValidatedInputField)
    func validatedInputFieldDidEndEditing(_ inputField: LMValidatedInputField)
    func validatedInputFieldShouldReturn(_ inputField: LMValidatedInputField) -> Bool
}

class LMValidatedInputField: UIView {
    
    private let titleLabel = UILabel()
    private let textField = UITextField()
    private let errorMessageLabel = UILabel()
    private let passwordVisibilityButton = UIButton()
    
    weak var delegate: LMValidatedInputFieldDelegate?
    
    var text: String? {
        get { return textField.text }
        set { textField.text = newValue }
    }
    
    var placeholder: String? {
        get { return textField.placeholder }
        set { textField.placeholder = newValue }
    }
    
    var isSecureTextEntry: Bool {
        get { return textField.isSecureTextEntry }
        set { 
            textField.isSecureTextEntry = newValue
            passwordVisibilityButton.isHidden = !newValue
        }
    }
    
    var keyboardType: UIKeyboardType {
        get { return textField.keyboardType }
        set { textField.keyboardType = newValue }
    }
    
    var returnKeyType: UIReturnKeyType {
        get { return textField.returnKeyType }
        set { textField.returnKeyType = newValue }
    }
    
    private var isPasswordVisible = false
    private var errorMessageHeightConstraint: Constraint?
    private var textFieldTopConstraint: Constraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configureInputFieldProperties(title: String, placeholder: String, isSecure: Bool = false, keyboardType: UIKeyboardType = .default) {
        titleLabel.text = title
        self.placeholder = placeholder
        self.isSecureTextEntry = isSecure
        self.keyboardType = keyboardType
        
        updateTitleLabelVisibilityAndLayout(title: title)
    }
    
    func displayErrorMessageWithText(_ errorMessage: String?) {
        if let errorMessage = errorMessage, !errorMessage.isEmpty {
            errorMessageLabel.text = errorMessage
            showErrorMessageWithAnimation()
            updateTextFieldBorderForErrorState(hasError: true)
        } else {
            hideErrorMessageWithAnimation()
            updateTextFieldBorderForErrorState(hasError: false)
        }
    }
    
    func clearErrorMessageDisplay() {
        displayErrorMessageWithText(nil)
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }
    
    @discardableResult
    override func resignFirstResponder() -> Bool {
        return textField.resignFirstResponder()
    }
}

extension LMValidatedInputField {
    
    private func setupUserInterfaceComponents() {
        addSubview(titleLabel)
        addSubview(textField)
        addSubview(errorMessageLabel)
        textField.addSubview(passwordVisibilityButton)
        
        setupTitleLabelConfiguration()
        setupTextFieldConfiguration()
        setupErrorMessageLabelConfiguration()
        setupPasswordVisibilityButtonConfiguration()
    }
    
    private func setupTitleLabelConfiguration() {
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 1
    }
    
    private func setupTextFieldConfiguration() {
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.textColor = UIColor.label
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray5.cgColor
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.delegate = self
        
        // 设置左边距
        let leftPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 50))
        textField.leftView = leftPaddingView
        textField.leftViewMode = .always
        
        // 设置右边距（为密码可见性按钮预留空间）
        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        textField.rightView = rightPaddingView
        textField.rightViewMode = .always
        
        // 添加编辑状态监听
        textField.addTarget(self, action: #selector(handleTextFieldEditingChanged), for: .editingChanged)
        textField.addTarget(self, action: #selector(handleTextFieldEditingDidBegin), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(handleTextFieldEditingDidEnd), for: .editingDidEnd)
    }
    
    private func setupErrorMessageLabelConfiguration() {
        errorMessageLabel.font = UIFont.systemFont(ofSize: 14)
        errorMessageLabel.textColor = UIColor.systemRed
        errorMessageLabel.numberOfLines = 0
        errorMessageLabel.alpha = 0
    }
    
    private func setupPasswordVisibilityButtonConfiguration() {
        passwordVisibilityButton.setImage(UIImage(systemName: "eye.slash"), for: .normal)
        passwordVisibilityButton.tintColor = UIColor.systemGray2
        passwordVisibilityButton.isHidden = true
        passwordVisibilityButton.addTarget(self, action: #selector(handlePasswordVisibilityButtonTapped), for: .touchUpInside)
    }
}

extension LMValidatedInputField {
    
    private func configureLayoutConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        
        textField.snp.makeConstraints { make in
            textFieldTopConstraint = make.top.equalTo(titleLabel.snp.bottom).offset(8).constraint
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(50)
        }
        
        passwordVisibilityButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        
        errorMessageLabel.snp.makeConstraints { make in
            make.top.equalTo(textField.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            errorMessageHeightConstraint = make.height.equalTo(0).constraint
        }
    }
}

extension LMValidatedInputField {
    
    private func configureDefaultContentAndStyles() {
        backgroundColor = UIColor.clear
    }
    
    private func updateTitleLabelVisibilityAndLayout(title: String) {
        let shouldShowTitle = !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        titleLabel.isHidden = !shouldShowTitle
        
        // 更新textField的top约束
        textFieldTopConstraint?.deactivate()
        
        if shouldShowTitle {
            // 有标题时，textField距离titleLabel底部8pt
            textField.snp.makeConstraints { make in
                textFieldTopConstraint = make.top.equalTo(titleLabel.snp.bottom).offset(8).constraint
            }
        } else {
            // 无标题时，textField直接贴顶部
            textField.snp.makeConstraints { make in
                textFieldTopConstraint = make.top.equalToSuperview().constraint
            }
        }
        
        textFieldTopConstraint?.activate()
        
        // 触发布局更新
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    private func showErrorMessageWithAnimation() {
        errorMessageHeightConstraint?.deactivate()
        
        UIView.animate(withDuration: 0.3, animations: {
            self.errorMessageLabel.alpha = 1
            self.layoutIfNeeded()
        })
    }
    
    private func hideErrorMessageWithAnimation() {
        errorMessageHeightConstraint?.activate()
        
        UIView.animate(withDuration: 0.3, animations: {
            self.errorMessageLabel.alpha = 0
            self.layoutIfNeeded()
        })
    }
    
    private func updateTextFieldBorderForErrorState(hasError: Bool) {
        let borderColor = hasError ? UIColor.systemRed : UIColor.systemGray5
        textField.layer.borderColor = borderColor.cgColor
        
        UIView.animate(withDuration: 0.2) {
            self.textField.layer.borderWidth = hasError ? 2 : 1
        }
    }
    
    private func updateTextFieldBorderForFocusState(isFocused: Bool) {
        if errorMessageLabel.alpha == 0 { // 只有在没有错误时才更新焦点状态
            let borderColor = isFocused ? UIColor.systemBlue : UIColor.systemGray5
            textField.layer.borderColor = borderColor.cgColor
            
            UIView.animate(withDuration: 0.2) {
                self.textField.layer.borderWidth = isFocused ? 2 : 1
            }
        }
    }
}

extension LMValidatedInputField {
    
    @objc private func handleTextFieldEditingChanged() {
        delegate?.validatedInputFieldDidChangeText(self, text: textField.text ?? "")
    }
    
    @objc private func handleTextFieldEditingDidBegin() {
        updateTextFieldBorderForFocusState(isFocused: true)
        delegate?.validatedInputFieldDidBeginEditing(self)
    }
    
    @objc private func handleTextFieldEditingDidEnd() {
        updateTextFieldBorderForFocusState(isFocused: false)
        delegate?.validatedInputFieldDidEndEditing(self)
    }
    
    @objc private func handlePasswordVisibilityButtonTapped() {
        isPasswordVisible.toggle()
        textField.isSecureTextEntry = !isPasswordVisible
        
        let imageName = isPasswordVisible ? "eye" : "eye.slash"
        passwordVisibilityButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
}

extension LMValidatedInputField: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return delegate?.validatedInputFieldShouldReturn(self) ?? true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // 限制输入长度
        let maxLength = 50
        let currentText = textField.text ?? ""
        let newLength = currentText.count + string.count - range.length
        return newLength <= maxLength
    }
}

extension LMValidatedInputField {
    
    func updateTitleText(_ title: String) {
        titleLabel.text = title
        updateTitleLabelVisibilityAndLayout(title: title)
    }
    
    func setTitleHidden(_ hidden: Bool) {
        let title = hidden ? "" : (titleLabel.text ?? "")
        updateTitleLabelVisibilityAndLayout(title: title)
    }
}
