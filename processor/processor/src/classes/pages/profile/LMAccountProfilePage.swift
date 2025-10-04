//
//  LMAccountProfilePage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

class LMAccountProfilePage: LMPageWrapper {
    
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    
    // 用户头部信息区域
    private let userHeaderView = UIView()
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let emailLabel = UILabel()
    private let editButton = UIButton()
    
    // 信息列表区域
    private let profileInfoTableView = UITableView()
    
    // 底部取消订阅按钮
    private let cancelSubscriptionButton = UIButton()
    
    private var userProfileData: LMUserProfileModel
    private var profileInfoItems: [LMProfileInfoItem] = []
    
    init(userProfileData: LMUserProfileModel = LMUserProfileModel.createDefault()) {
        self.userProfileData = userProfileData
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.userProfileData = LMUserProfileModel.createDefault()
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        setupProfileInfoItems()
        setupUserInteractionHandlers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        configureNavigationBarAppearance()
    }
}

struct LMProfileInfoItem {
    let title: String
    let value: String
    let isEditable: Bool
    let accessoryType: LMProfileInfoAccessoryType
    let identifier: String
    
    enum LMProfileInfoAccessoryType: Equatable {
        case none
        case disclosure
        case button(title: String, color: UIColor)
        case editableText
    }
}

// MARK: - User Interface Setup Methods
extension LMAccountProfilePage {
    
    private func setupUserInterfaceComponents() {
        setupScrollViewAndContentStack()
        setupUserHeaderComponents()
        setupProfileInfoTableView()
        setupCancelSubscriptionButton()
    }
    
    private func setupScrollViewAndContentStack() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        contentStackView.axis = .vertical
        contentStackView.spacing = 0
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        
        // 添加主要区域到堆栈视图
        contentStackView.addArrangedSubview(userHeaderView)
        contentStackView.addArrangedSubview(profileInfoTableView)
        contentStackView.addArrangedSubview(cancelSubscriptionButton)
    }
    
    private func setupUserHeaderComponents() {
        userHeaderView.addSubview(avatarImageView)
        userHeaderView.addSubview(nameLabel)
        userHeaderView.addSubview(emailLabel)
        userHeaderView.addSubview(editButton)
        
        // 头像设置
        avatarImageView.backgroundColor = UIColor.systemGray4
        avatarImageView.layer.cornerRadius = 40
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.image = userProfileData.avatarImage ?? UIImage(systemName: "person.circle.fill")
        avatarImageView.tintColor = UIColor.systemGray3
        
        // 姓名标签设置
        nameLabel.text = userProfileData.fullName
        nameLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        nameLabel.textColor = UIColor.label
        
        // 邮箱标签设置
        emailLabel.text = userProfileData.emailAddress
        emailLabel.font = UIFont.systemFont(ofSize: 16)
        emailLabel.textColor = UIColor.secondaryLabel
        
        // 编辑按钮设置
        editButton.setTitle("Edit", for: .normal)
        editButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        editButton.setTitleColor(UIColor.systemBlue, for: .normal)
        editButton.addTarget(self, action: #selector(handleEditButtonTapped), for: .touchUpInside)
    }
    
    private func setupProfileInfoTableView() {
        profileInfoTableView.delegate = self
        profileInfoTableView.dataSource = self
        profileInfoTableView.separatorStyle = .singleLine
        profileInfoTableView.separatorInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        profileInfoTableView.backgroundColor = UIColor.systemBackground
        profileInfoTableView.isScrollEnabled = false
        
        // 注册自定义cell
        profileInfoTableView.register(LMProfileInfoTableViewCell.self, forCellReuseIdentifier: "ProfileInfoCell")
    }
    
    private func setupCancelSubscriptionButton() {
        cancelSubscriptionButton.setTitle("❌ Cancel Subscription Plan", for: .normal)
        cancelSubscriptionButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelSubscriptionButton.setTitleColor(UIColor.systemRed, for: .normal)
        cancelSubscriptionButton.backgroundColor = UIColor.clear
        cancelSubscriptionButton.layer.borderWidth = 1
        cancelSubscriptionButton.layer.borderColor = UIColor.systemRed.cgColor
        cancelSubscriptionButton.layer.cornerRadius = 12
        cancelSubscriptionButton.addTarget(self, action: #selector(handleCancelSubscriptionButtonTapped), for: .touchUpInside)
        
        // 添加触摸反馈效果
        addTouchFeedbackEffectToButton(cancelSubscriptionButton)
    }
    
    private func addTouchFeedbackEffectToButton(_ button: UIButton) {
        button.addTarget(self, action: #selector(handleButtonTouchDownAnimation(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(handleButtonTouchUpAnimation(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
}

// MARK: - Layout Configuration Methods
extension LMAccountProfilePage {
    
    private func configureLayoutConstraints() {
        configureScrollViewConstraints()
        configureUserHeaderConstraints()
        configureProfileInfoTableViewConstraints()
        configureCancelSubscriptionButtonConstraints()
    }
    
    private func configureScrollViewConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }
    }
    
    private func configureUserHeaderConstraints() {
        userHeaderView.snp.makeConstraints { make in
            make.height.equalTo(140)
        }
        
        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.size.equalTo(80)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(16)
            make.top.equalTo(avatarImageView).offset(8)
            make.trailing.lessThanOrEqualTo(editButton.snp.leading).offset(-8)
        }
        
        emailLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.trailing.lessThanOrEqualTo(editButton.snp.leading).offset(-8)
        }
        
        editButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(nameLabel)
        }
    }
    
    private func configureProfileInfoTableViewConstraints() {
        profileInfoTableView.snp.makeConstraints { make in
            make.height.equalTo(400) // 根据实际行数调整
        }
    }
    
    private func configureCancelSubscriptionButtonConstraints() {
        cancelSubscriptionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(50)
            make.bottom.equalToSuperview().offset(-40)
        }
    }
}

