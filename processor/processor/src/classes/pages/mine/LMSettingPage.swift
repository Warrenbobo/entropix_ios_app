//
//  LMSettingPage.swift
//  processor
//
//  Created by muz on 2025/10/6.
//

import UIKit
import SnapKit

class LMSettingPage: LMPageWrapper {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Setting Items
    private let accountProfileItem = LMSettingItemView()
    private let notificationItem = LMSettingItemView()
    private let languageItem = LMSettingItemView()
    private let contactUsItem = LMSettingItemView()
    private let frequentQuestionsItem = LMSettingItemView()
    private let aboutItem = LMSettingItemView()
    
    // Logout Button
    private let logoutButton = UIButton(type: .custom)
    
    private var isUserLoggedIn: Bool {
        return false // 暂时隐藏退出登录按钮
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.settings
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        updateUIForLoginState()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false,
                                                     animated: true)
        updateUIForLoginState()
    }
}

// MARK: - Setup Methods
extension LMSettingPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(accountProfileItem)
        contentView.addSubview(notificationItem)
        contentView.addSubview(languageItem)
        contentView.addSubview(contactUsItem)
        contentView.addSubview(frequentQuestionsItem)
        contentView.addSubview(aboutItem)
        contentView.addSubview(logoutButton)
        
        setupSettingItems()
        setupLogoutButton()
    }
    
    private func setupSettingItems() {
        // Account Profile
        accountProfileItem.configure(
            icon: UIImage(named: "user_solid_blue"),
            iconBackgroundColor: .hexColor("#DBE9FE"),
            title: LMText.settings.accountProfile,
            subtitle: LMText.settings.accountProfileSubtitle,
            showArrow: true
        )
        accountProfileItem.onTap = { [weak self] in
            self?.handleAccountProfileTapped()
        }
        
        // Notification
        notificationItem.configure(
            icon: UIImage(named: "bullhorn_yellow"),
            iconBackgroundColor: .hexColor("#FEF9C2"),
            title: LMText.settings.notifications,
            subtitle: LMText.settings.notificationSubtitle,
            showArrow: true
        )
        notificationItem.onTap = { [weak self] in
            self?.handleNotificationTapped()
        }
        
        // Language
        languageItem.configure(
            icon: UIImage(named: "globe_purple"),
            iconBackgroundColor: .hexColor("F3E8FF"),
            title: LMText.settings.language,
            subtitle: LMText.settings.languageSubtitle,
            showArrow: true
        )
        languageItem.onTap = { [weak self] in
            self?.handleLanguageTapped()
        }
        
        // Contact Us
        contactUsItem.configure(
            icon: UIImage(named: "envelope_orange"),
            iconBackgroundColor: .hexColor("#FFECD5"),
            title: LMText.settings.contactUs,
            subtitle: LMText.settings.contactUsSubtitle,
            showArrow: true
        )
        contactUsItem.onTap = { [weak self] in
            self?.handleContactUsTapped()
        }
        
        // Frequent Questions
        frequentQuestionsItem.configure(
            icon: UIImage(named: "question_circle_indigo"),
            iconBackgroundColor: .hexColor("#E0E7FF"),
            title: LMText.settings.frequentQuestions,
            subtitle: LMText.settings.frequentQuestionsSubtitle,
            showArrow: true
        )
        frequentQuestionsItem.onTap = { [weak self] in
            self?.handleFrequentQuestionsTapped()
        }
        
        // About
        aboutItem.configure(
            icon: UIImage(named: "info_circle_green"),
            iconBackgroundColor: .hexColor("#DCFCE8"),
            title: LMText.settings.about,
            subtitle: LMText.settings.aboutSubtitle,
            showArrow: true
        )
        aboutItem.onTap = { [weak self] in
            self?.handleAboutTapped()
        }
    }
    
    private func setupLogoutButton() {
        logoutButton.setTitleColor(.white, for: .normal)
        logoutButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        logoutButton.backgroundColor = UIColor.systemRed
        logoutButton.layer.cornerRadius = 12
        logoutButton.addTarget(self, action: #selector(handleLogoutButtonTapped), for: .touchUpInside)
        logoutButton.adjust(image: UIImage(named: "sign_out_white"),
                            title: LMText.auth.logOut,
                            titlePosition: .right,
                            additionalSpacing: 5,
                            state: .normal)
    }
}

