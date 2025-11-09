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
    private let displayView = LMProfileDisplayView()
    private let editView = LMProfileEditView()
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.profile.accountProfile
        setupCustomNavigationBar()
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        setupDelegates()
        updateViewsWithData()
        showDisplayView()
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: LMLaunageManager.languageDidChangeNotification,
            object: nil
        )
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Localization
    
    @objc private func languageDidChange() {
        updateTexts()
    }
    
    private func updateTexts() {
        barTitle = LMText.profile.accountProfile
        actionButton.setTitle(LMText.common.save, for: .normal)
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
        actionButton.setTitle(LMText.common.save, for: .normal)
        actionButton.contentMode = .right
        actionButton.frame = CGRect(origin: .zero,
                                    size: CGSize(width: 50,
                                                 height: 44))
        actionButton.setTitleColor(UIColor.systemBlue, for: .normal)
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        actionButton.addTarget(self, action: #selector(handleSaveButtonTapped), for: .touchUpInside)
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
        actionButton.isHidden = true
        
        // 确保布局更新
        DispatchQueue.main.async {
            self.view.layoutIfNeeded()
        }
    }
    
    private func showEditView() {
        isEditingMode = true
        displayView.isHidden = true
        editView.isHidden = false
        actionButton.isHidden = false
        
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
            title: LMText.profile.profileUpdated,
            message: LMText.profile.profileUpdatedMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LMText.common.ok, style: .default))
        present(alert, animated: true)
    }
}

// MARK: - ProfileDisplayViewDelegate
extension LMAccountProfilePage: ProfileDisplayViewDelegate {
    
    func profileDisplayViewDidTapCancelSubscription(_ view: LMProfileDisplayView) {
        showCancelSubscriptionAlert()
    }
    
    private func showCancelSubscriptionAlert() {
        let alert = UIAlertController(
            title: LMText.profile.cancelSubscriptionTitle,
            message: LMText.profile.cancelSubscriptionMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LMText.profile.keepSubscription, style: .cancel))
        alert.addAction(UIAlertAction(title: LMText.profile.cancelSubscription, style: .destructive) { _ in
            self.performSubscriptionCancellation()
        })
        
        present(alert, animated: true)
    }
    
    private func performSubscriptionCancellation() {
        // 更新数据
        userProfileData.subscriptionType = LMText.profile.freePlan
        userProfileData.inspirePoints = "3"
        
        // 更新视图
        updateViewsWithData()
        
        // 显示确认
        let alert = UIAlertController(
            title: LMText.profile.subscriptionCancelled,
            message: LMText.profile.subscriptionCancelledMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LMText.common.ok, style: .default))
        present(alert, animated: true)
    }
    
    func profileDisplayViewDidTapEditProfileData(_ view: LMProfileDisplayView) {
        showEditView()
    }
}

// MARK: - ProfileEditViewDelegate
extension LMAccountProfilePage: ProfileEditViewDelegate {
    
    func profileEditViewDidTapChangePhoto(_ view: LMProfileEditView) {
        showImagePicker()
    }
    
    func profileEditViewDidTapChangePassword(_ view: LMProfileEditView) {
        let changePasswordPage = LMForgotPasswordPage()
        navigationController?.pushViewController(changePasswordPage, animated: true)
    }
    
    private func showImagePicker() {
        let alert = UIAlertController(title: LMText.profile.changePhoto, message: "Choose a photo source", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: LMText.profile.camera, style: .default) { _ in
            // 实现相机功能
        })
        
        alert.addAction(UIAlertAction(title: LMText.profile.photoLibrary, style: .default) { _ in
            // 实现相册功能
        })
        
        alert.addAction(UIAlertAction(title: LMText.common.cancel, style: .cancel))
        
        // iPad支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        present(alert, animated: true)
    }
}