// MARK: - Content Configuration Methods
extension LMAccountProfilePage {
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = AppTheme.ThemeColor.background
        
        // 设置滚动视图属性
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .automatic
    }
    
    private func configureNavigationBarAppearance() {
        navigationItem.title = "Account Profile"
        
        // 设置返回按钮
        let backButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.left"),
            style: .plain,
            target: self,
            action: #selector(handleNavigationBackButtonTapped)
        )
        backButton.tintColor = UIColor.label
        navigationItem.leftBarButtonItem = backButton
    }
    
    private func setupProfileInfoItems() {
        profileInfoItems = [
            LMProfileInfoItem(
                title: "Fullname",
                value: userProfileData.fullName,
                isEditable: true,
                accessoryType: .editableText,
                identifier: "fullname"
            ),
            LMProfileInfoItem(
                title: "Username",
                value: userProfileData.username,
                isEditable: true,
                accessoryType: .editableText,
                identifier: "username"
            ),
            LMProfileInfoItem(
                title: "Avatar",
                value: "Profile Photo",
                isEditable: true,
                accessoryType: .disclosure,
                identifier: "avatar"
            ),
            LMProfileInfoItem(
                title: "Subscription",
                value: userProfileData.subscriptionType,
                isEditable: false,
                accessoryType: .button(title: "Plus Plan", color: UIColor.systemBlue),
                identifier: "subscription"
            ),
            LMProfileInfoItem(
                title: "Inspire Points",
                value: userProfileData.inspirePoints,
                isEditable: false,
                accessoryType: .none,
                identifier: "inspirePoints"
            ),
            LMProfileInfoItem(
                title: "Email Address",
                value: userProfileData.emailAddress,
                isEditable: true,
                accessoryType: .editableText,
                identifier: "emailAddress"
            ),
            LMProfileInfoItem(
                title: "Date of Birth",
                value: userProfileData.dateOfBirth ?? "-",
                isEditable: true,
                accessoryType: .disclosure,
                identifier: "dateOfBirth"
            )
        ]
        
        profileInfoTableView.reloadData()
    }
    
    private func setupUserInteractionHandlers() {
        // 所有的交互处理器已在UI设置方法中配置
        print("User interaction handlers configured successfully")
    }
}