// MARK: - Layout Configuration
extension LMSettingPage {
    
    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        accountProfileItem.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        notificationItem.snp.makeConstraints { make in
            make.top.equalTo(accountProfileItem.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        languageItem.snp.makeConstraints { make in
            make.top.equalTo(notificationItem.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        contactUsItem.snp.makeConstraints { make in
            make.top.equalTo(languageItem.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        frequentQuestionsItem.snp.makeConstraints { make in
            make.top.equalTo(contactUsItem.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        aboutItem.snp.makeConstraints { make in
            make.top.equalTo(frequentQuestionsItem.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        logoutButton.snp.makeConstraints { make in
            make.top.equalTo(aboutItem.snp.bottom).offset(40)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(50)
            make.bottom.equalToSuperview().offset(-40)
        }
    }
}

// MARK: - Style Configuration
extension LMSettingPage {
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = UIColor.systemBackground
        scrollView.backgroundColor = UIColor.clear
        scrollView.showsVerticalScrollIndicator = false
    }
    
    private func updateUIForLoginState() {
        logoutButton.isHidden = !isUserLoggedIn
        
        // 如果未登录，需要更新布局约束
        if !isUserLoggedIn {
            aboutItem.snp.remakeConstraints { make in
                make.top.equalTo(frequentQuestionsItem.snp.bottom).offset(16)
                make.leading.trailing.equalToSuperview().inset(16)
                make.bottom.equalToSuperview().offset(-40)
            }
        }
    }
}

// MARK: - Action Handlers
extension LMSettingPage {
    
    @objc private func handleBackButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func handleLogoutButtonTapped() {
        showLogoutConfirmation()
    }
    
    private func handleAccountProfileTapped() {
        // 检查登录状态
        guard requireLogin(action: "view account profile") else {
            return
        }
        
        // 导航到账户资料页面
        let accountProfilePage = LMAccountProfilePage()
        navigationController?.pushViewController(accountProfilePage, animated: true)
    }
    
    private func handleNotificationTapped() {
        // 检查登录状态
        guard requireLogin(action: "view notifications") else {
            return
        }
        
        // 导航到通知设置页面
        let notifications = LMNotificationsPage()
        navigationController?.pushViewController(notifications,
                                                 animated: true)
    }
    
    private func handleLanguageTapped() {
        let language = LMLanguagePage()
        navigationController?.pushViewController(language,
                                                 animated: true)
    }
    
    private func handleContactUsTapped() {
        let contactUs = LMContactUsPage()
        navigationController?.pushViewController(contactUs,
                                                 animated: true)
    }
    
    private func handleFrequentQuestionsTapped() {
        // 导航到常见问题页面
        let faq = LMFAQPage()
        navigationController?.pushViewController(faq,
                                                 animated: true)
    }
    
    private func handleAboutTapped() {
        // 导航到关于页面
        let aboutPage = LMAboutPage()
        navigationController?.pushViewController(aboutPage,
                                                 animated: true)
    }
}

// MARK: - Helper Methods
extension LMSettingPage {
    
    private func showLogoutConfirmation() {
        LMAlertDialog.showAlert(
            title: LMText.auth.logOut,
            message: LMText.settings.areYouSureLogout,
            cancelText: LMText.common.cancel,
            confirmText: LMText.auth.logOut,
            confirmStyle: .destructive,
            onConfirm: { [weak self] in
                self?.performLogout()
            }
        )
    }
    
    private func performLogout() {
        // 执行登出逻辑
        // 这里应该清除用户数据、token等
        LMUserManager.shared.clearLoginInfo()
        
        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // 导航回登录页面或主页
            self.navigateToLoginPage()
        }
    }
    
    private func navigateToLoginPage() {
        // 导航到登录页面
        let installer = LMNewInstallerPage()
        let navController = LMNavigationWrapper(rootViewController: installer)
        if let window = AppTheme.Screen.window() {
            window.rootViewController = navController
        }
    }
    
    private func showComingSoonAlert(for feature: String) {
        LMAlertDialog.showGeneralAlert(String(format: LMText.settings.comingSoonMessage, feature),
                                       title: LMText.settings.comingSoon,
                                       onConfirm: {})
    }
}

// MARK: - Setting Item View
class LMSettingItemView: UIView {
    
    private let containerView = UIView()
    private let iconContainerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let arrowImageView = UIImageView()
    
    var onTap: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUserInterface()
        setupLayout()
        setupStyles()
        setupGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUserInterface() {
        addSubview(containerView)
        containerView.addSubview(iconContainerView)
        iconContainerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(subtitleLabel)
        containerView.addSubview(arrowImageView)
    }
    
    private func setupLayout() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.greaterThanOrEqualTo(70)
        }
        
        iconContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(40)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(20)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconContainerView.snp.trailing).offset(16)
            make.top.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualTo(arrowImageView.snp.leading).offset(-16)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.trailing.lessThanOrEqualTo(arrowImageView.snp.leading).offset(-16)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
    }
    
    private func setupStyles() {
        backgroundColor = UIColor.systemBackground
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 3
        layer.shadowOpacity = 0.1
        
        iconContainerView.layer.cornerRadius = 8
        
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 1
        
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIColor.systemGray
        subtitleLabel.numberOfLines = 2
        
        arrowImageView.image = UIImage(systemName: "chevron.right")
        arrowImageView.tintColor = UIColor.systemGray3
        arrowImageView.contentMode = .scaleAspectFit
    }
    
    private func setupGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
    }
    
    @objc private func handleTap() {
        // 添加点击动画
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = CGAffineTransform.identity
            }
        }
        
        onTap?()
    }
    
    func configure(icon: UIImage?, iconBackgroundColor: UIColor, title: String, subtitle: String, showArrow: Bool = true) {
        iconImageView.image = icon
        iconContainerView.backgroundColor = iconBackgroundColor
        titleLabel.text = title
        subtitleLabel.text = subtitle
        arrowImageView.isHidden = !showArrow
    }
}
