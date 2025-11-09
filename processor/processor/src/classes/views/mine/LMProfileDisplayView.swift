//
//  LMProfileDisplayView.swift
//  processor
//
//  Created by muz on 2025/11/1.
//

import UIKit

// MARK: - ProfileDisplayView
protocol ProfileDisplayViewDelegate: AnyObject {
    func profileDisplayViewDidTapCancelSubscription(_ view: LMProfileDisplayView)
    func profileDisplayViewDidTapEditProfileData(_ view: LMProfileDisplayView)
}

class LMProfileDisplayView: UIView {
    
    weak var delegate: ProfileDisplayViewDelegate?
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let editButton = UIButton()
    
    // Profile fields
    private let fieldsStackView = UIStackView()
    private let cancelSubscriptionButton = UIButton()
    
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
        
        containerView.addSubview(avatarImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(emailLabel)
        containerView.addSubview(fieldsStackView)
        containerView.addSubview(cancelSubscriptionButton)
        
        setupAvatarSection()
        setupFieldsStackView()
        setupCancelSubscriptionButton()
        
        let editButton = UIButton(type: .custom)
        editButton.setImage(UIImage(named: "edit_blue"), for: .normal)
        editButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        editButton.addTarget(self,
                             action: #selector(startEditProfileDataButtonTapped), for: .touchUpInside)
        containerView.addSubview(editButton)
        editButton.snp.makeConstraints { make in
            make.trailing.equalTo(-6)
            make.centerY.equalTo(nameLabel)
            make.width.height.equalTo(44)
        }
    }
    
    private func setupAvatarSection() {
        // Avatar - matching HTML styling (w-20 h-20 = 80px)
        avatarImageView.backgroundColor = UIColor.systemGray4
        avatarImageView.layer.cornerRadius = 40
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.borderWidth = 2
        avatarImageView.layer.borderColor = UIColor.systemGray5.cgColor
        
        // Name - matching HTML (text-xl font-semibold)
        nameLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textColor = UIColor.label
        
        // Email - matching HTML (text-gray-600)
        emailLabel.font = UIFont.systemFont(ofSize: 16)
        emailLabel.textColor = UIColor.systemGray
    }
    
    private func setupFieldsStackView() {
        fieldsStackView.axis = .vertical
        fieldsStackView.spacing = 0
        fieldsStackView.distribution = .fill
    }
    
    private func setupCancelSubscriptionButton() {
        // Matching HTML styling: border border-red-300 text-red-600 rounded-lg
        cancelSubscriptionButton.setTitle(LMText.profile.cancelSubscription, for: .normal)
        cancelSubscriptionButton.setTitleColor(UIColor.systemRed, for: .normal)
        cancelSubscriptionButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelSubscriptionButton.backgroundColor = UIColor.clear
        cancelSubscriptionButton.layer.borderWidth = 1
        cancelSubscriptionButton.layer.borderColor = UIColor.systemRed.cgColor
        cancelSubscriptionButton.layer.cornerRadius = 8
        cancelSubscriptionButton.addTarget(self, action: #selector(cancelSubscriptionButtonTapped), for: .touchUpInside)
        
        // Add icon
        let iconImage = UIImage(systemName: "xmark.circle")
        cancelSubscriptionButton.setImage(iconImage, for: .normal)
        cancelSubscriptionButton.tintColor = UIColor.systemRed
        cancelSubscriptionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
    }
    
    private func configureLayoutConstraints() {
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-120)
        }
        
        // Avatar section - matching HTML layout
        avatarImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.equalToSuperview().offset(24)
            make.size.equalTo(80)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(16)
            make.top.equalTo(avatarImageView).offset(12)
            make.trailing.equalToSuperview().offset(-24)
        }
        
        emailLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.trailing.equalToSuperview().offset(-24)
        }
        
        // Fields - matching HTML space-y-4
        fieldsStackView.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        // Cancel button - matching HTML mt-6 pt-4
        cancelSubscriptionButton.snp.makeConstraints { make in
            make.top.equalTo(fieldsStackView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(48)
            make.bottom.equalToSuperview().offset(-24)
        }
    }
    
    private func configureDefaultContentAndStyles() {
        backgroundColor = UIColor.clear
        
        // Matching HTML: bg-white rounded-xl p-6 shadow-sm
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 1)
        containerView.layer.shadowRadius = 3
        containerView.layer.shadowOpacity = 0.1
    }
    
    func updateWithData(_ data: UserProfileData) {
        profileData = data
        
        nameLabel.text = data.fullName
        emailLabel.text = data.emailAddress
        avatarImageView.image = data.avatarImage ?? UIImage(systemName: "person.circle.fill")
        
        // Clear existing fields
        fieldsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add profile fields
        addProfileField(title: "Fullname", value: data.fullName)
        addProfileField(title: "Username", value: data.username)
        addProfileField(title: "Avatar", value: "Profile Photo")
        addProfileField(title: "Subscription", value: data.subscriptionType, isHighlighted: true)
        addProfileField(title: "Inspire Points", value: data.inspirePoints)
        addProfileField(title: "Email Address", value: data.emailAddress)
        addProfileField(title: "Date of Birth", value: data.dateOfBirth ?? "-")
    }
    
    private func addProfileField(title: String, value: String, isHighlighted: Bool = false) {
        let fieldView = UIView()
        fieldView.backgroundColor = UIColor.clear
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.textColor = UIColor.systemGray // Matching HTML text-gray-600
        
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        valueLabel.textColor = isHighlighted ? UIColor.systemBlue : UIColor.label
        valueLabel.textAlignment = .right
        
        if isHighlighted {
            let underlineAttribute = [NSAttributedString.Key.underlineStyle: NSUnderlineStyle.single.rawValue]
            valueLabel.attributedText = NSAttributedString(string: value, attributes: underlineAttribute)
        }
        
        fieldView.addSubview(titleLabel)
        fieldView.addSubview(valueLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        
        valueLabel.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(16)
        }
        
        fieldView.snp.makeConstraints { make in
            make.height.equalTo(48) // Matching HTML py-3 (12px top/bottom)
        }
        
        // Add separator line - matching HTML border-b border-gray-100
        if fieldsStackView.arrangedSubviews.count > 0 {
            let separator = UIView()
            separator.backgroundColor = UIColor.systemGray6
            fieldsStackView.addArrangedSubview(separator)
            separator.snp.makeConstraints { make in
                make.height.equalTo(0.5)
            }
        }
        
        fieldsStackView.addArrangedSubview(fieldView)
    }
    

    
    @objc private func cancelSubscriptionButtonTapped() {
        delegate?.profileDisplayViewDidTapCancelSubscription(self)
    }
    
    @objc private func startEditProfileDataButtonTapped() {
        delegate?.profileDisplayViewDidTapEditProfileData(self)
    }
}
