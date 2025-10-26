//
//  LMAccountProfilePage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

// MARK: - User Profile Data Model
struct UserProfileData {
    var fullName: String
    var username: String
    var emailAddress: String
    var avatarImage: UIImage?
    var subscriptionType: String
    var inspirePoints: String
    var dateOfBirth: String?
    
    static func createDefault() -> UserProfileData {
        return UserProfileData(
            fullName: "Alex Johnson",
            username: "alex.j@email.com",
            emailAddress: "alex.j@email.com",
            avatarImage: nil,
            subscriptionType: "Plus Plan",
            inspirePoints: "Unlimited",
            dateOfBirth: nil
        )
    }
}

class LMAccountProfilePage: LMPageWrapper {
    
    // MARK: - Properties
    private var userProfileData = UserProfileData.createDefault()
    private var isEditingMode = false
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Custom Navigation Bar Right
    private let actionButton = UIButton()
    
    // View State Views
    private let displayView = ProfileDisplayView()
    private let editView = ProfileEditView()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = "Account Profile"
        setupCustomNavigationBar()
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        setupDelegates()
        updateViewsWithData()
        showDisplayView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        // 添加键盘通知监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 移除键盘通知监听
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard isEditingMode,
              let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
        
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset = contentInsets
            self.scrollView.scrollIndicatorInsets = contentInsets
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset = .zero
            self.scrollView.scrollIndicatorInsets = .zero
        }
    }
}

// MARK: - Setup Methods
extension LMAccountProfilePage {
    
    private func setupCustomNavigationBar() {
        actionButton.setTitle("Edit", for: .normal)
        actionButton.contentMode = .right
        actionButton.frame = CGRect(origin: .zero,
                                    size: CGSize(width: 50,
                                                 height: 44))
        actionButton.setTitleColor(UIColor.systemBlue, for: .normal)
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        actionButton.addTarget(self, action: #selector(handleActionButtonTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: actionButton)
    }
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(displayView)
        contentView.addSubview(editView)
        
        // 初始状态隐藏编辑视图
        editView.isHidden = true
    }
    
    private func setupDelegates() {
        displayView.delegate = self
        editView.delegate = self
    }

    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(AppTheme.Screen.navigatorHeight)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        displayView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.medium)
        }
        
        editView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.medium)
        }
    }
    
    private func configureDefaultContentAndStyles() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
    }

    private func updateViewsWithData() {
        displayView.updateWithData(userProfileData)
        editView.updateWithData(userProfileData)
    }
    
    private func showDisplayView() {
        isEditingMode = false
        displayView.isHidden = false
        editView.isHidden = true
        
        // Update navigation
        actionButton.setTitle("Edit", for: .normal)
        
        // 确保布局更新
        DispatchQueue.main.async {
            self.view.layoutIfNeeded()
        }
    }
    
    private func showEditView() {
        isEditingMode = true
        displayView.isHidden = true
        editView.isHidden = false
        
        // Update navigation
        actionButton.setTitle("Save", for: .normal)
        
        // 确保布局更新并滚动到顶部
        DispatchQueue.main.async {
            self.view.layoutIfNeeded()
            self.scrollView.setContentOffset(.zero, animated: true)
        }
    }
}

// MARK: - Action Handlers
extension LMAccountProfilePage {
    
    @objc private func handleBackButtonTapped() {
        if isEditingMode {
            // 如果在编辑模式，返回到显示模式
            showDisplayView()
        } else {
            // 如果在显示模式，返回上一页
            navigationController?.popViewController(animated: true)
        }
    }
    
    @objc private func handleActionButtonTapped() {
        if isEditingMode {
            handleSaveButtonTapped()
        } else {
            showEditView()
        }
    }
    
    @objc private func handleSaveButtonTapped() {
        // 获取编辑视图的数据
        let updatedData = editView.getCurrentData()
        
        // 更新数据模型
        userProfileData = updatedData
        
        // 更新显示视图
        displayView.updateWithData(userProfileData)
        
        // 返回显示模式
        showDisplayView()
        
        // 显示保存成功提示
        showSaveSuccessAlert()
    }
    
    private func showSaveSuccessAlert() {
        let alert = UIAlertController(
            title: "Profile Updated",
            message: "Your profile has been updated successfully.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ProfileDisplayViewDelegate
extension LMAccountProfilePage: ProfileDisplayViewDelegate {
    
    func profileDisplayViewDidTapCancelSubscription(_ view: ProfileDisplayView) {
        showCancelSubscriptionAlert()
    }
    
    private func showCancelSubscriptionAlert() {
        let alert = UIAlertController(
            title: "Cancel Subscription",
            message: "Are you sure you want to cancel your subscription? You will lose access to premium features.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Keep Subscription", style: .cancel))
        alert.addAction(UIAlertAction(title: "Cancel Subscription", style: .destructive) { _ in
            self.performSubscriptionCancellation()
        })
        
        present(alert, animated: true)
    }
    
    private func performSubscriptionCancellation() {
        // 更新数据
        userProfileData.subscriptionType = "Free Plan"
        userProfileData.inspirePoints = "3"
        
        // 更新视图
        updateViewsWithData()
        
        // 显示确认
        let alert = UIAlertController(
            title: "Subscription Cancelled",
            message: "Your subscription has been cancelled successfully.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ProfileEditViewDelegate
extension LMAccountProfilePage: ProfileEditViewDelegate {
    
    func profileEditViewDidTapChangePhoto(_ view: ProfileEditView) {
        showImagePicker()
    }
    
    func profileEditViewDidTapChangePassword(_ view: ProfileEditView) {
        let changePasswordPage = LMForgotPasswordPage()
        navigationController?.pushViewController(changePasswordPage, animated: true)
    }
    
    private func showImagePicker() {
        let alert = UIAlertController(title: "Change Photo", message: "Choose a photo source", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Camera", style: .default) { _ in
            // 实现相机功能
        })
        
        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { _ in
            // 实现相册功能
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        present(alert, animated: true)
    }
}

// MARK: - ProfileDisplayView
protocol ProfileDisplayViewDelegate: AnyObject {
    func profileDisplayViewDidTapCancelSubscription(_ view: ProfileDisplayView)
}

class ProfileDisplayView: UIView {
    
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
        cancelSubscriptionButton.setTitle("Cancel Subscription", for: .normal)
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
}

// MARK: - ProfileEditView
protocol ProfileEditViewDelegate: AnyObject {
    func profileEditViewDidTapChangePhoto(_ view: ProfileEditView)
    func profileEditViewDidTapChangePassword(_ view: ProfileEditView)
}

class ProfileEditView: UIView {
    
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
        
        changePhotoButton.setTitle("Change Photo", for: .normal)
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