// MARK: - Table View Data Source Methods
extension LMAccountProfilePage: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return profileInfoItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileInfoCell", for: indexPath) as? LMProfileInfoTableViewCell else {
            return UITableViewCell()
        }
        
        let item = profileInfoItems[indexPath.row]
        cell.delegate = self
        cell.configureCell(with: item)
        
        return cell
    }
}

// MARK: - Table View Delegate Methods
extension LMAccountProfilePage: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let item = profileInfoItems[indexPath.row]
        
        if item.isEditable && item.accessoryType == .editableText {
            // 进入编辑模式
            if let cell = tableView.cellForRow(at: indexPath) as? LMProfileInfoTableViewCell {
                cell.enterEditingMode()
            }
        } else if item.accessoryType == .disclosure {
            handleDisclosureItemTapped(identifier: item.identifier)
        }
    }
}

// MARK: - Profile Info Cell Delegate Methods
extension LMAccountProfilePage: LMProfileInfoTableViewCellDelegate {
    
    func profileInfoCellDidTapAccessoryButton(_ cell: LMProfileInfoTableViewCell, identifier: String) {
        switch identifier {
        case "subscription":
            handleSubscriptionButtonTapped()
        default:
            break
        }
    }
    
    func profileInfoCellDidChangeText(_ cell: LMProfileInfoTableViewCell, identifier: String, newText: String) {
        // 更新数据模型，确保不影响其他数据
        updateUserProfileData(for: identifier, newValue: newText)
        
        // 刷新对应的数据项，而不是整个列表
        refreshSpecificProfileItem(identifier: identifier, newValue: newText)
    }
}

// MARK: - User Interaction Handler Methods
extension LMAccountProfilePage {
    
    @objc private func handleNavigationBackButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func handleEditButtonTapped() {
        print("Edit button tapped")
        presentUserProfileEditingViewController()
    }
    
    @objc private func handleCancelSubscriptionButtonTapped() {
        print("Cancel subscription button tapped")
        presentCancelSubscriptionConfirmationAlert()
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
    
    private func handleDisclosureItemTapped(identifier: String) {
        switch identifier {
        case "avatar":
            presentAvatarSelectionViewController()
        case "dateOfBirth":
            presentDateOfBirthPickerViewController()
        default:
            break
        }
    }
    
    private func handleSubscriptionButtonTapped() {
        print("Subscription button tapped")
        presentSubscriptionManagementViewController()
    }
}

// MARK: - Data Management Methods
extension LMAccountProfilePage {
    
    private func updateUserProfileData(for identifier: String, newValue: String) {
        // 创建新的数据副本，避免直接修改影响其他引用
        var updatedData = userProfileData
        
        switch identifier {
        case "fullname":
            updatedData.fullName = newValue
        case "username":
            updatedData.username = newValue
        case "emailAddress":
            updatedData.emailAddress = newValue
        case "dateOfBirth":
            updatedData.dateOfBirth = newValue.isEmpty ? nil : newValue
        default:
            break
        }
        
        // 更新数据模型
        userProfileData = updatedData
        
        // 更新UI中相关的显示
        updateUserHeaderDisplay()
    }
    
