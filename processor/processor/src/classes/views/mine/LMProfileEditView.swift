//
//  LMProfileEditView.swift
//  processor
//
//  Created by muz on 2025/11/1.
//

import UIKit

// MARK: - ProfileEditView
protocol ProfileEditViewDelegate: AnyObject {
    func profileEditViewDidTapChangePhoto(_ view: LMProfileEditView)
}

class LMProfileEditView: UIView {
    
    weak var delegate: ProfileEditViewDelegate?
    
    // MARK: - Constants
    private enum Constants {
        static let titleLabelWidth: CGFloat = 140 // 统一的标题宽度
        static let horizontalPadding: CGFloat = 24
        static let verticalSpacing: CGFloat = 16
        static let fieldHeight: CGFloat = 32
        static let textFieldHeight: CGFloat = 48
    }
    
    private enum DateOfBirthFormat {
        static let output = "yyyy-MM-dd"
        static let inputs = ["yyyy-MM-dd", "yyyy/MM/dd"]
    }
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Editable fields - Avatar section
    private let avatarLabel = UILabel()
    private let avatarContainerView = UIView()
    private let avatarImageView = UIImageView()
    private let changePhotoButton = UIButton()
    
    // Editable fields - Text fields
    private let nicknameLabel = UILabel()
    private let nicknameTextField = UITextField()
    private let usernameLabel = UILabel()
    private let usernameTextField = UITextField()
    private let dateOfBirthLabel = UILabel()
    private let dateOfBirthContainerView = UIView()
    private let dateOfBirthTextField = UITextField()
    private let calendarIconView = UIImageView()
    private let datePicker = UIDatePicker()
    
