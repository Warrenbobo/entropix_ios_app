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
    func profileDisplayViewDidTapSubscription(_ view: LMProfileDisplayView)
}

class LMProfileDisplayView: UIView {
    
    weak var delegate: ProfileDisplayViewDelegate?
    
    // MARK: - Constants
    private enum Constants {
        static let horizontalPadding: CGFloat = 24
    }
    
    // MARK: - UI Components
    private let containerView = UIView()
    
    // Header section
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let editButton = UIButton(type: .custom)
    
    // Profile fields container
    private let fieldsContainerView = UIView()
    
    // Profile Item Views - 按图片顺序
    private let nicknameItemView = LMProfileItemView(title: "Nickname")
    private let usernameItemView = LMProfileItemView(title: "Username")
    private let avatarItemView = LMProfileItemView(title: "Avatar", content: "Profile Photo")
    private let subscriptionItemView = LMProfileItemView(title: "Subscription")
    private let inspirePointsItemView = LMProfileItemView(title: "Inspire Points")
    private let emailAddressItemView = LMProfileItemView(title: "Email Address")
    private let dateOfBirthItemView = LMProfileItemView(title: "Date of Birth")
    
    // Cancel subscription button
    private let cancelSubscriptionButton = UIButton()
    
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
        
        setupHeaderSection()
        setupFieldRows()
        setupCancelSubscriptionButton()
    }
    
    private func setupHeaderSection() {
        containerView.addSubview(avatarImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(emailLabel)
        containerView.addSubview(editButton)
        
        // Avatar
        avatarImageView.backgroundColor = UIColor.systemGray4
        avatarImageView.layer.cornerRadius = 40
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.layer.borderWidth = 2
        avatarImageView.layer.borderColor = UIColor.systemGray5.cgColor
        
        // Name
        nameLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textColor = UIColor.label
        
        // Email
        emailLabel.font = UIFont.systemFont(ofSize: 16)
        emailLabel.textColor = UIColor.systemGray
        
        // Edit button
        editButton.setImage(UIImage(named: "edit_blue"), for: .normal)
        editButton.imageEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        editButton.addTarget(self, action: #selector(startEditProfileDataButtonTapped), for: .touchUpInside)
    }
    
    private func setupFieldRows() {
        containerView.addSubview(fieldsContainerView)
        
        // 添加所有 Profile Item Views
        fieldsContainerView.addSubview(nicknameItemView)
        fieldsContainerView.addSubview(usernameItemView)
        fieldsContainerView.addSubview(avatarItemView)
        fieldsContainerView.addSubview(subscriptionItemView)
        fieldsContainerView.addSubview(inspirePointsItemView)
        fieldsContainerView.addSubview(emailAddressItemView)
        fieldsContainerView.addSubview(dateOfBirthItemView)
        
        // 设置 Subscription 项目的代理（可点击）
        subscriptionItemView.delegate = self
    }
    
    private func setupCancelSubscriptionButton() {
        containerView.addSubview(cancelSubscriptionButton)
        
        cancelSubscriptionButton.setTitle(LMText.profile.cancelSubscription, for: .normal)
        cancelSubscriptionButton.setTitleColor(UIColor.systemRed, for: .normal)
        cancelSubscriptionButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelSubscriptionButton.backgroundColor = UIColor.clear
        cancelSubscriptionButton.layer.borderWidth = 1
        cancelSubscriptionButton.layer.borderColor = UIColor.systemRed.cgColor
        cancelSubscriptionButton.layer.cornerRadius = 8
        cancelSubscriptionButton.addTarget(self, action: #selector(cancelSubscriptionButtonTapped), for: .touchUpInside)
        
        let iconImage = UIImage(systemName: "xmark.circle")
        cancelSubscriptionButton.setImage(iconImage, for: .normal)
        cancelSubscriptionButton.tintColor = UIColor.systemRed
        cancelSubscriptionButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
    }
    
    // MARK: - Layout Constraints
    
    private func configureLayoutConstraints() {
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-40)
        }
        
        // Header section
        avatarImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.equalToSuperview().offset(Constants.horizontalPadding)
            make.size.equalTo(80)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(16)
            make.top.equalTo(avatarImageView).offset(12)
            make.trailing.equalTo(editButton.snp.leading).offset(-8)
        }
        
        emailLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.trailing.equalTo(nameLabel)
        }
        
        editButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-6)
            make.centerY.equalTo(nameLabel)
            make.width.height.equalTo(44)
        }
        
        // Fields container
        fieldsContainerView.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
        }
        
        // Profile Item Views 布局
        nicknameItemView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        
        usernameItemView.snp.makeConstraints { make in
            make.top.equalTo(nicknameItemView.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        
        avatarItemView.snp.makeConstraints { make in
            make.top.equalTo(usernameItemView.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        
        subscriptionItemView.snp.makeConstraints { make in
            make.top.equalTo(avatarItemView.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        
        inspirePointsItemView.snp.makeConstraints { make in
            make.top.equalTo(subscriptionItemView.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        
        emailAddressItemView.snp.makeConstraints { make in
            make.top.equalTo(inspirePointsItemView.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }
        
        dateOfBirthItemView.snp.makeConstraints { make in
            make.top.equalTo(emailAddressItemView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        // Cancel subscription button
        cancelSubscriptionButton.snp.makeConstraints { make in
            make.top.equalTo(fieldsContainerView.snp.bottom).offset(32)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalPadding)
            make.height.equalTo(48)
            make.bottom.equalToSuperview().offset(-24)
        }
    }
    
    /// 更新底部约束，根据按钮是否显示
    private func updateBottomConstraints(showButton: Bool) {
        cancelSubscriptionButton.isHidden = !showButton
        dateOfBirthItemView.hiddenLine(!showButton)
        if showButton {
            cancelSubscriptionButton.snp.updateConstraints { make in
                make.height.equalTo(48)
                make.bottom.equalToSuperview().offset(-24)
            }
        } else {
            cancelSubscriptionButton.snp.updateConstraints { make in
                make.height.equalTo(0)
                make.bottom.equalToSuperview().offset(10)
            }
        }
    }
    
    // MARK: - Styles
    
    private func configureDefaultContentAndStyles() {
        backgroundColor = UIColor.clear
        
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 1)
        containerView.layer.shadowRadius = 3
        containerView.layer.shadowOpacity = 0.1
    }
    
    // MARK: - Public Methods
    
    func updateWithData(_ data: LMUserModel) {
        profileData = data
        
        // Update header section
        nameLabel.text = (data.nickname?.isEmpty ?? true) ? "-" : data.nickname
        emailLabel.text = (data.email?.isEmpty ?? true) ? "-" : data.email
        avatarImageView.kf.setImage(
            with: URL(string: data.avatar ?? ""),
            placeholder: UIImage(systemName: "person.circle.fill")
        )
        
        // Update Profile Item Views
        nicknameItemView.updateContent(data.nickname ?? "-")
        usernameItemView.updateContent(data.username ?? "-")
        avatarItemView.updateContent("Profile Photo")
        emailAddressItemView.updateContent(data.email ?? "-")
        dateOfBirthItemView.updateContent(data.birthDate ?? "-")
        
        // Subscription 显示逻辑
        let subscriptionText = data.subscription ?? "-"
        if data.isPremiumUser {
            subscriptionItemView.configure(title: "Subscription", content: subscriptionText, type: .button)
        } else {
            subscriptionItemView.configure(title: "Subscription", content: subscriptionText, type: .text)
        }
        
        // Inspire Points 显示逻辑
        if data.isPremiumUser {
            inspirePointsItemView.updateContent("Unlimited")
        } else {
            inspirePointsItemView.updateContent("\(data.inspirePoints ?? 0)")
        }
        
        // 根据订阅状态显示/隐藏取消订阅按钮，并更新布局
        updateBottomConstraints(showButton: data.isPremiumUser)
    }
    
    // MARK: - Actions
    
    @objc private func cancelSubscriptionButtonTapped() {
        delegate?.profileDisplayViewDidTapCancelSubscription(self)
    }
    
    @objc private func startEditProfileDataButtonTapped() {
        delegate?.profileDisplayViewDidTapEditProfileData(self)
    }
}

// MARK: - LMProfileItemViewDelegate
extension LMProfileDisplayView: LMProfileItemViewDelegate {
    func profileItemViewDidTap(_ itemView: LMProfileItemView) {
        if itemView === subscriptionItemView {
            delegate?.profileDisplayViewDidTapSubscription(self)
        }
    }
}
