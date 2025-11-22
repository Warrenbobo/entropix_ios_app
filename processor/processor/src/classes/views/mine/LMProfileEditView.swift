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
    func profileEditViewDidTapChangePassword(_ view: LMProfileEditView)
}

class LMProfileEditView: UIView {
    
    weak var delegate: ProfileEditViewDelegate?
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Editable fields
    private let avatarContainerView = UIView()
    private let avatarImageView = UIImageView()
    private let changePhotoButton = UIButton()
    
    private let nicknameTextField = UITextField()
    private let usernameTextField = UITextField()
    private let dateOfBirthTextField = UITextField()
    
    // Non-editable fields
    private let nonEditableFieldsView = UIView()
    
    private var profileData: UserProfileData?
    
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
    
    private func setupUserInterfaceComponents() {
        addSubview(containerView)
        containerView.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        setupEditableFields()
        setupNonEditableFields()
    }
    
    private func setupEditableFields() {
        // Avatar section with label
        let avatarLabel = createFieldLabel(text: "Avatar")
        contentView.addSubview(avatarLabel)
        contentView.addSubview(avatarContainerView)
        avatarContainerView.addSubview(avatarImageView)
        avatarContainerView.addSubview(changePhotoButton)
        
        avatarImageView.backgroundColor = UIColor.systemGray4
        avatarImageView.layer.cornerRadius = 30
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.borderWidth = 2
        avatarImageView.layer.borderColor = UIColor.systemGray5.cgColor
        
        changePhotoButton.setTitle(LMText.profile.changePhoto, for: .normal)
        changePhotoButton.setTitleColor(UIColor.systemBlue, for: .normal)
        changePhotoButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        changePhotoButton.addTarget(self, action: #selector(changePhotoButtonTapped), for: .touchUpInside)
        
        // Text fields with labels - matching HTML structure
        let nicknameLabel = createFieldLabel(text: "Nickname")
        let usernameLabel = createFieldLabel(text: "Username")
        let dateOfBirthLabel = createFieldLabel(text: "Date of Birth (optional)")
        
        contentView.addSubview(nicknameLabel)
        contentView.addSubview(nicknameTextField)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(usernameTextField)
        contentView.addSubview(dateOfBirthLabel)
        contentView.addSubview(dateOfBirthTextField)
        
        setupTextField(nicknameTextField, placeholder: "Enter your nickname")
        setupTextField(usernameTextField, placeholder: "Enter your username")
        setupTextField(dateOfBirthTextField, placeholder: "Select date of birth")
        
        // Non-editable fields
        contentView.addSubview(nonEditableFieldsView)
    }
    
    private func createFieldLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium) // Matching HTML text-sm font-medium
        label.textColor = UIColor.label // Matching HTML text-gray-700
        return label
    }
    
    private func setupTextField(_ textField: UITextField, placeholder: String) {
        textField.placeholder = placeholder
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.borderStyle = .none
        textField.backgroundColor = UIColor.systemBackground
        textField.layer.cornerRadius = 8 // Matching HTML rounded-lg
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        
        // Add padding - matching HTML px-3 py-2
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 40))
        textField.leftView = paddingView
        textField.leftViewMode = .always
        
        let rightPaddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 40))
        textField.rightView = rightPaddingView
        textField.rightViewMode = .always
        
        // Focus styling - matching HTML focus:ring-2 focus:ring-blue-500
        textField.addTarget(self, action: #selector(textFieldDidBeginEditing(_:)), for: .editingDidBegin)
        textField.addTarget(self, action: #selector(textFieldDidEndEditing(_:)), for: .editingDidEnd)
    }
    
    @objc private func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor.systemBlue.cgColor
        textField.layer.borderWidth = 2
    }
    
    @objc private func textFieldDidEndEditing(_ textField: UITextField) {
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        textField.layer.borderWidth = 1
    }
    
    private func setupNonEditableFields() {
        nonEditableFieldsView.backgroundColor = UIColor.clear
        
        // Add separator line - matching HTML border-t border-gray-200
        let separatorLine = UIView()
        separatorLine.backgroundColor = UIColor.systemGray5
        nonEditableFieldsView.addSubview(separatorLine)
        
        separatorLine.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        
        // Add non-editable fields - matching HTML structure
        var lastView: UIView = separatorLine
        
        let fields = [
            ("Email Address", "alex.j@email.com"),
            ("Subscription Type", "Plus Plan"),
            ("Inspire Points", "Unlimited"),
            ("Password", "Change Password")
        ]
        
        for (index, field) in fields.enumerated() {
            let fieldView = createNonEditableField(title: field.0, value: field.1, isButton: field.0 == "Password")
            nonEditableFieldsView.addSubview(fieldView)
            
            fieldView.snp.makeConstraints { make in
                make.top.equalTo(lastView.snp.bottom).offset(16)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(32)
                
                if index == fields.count - 1 {
                    make.bottom.equalToSuperview()
                }
            }
            
            lastView = fieldView
        }
    }
    
    private func createNonEditableField(title: String, value: String, isButton: Bool = false) -> UIView {
        let fieldView = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium) // Matching HTML text-sm font-medium
        titleLabel.textColor = UIColor.systemGray // Matching HTML text-gray-700
        
        if isButton {
            let button = UIButton()
            button.setTitle(value, for: .normal)
            button.setTitleColor(UIColor.systemBlue, for: .normal) // Matching HTML text-blue-600
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
            button.contentHorizontalAlignment = .right
            button.addTarget(self, action: #selector(changePasswordButtonTapped), for: .touchUpInside)
            
            fieldView.addSubview(titleLabel)
            fieldView.addSubview(button)
            
            titleLabel.snp.makeConstraints { make in
                make.leading.centerY.equalToSuperview()
            }
            
            button.snp.makeConstraints { make in
                make.trailing.centerY.equalToSuperview()
                make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(16)
            }
        } else {
            let valueLabel = UILabel()
            valueLabel.text = value
            valueLabel.font = UIFont.systemFont(ofSize: 14)
            valueLabel.textColor = UIColor.systemGray2 // Matching HTML text-gray-500
            valueLabel.textAlignment = .right
            
            fieldView.addSubview(titleLabel)
            fieldView.addSubview(valueLabel)
            
            titleLabel.snp.makeConstraints { make in
                make.leading.centerY.equalToSuperview()
            }
            
            valueLabel.snp.makeConstraints { make in
                make.trailing.centerY.equalToSuperview()
                make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(16)
            }
        }
        
        return fieldView
    }
    
    private func configureLayoutConstraints() {
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
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
        
        // Avatar section with label
        let avatarLabel = contentView.subviews.first { ($0 as? UILabel)?.text == "Avatar" } as! UILabel
        
        avatarLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        avatarContainerView.snp.makeConstraints { make in
            make.top.equalTo(avatarLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(80)
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(60)
        }
        
        changePhotoButton.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
        }
        
        // Text fields with labels - matching HTML structure
        let nicknameLabel = contentView.subviews.first { ($0 as? UILabel)?.text == "Nickname" } as! UILabel
        let usernameLabel = contentView.subviews.first { ($0 as? UILabel)?.text == "Username" } as! UILabel
        let dateOfBirthLabel = contentView.subviews.first { ($0 as? UILabel)?.text == "Date of Birth (optional)" } as! UILabel
        
        nicknameLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarContainerView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        nicknameTextField.snp.makeConstraints { make in
            make.top.equalTo(nicknameLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(48)
        }
        
        usernameLabel.snp.makeConstraints { make in
            make.top.equalTo(nicknameTextField.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        usernameTextField.snp.makeConstraints { make in
            make.top.equalTo(usernameLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(48)
        }
        
        dateOfBirthLabel.snp.makeConstraints { make in
            make.top.equalTo(usernameTextField.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        dateOfBirthTextField.snp.makeConstraints { make in
            make.top.equalTo(dateOfBirthLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(48)
        }
        
        // Non-editable fields
        nonEditableFieldsView.snp.makeConstraints { make in
            make.top.equalTo(dateOfBirthTextField.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-40)
        }
    }
    
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
    
    func updateWithData(_ data: UserProfileData) {
        profileData = data
        
        avatarImageView.image = data.avatarImage ?? UIImage(systemName: "person.circle.fill")
        nicknameTextField.text = data.fullName
        usernameTextField.text = data.username
        dateOfBirthTextField.text = data.dateOfBirth
        
        // 更新非编辑字段的数据
        updateNonEditableFields(with: data)
    }
    
    /// 更新头像图片
    func updateAvatar(_ image: UIImage) {
        avatarImageView.image = image
        profileData?.avatarImage = image
    }
    
    private func updateNonEditableFields(with data: UserProfileData) {
        // 清除现有的非编辑字段
        nonEditableFieldsView.subviews.forEach { $0.removeFromSuperview() }
        
        // 重新添加分隔线
        let separatorLine = UIView()
        separatorLine.backgroundColor = UIColor.systemGray5
        nonEditableFieldsView.addSubview(separatorLine)
        
        separatorLine.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        
        // 重新添加非编辑字段
        var lastView: UIView = separatorLine
        
        let fields = [
            ("Email Address", data.emailAddress),
            ("Subscription Type", data.subscriptionType),
            ("Inspire Points", data.inspirePoints),
            ("Password", "Change Password")
        ]
        
        for (index, field) in fields.enumerated() {
            let fieldView = createNonEditableField(title: field.0, value: field.1, isButton: field.0 == "Password")
            nonEditableFieldsView.addSubview(fieldView)
            
            fieldView.snp.makeConstraints { make in
                make.top.equalTo(lastView.snp.bottom).offset(16)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(32)
                
                if index == fields.count - 1 {
                    make.bottom.lessThanOrEqualToSuperview()
                }
            }
            
            lastView = fieldView
        }
    }
    
    func getCurrentData() -> UserProfileData {
        var data = profileData ?? UserProfileData.createDefault()
        
        data.fullName = nicknameTextField.text ?? ""
        data.username = usernameTextField.text ?? ""
        data.dateOfBirth = dateOfBirthTextField.text?.isEmpty == false ? dateOfBirthTextField.text : nil
        
        return data
    }
    
    @objc private func changePhotoButtonTapped() {
        delegate?.profileEditViewDidTapChangePhoto(self)
    }
    
    @objc private func changePasswordButtonTapped() {
        delegate?.profileEditViewDidTapChangePassword(self)
    }
}