    private var profileData: LMUserModel?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
    }
    
    // MARK: - Setup Methods
    
    private func setupUserInterfaceComponents() {
        addSubview(containerView)
        containerView.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupEditableFields()
    }
    
    private func setupEditableFields() {
        // Avatar section
        setupLabel(avatarLabel, text: LMText.profile.avatar)
        contentView.addSubview(avatarLabel)
        contentView.addSubview(avatarContainerView)
        avatarContainerView.addSubview(avatarImageView)
        avatarContainerView.addSubview(changePhotoButton)
        
        avatarImageView.backgroundColor = UIColor.systemGray4
        avatarImageView.layer.cornerRadius = 40
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.borderWidth = 1
        avatarImageView.layer.borderColor = UIColor.systemGray5.cgColor
        
        changePhotoButton.setTitle(LMText.profile.changePhoto, for: .normal)
        changePhotoButton.setTitleColor(UIColor.systemBlue, for: .normal)
        changePhotoButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        changePhotoButton.addTarget(self, action: #selector(changePhotoButtonTapped), for: .touchUpInside)
        
        // Nickname field
        setupLabel(nicknameLabel, text: LMText.profile.nickname)
        contentView.addSubview(nicknameLabel)
        contentView.addSubview(nicknameTextField)
        setupTextField(nicknameTextField, placeholder: LMText.profile.enterNickname)
        
        // Username field
        setupLabel(usernameLabel, text: LMText.profile.username)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(usernameTextField)
        setupTextField(usernameTextField, placeholder: LMText.profile.enterUsername)
        
        // Date of Birth field
        setupLabel(dateOfBirthLabel, text: LMText.profile.dateOfBirthOptional)
        contentView.addSubview(dateOfBirthLabel)
        contentView.addSubview(dateOfBirthContainerView)
        setupDateOfBirthField()
    }
    
    private func setupLabel(_ label: UILabel, text: String) {
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.label
    }
    
    private func setupTextField(_ textField: UITextField, placeholder: String) {
        textField.placeholder = placeholder
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.borderStyle = .none
        textField.backgroundColor = UIColor.systemBackground
        textField.layer.cornerRadius = 8
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 40))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        
        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 40))
        textField.rightView = rightPaddingView
        textField.rightViewMode = .always
        
        textField.addTarget(self, action: #selector(textFieldDidBeginEditing(_:)), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(textFieldDidEndEditing(_:)), for: .editingDidEnd)
    }
    
    private func setupDateOfBirthField() {
        // Container view 样式
        dateOfBirthContainerView.backgroundColor = UIColor.systemBackground
        dateOfBirthContainerView.layer.cornerRadius = 8
        dateOfBirthContainerView.layer.borderWidth = 1
        dateOfBirthContainerView.layer.borderColor = UIColor.systemGray4.cgColor
        
        // TextField 设置
        dateOfBirthTextField.placeholder = LMText.profile.dateFormatPlaceholder
        dateOfBirthTextField.font = UIFont.systemFont(ofSize: 16)
        dateOfBirthTextField.borderStyle = .none
        dateOfBirthTextField.backgroundColor = UIColor.clear
        dateOfBirthTextField.isUserInteractionEnabled = false // 禁止直接编辑
        
        // 日历图标
        calendarIconView.image = UIImage(systemName: "calendar")
        calendarIconView.tintColor = UIColor.systemGray
        calendarIconView.contentMode = .scaleAspectFit
        
        // 添加子视图
        dateOfBirthContainerView.addSubview(dateOfBirthTextField)
        dateOfBirthContainerView.addSubview(calendarIconView)
        
        // 配置 DatePicker
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.maximumDate = Date() // 不能选择未来日期
        
        // 创建工具栏 - 使用明确的 frame 避免约束冲突警告
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.barStyle = .default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: LMText.common.done, style: .done, target: self, action: #selector(datePickerDoneButtonTapped))
        let cancelButton = UIBarButtonItem(title: LMText.common.cancel, style: .plain, target: self, action: #selector(datePickerCancelButtonTapped))
        
        toolbar.setItems([cancelButton, flexSpace, doneButton], animated: false)
        
        // 添加点击手势到容器
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dateOfBirthContainerTapped))
        dateOfBirthContainerView.addGestureRecognizer(tapGesture)
        dateOfBirthContainerView.isUserInteractionEnabled = true
        
        // 创建一个隐藏的 TextField 用于显示 DatePicker
        let hiddenTextField = UITextField()
        hiddenTextField.inputView = datePicker
        hiddenTextField.inputAccessoryView = toolbar
        hiddenTextField.isHidden = true
        hiddenTextField.tag = 999
        dateOfBirthContainerView.addSubview(hiddenTextField)
    }
    
    @objc private func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor.systemBlue.cgColor
        textField.layer.borderWidth = 2
    }
    
    @objc private func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        textField.layer.borderWidth = 1
    }
    
    // MARK: - Layout Constraints
    
    private func configureLayoutConstraints() {
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-24)
        }
        
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        // Avatar section
        avatarLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
        }
        
        avatarContainerView.snp.makeConstraints { make in
            make.top.equalTo(avatarLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
            make.height.equalTo(80)
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(80)
        }
        
        changePhotoButton.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
        }
        
        // Nickname field
        nicknameLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarContainerView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
        }
        
        nicknameTextField.snp.makeConstraints { make in
            make.top.equalTo(nicknameLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
            make.height.equalTo(Constants.textFieldHeight)
        }
        
        // Username field
        usernameLabel.snp.makeConstraints { make in
            make.top.equalTo(nicknameTextField.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
        }
        
        usernameTextField.snp.makeConstraints { make in
            make.top.equalTo(usernameLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
            make.height.equalTo(Constants.textFieldHeight)
        }
        
        // Date of Birth field
        dateOfBirthLabel.snp.makeConstraints { make in
            make.top.equalTo(usernameTextField.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
        }
        
        dateOfBirthContainerView.snp.makeConstraints { make in
            make.top.equalTo(dateOfBirthLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
            make.height.equalTo(Constants.textFieldHeight)
            make.bottom.equalToSuperview().offset(-40)
        }
        
        dateOfBirthTextField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalTo(calendarIconView.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
        
        calendarIconView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        
    }
    
    // MARK: - Styles
    
    private func configureDefaultContentAndStyles() {
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 1)
        containerView.layer.shadowRadius = 3
        containerView.layer.shadowOpacity = 0.1
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
    }
    
    // MARK: - Public Methods
    
    func updateWithData(_ data: LMUserModel) {
        profileData = data
        
        // Update avatar
        avatarImageView.kf.setImage(
            with: URL(string: data.avatar ?? ""),
            placeholder: UIImage(systemName: "person.circle.fill")
        )
        
        // Update editable text fields
        nicknameTextField.text = data.nickname
        usernameTextField.text = data.username
        
        // 更新日期字段，如果有值则设置到 datePicker
        if let birthDate = data.birthDate, !birthDate.isEmpty {
            if let parsedDate = parseDateOfBirth(birthDate) {
                datePicker.date = parsedDate
                let formatted = formatDateOfBirth(parsedDate)
                dateOfBirthTextField.text = formatted
                profileData?.birthDate = formatted
            } else {
                dateOfBirthTextField.text = birthDate
            }
        } else {
            dateOfBirthTextField.text = nil
        }
    }
    
    func getCurrentData() -> LMUserModel {
        var data = profileData ?? LMUserModel(userId: "")
        
        data.nickname = nicknameTextField.text ?? ""
        data.username = usernameTextField.text ?? ""
        data.birthDate = dateOfBirthTextField.text?.isEmpty == false ? dateOfBirthTextField.text : nil
        
        return data
    }
    
    func getAvatarImage() -> UIImage? {
        return avatarImageView.image
    }
    
    func setAvatarImage(_ image: UIImage?) {
        avatarImageView.image = image
    }
    
    /// 检查是否有未保存的修改
    func hasUnsavedChanges() -> Bool {
        guard let originalData = profileData else { return false }
        
        let currentNickname = nicknameTextField.text ?? ""
        let currentUsername = usernameTextField.text ?? ""
        let currentBirthDate = dateOfBirthTextField.text
        
        let originalNickname = originalData.nickname ?? ""
        let originalUsername = originalData.username ?? ""
        let originalBirthDate = originalData.birthDate
        
        // 比较各字段是否有变化
        if currentNickname != originalNickname {
            return true
        }
        if currentUsername != originalUsername {
            return true
        }
        // 处理日期字段的空值比较
        let currentBirthDateNormalized = (currentBirthDate?.isEmpty ?? true) ? nil : currentBirthDate
        let originalBirthDateNormalized = (originalBirthDate?.isEmpty ?? true) ? nil : originalBirthDate
        if currentBirthDateNormalized != originalBirthDateNormalized {
            return true
        }
        
        return false
    }
    
    // MARK: - Actions
    
    @objc private func changePhotoButtonTapped() {
        delegate?.profileEditViewDidTapChangePhoto(self)
    }
    
    @objc private func dateOfBirthContainerTapped() {
        // 高亮容器边框
        dateOfBirthContainerView.layer.borderColor = UIColor.systemBlue.cgColor
        dateOfBirthContainerView.layer.borderWidth = 2
        
        // 显示 DatePicker
        if let hiddenTextField = dateOfBirthContainerView.viewWithTag(999) as? UITextField {
            hiddenTextField.becomeFirstResponder()
        }
    }
    
    @objc private func datePickerDoneButtonTapped() {
        // 格式化日期
        dateOfBirthTextField.text = formatDateOfBirth(datePicker.date)
        
        // 恢复边框样式
        dateOfBirthContainerView.layer.borderColor = UIColor.systemGray4.cgColor
        dateOfBirthContainerView.layer.borderWidth = 1
        
        // 关闭 DatePicker
        if let hiddenTextField = dateOfBirthContainerView.viewWithTag(999) as? UITextField {
            hiddenTextField.resignFirstResponder()
        }
    }
    
    @objc private func datePickerCancelButtonTapped() {
        // 恢复边框样式
        dateOfBirthContainerView.layer.borderColor = UIColor.systemGray4.cgColor
        dateOfBirthContainerView.layer.borderWidth = 1
        
        // 关闭 DatePicker
        if let hiddenTextField = dateOfBirthContainerView.viewWithTag(999) as? UITextField {
            hiddenTextField.resignFirstResponder()
        }
    }
    
    // MARK: - Date of Birth Formatting
    
    private func parseDateOfBirth(_ rawValue: String) -> Date? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        for format in DateOfBirthFormat.inputs {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        
        return nil
    }
    
    private func formatDateOfBirth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = DateOfBirthFormat.output
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.string(from: date)
    }
}