    private func refreshSpecificProfileItem(identifier: String, newValue: String) {
        // 找到对应的数据项并更新
        if let index = profileInfoItems.firstIndex(where: { $0.identifier == identifier }) {
            var updatedItem = profileInfoItems[index]
            
            // 创建新的数据项
            profileInfoItems[index] = LMProfileInfoItem(
                title: updatedItem.title,
                value: newValue,
                isEditable: updatedItem.isEditable,
                accessoryType: updatedItem.accessoryType,
                identifier: updatedItem.identifier
            )
            
            // 只刷新特定的行，而不是整个表格
            let indexPath = IndexPath(row: index, section: 0)
            profileInfoTableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    
    private func updateUserHeaderDisplay() {
        // 更新头部显示的用户信息
        nameLabel.text = userProfileData.fullName
        emailLabel.text = userProfileData.emailAddress
        
        // 如果有头像更新，也在这里处理
        if let avatarImage = userProfileData.avatarImage {
            avatarImageView.image = avatarImage
        }
    }
}

// MARK: - Navigation and Presentation Methods
extension LMAccountProfilePage {
    
    private func presentUserProfileEditingViewController() {
        let editVC = createUserProfileEditingViewController()
        present(editVC, animated: true)
    }
    
    private func presentAvatarSelectionViewController() {
        let avatarVC = createAvatarSelectionViewController()
        present(avatarVC, animated: true)
    }
    
    private func presentDateOfBirthPickerViewController() {
        let datePickerVC = createDateOfBirthPickerViewController()
        present(datePickerVC, animated: true)
    }
    
    private func presentSubscriptionManagementViewController() {
        let subscriptionVC = createSubscriptionManagementViewController()
        navigationController?.pushViewController(subscriptionVC, animated: true)
    }
    
    private func presentCancelSubscriptionConfirmationAlert() {
        let alertController = UIAlertController(
            title: "Cancel Subscription",
            message: "Are you sure you want to cancel your subscription? You will lose access to premium features.",
            preferredStyle: .alert
        )
        
        let cancelAction = UIAlertAction(title: "Keep Subscription", style: .cancel)
        let confirmAction = UIAlertAction(title: "Cancel Subscription", style: .destructive) { _ in
            self.performSubscriptionCancellation()
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(confirmAction)
        
        present(alertController, animated: true)
    }
    
    private func performSubscriptionCancellation() {
        // 模拟取消订阅的网络请求
        print("Performing subscription cancellation...")
        
        // 更新订阅状态
        updateSubscriptionStatus(to: "Free Plan")
        
        // 显示确认消息
        showSubscriptionCancellationConfirmation()
    }
    
    private func updateSubscriptionStatus(to newStatus: String) {
        // 更新数据模型
        userProfileData.subscriptionType = newStatus
        userProfileData.inspirePoints = newStatus == "Free Plan" ? "3" : "Unlimited"
        
        // 刷新相关的表格行
        refreshSpecificProfileItem(identifier: "subscription", newValue: newStatus)
        refreshSpecificProfileItem(identifier: "inspirePoints", newValue: userProfileData.inspirePoints)
    }
    
    private func showSubscriptionCancellationConfirmation() {
        let alertController = UIAlertController(
            title: "Subscription Cancelled",
            message: "Your subscription has been cancelled successfully. You can continue using the app with limited features.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
}

// MARK: - View Controller Factory Methods
extension LMAccountProfilePage {
    
    private func createUserProfileEditingViewController() -> UIViewController {
        let editVC = UIViewController()
        editVC.view.backgroundColor = UIColor.systemBackground
        editVC.title = "Edit Profile"
        return editVC
    }
    
    private func createAvatarSelectionViewController() -> UIViewController {
        let avatarVC = UIViewController()
        avatarVC.view.backgroundColor = UIColor.systemBackground
        avatarVC.title = "Select Avatar"
        return avatarVC
    }
    
    private func createDateOfBirthPickerViewController() -> UIViewController {
        let datePickerVC = UIViewController()
        datePickerVC.view.backgroundColor = UIColor.systemBackground
        datePickerVC.title = "Date of Birth"
        return datePickerVC
    }
    
    private func createSubscriptionManagementViewController() -> UIViewController {
        let subscriptionVC = UIViewController()
        subscriptionVC.view.backgroundColor = UIColor.systemBackground
        subscriptionVC.title = "Subscription Management"
        return subscriptionVC
    }
}

// MARK: - Public Configuration Methods
extension LMAccountProfilePage {
    
    func updateUserProfileData(_ newData: LMUserProfileModel) {
        // 安全地更新用户数据，确保不影响其他数据
        guard newData.userId == userProfileData.userId else {
            print("Warning: Attempting to update profile with different user ID")
            return
        }
        
        userProfileData = newData
        updateUserHeaderDisplay()
        setupProfileInfoItems() // 重新设置数据项
    }
    
    func getCurrentUserProfileData() -> LMUserProfileModel {
        return userProfileData
    }
    
    func refreshProfileData() {
        // 刷新个人资料数据，可以从服务器获取最新数据
        setupProfileInfoItems()
        updateUserHeaderDisplay()
    }
}
