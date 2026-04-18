//
//  LMSettingPage.swift
//  processor
//
//  Created by muz on 2025/10/6.
//

import UIKit
import SnapKit

class LMSettingPage: LMPageWrapper {
    
    override var usesMineNavigationBarStyle: Bool { true }
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let itemsContainerView = UIView()
    private let itemsStackView = UIStackView()
    
    // Setting Items
    private let accountProfileItem = LMSettingItemView()
    private let languageItem = LMSettingItemView()
    private let contactUsItem = LMSettingItemView()
    private let frequentQuestionsItem = LMSettingItemView()
    private let aboutItem = LMSettingItemView()
    private let deleteAccountItem = LMSettingItemView()
    
    // Logout Button
    private let logoutButton = UIButton(type: .custom)

    private var isUserLoggedIn: Bool {
        return false // 暂时隐藏退出登录按钮
    }
    
    private var isInReviewMode: Bool {
        LMPackageManager.reviewState == .inReview
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.settings
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        updateUIForLoginState()
        updateUIForReviewState()
    }

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true,
                                                     animated: true)
        updateUIForLoginState()
        updateUIForReviewState()
        refreshAppUpdateIndicator()
    }
}

// MARK: - Setup Methods
extension LMSettingPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(itemsContainerView)
        itemsContainerView.addSubview(itemsStackView)
        itemsStackView.addArrangedSubview(accountProfileItem)
        itemsStackView.addArrangedSubview(languageItem)
        itemsStackView.addArrangedSubview(contactUsItem)
        itemsStackView.addArrangedSubview(frequentQuestionsItem)
        itemsStackView.addArrangedSubview(aboutItem)
        itemsStackView.addArrangedSubview(deleteAccountItem)
        
        contentView.addSubview(logoutButton)
        
        setupItemsStackView()
        setupSettingItems()
        setupLogoutButton()
    }
    
    private func setupItemsStackView() {
        itemsStackView.axis = .vertical
        itemsStackView.spacing = 0
        itemsStackView.distribution = .fill
        itemsStackView.alignment = .fill
    }
    
    private func setupSettingItems() {
        // Account Profile
        accountProfileItem.configure(
            icon: UIImage(named: "user_solid_blue"),
            iconBackgroundColor: .hexColor("#DBEAFE"),
            title: LMText.settings.accountProfile,
            subtitle: LMText.settings.accountProfileSubtitle,
            showArrow: true
        )
        accountProfileItem.onTap = { [weak self] in
            self?.handleAccountProfileTapped()
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
        
        // Delete Account
        deleteAccountItem.configure(
            icon: UIImage(named: "trash_white"),
            iconBackgroundColor: UIColor.systemRed,
            title: LMText.settings.deleteAccount,
            subtitle: LMText.settings.deleteAccountSubtitle,
            showArrow: true
        )
        deleteAccountItem.onTap = { [weak self] in
            self?.handleDeleteAccountTapped()
        }
        
        updateItemSeparators()
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
        
        itemsContainerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        itemsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: - Style Configuration
extension LMSettingPage {
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = .white
        scrollView.backgroundColor = .white
        scrollView.showsVerticalScrollIndicator = false
        contentView.backgroundColor = .white
        
        itemsContainerView.backgroundColor = .white
        itemsContainerView.layer.cornerRadius = 0
        itemsContainerView.layer.masksToBounds = false
    }
    
    private func updateUIForLoginState() {
        logoutButton.isHidden = !isUserLoggedIn
        
        // 如果未登录，需要更新布局约束
        if !isUserLoggedIn {
            logoutButton.snp.remakeConstraints { make in
                make.top.equalTo(itemsStackView.snp.bottom)
                make.leading.trailing.equalToSuperview().inset(16)
                make.height.equalTo(0)
                make.bottom.equalToSuperview().offset(-40)
            }
        } else {
            logoutButton.snp.remakeConstraints { make in
                make.top.equalTo(itemsStackView.snp.bottom).offset(40)
                make.leading.trailing.equalToSuperview().inset(16)
                make.height.equalTo(50)
                make.bottom.equalToSuperview().offset(-40)
            }
        }
    }
    
    private func updateUIForReviewState() {
        deleteAccountItem.isHidden = !isInReviewMode
        updateItemSeparators()
    }
}

extension LMSettingPage {
    
    private var orderedSettingItems: [LMSettingItemView] {
        [
            accountProfileItem,
            languageItem,
            contactUsItem,
            frequentQuestionsItem,
            aboutItem,
            deleteAccountItem
        ]
    }
    
    private func updateItemSeparators() {
        let visibleItems = orderedSettingItems.filter { !$0.isHidden }
        orderedSettingItems.forEach { item in
            item.setSeparatorHidden(true)
        }
        visibleItems.enumerated().forEach { index, item in
            item.setSeparatorHidden(index == visibleItems.count - 1)
        }
    }
}

extension LMSettingPage {
    
    private func refreshAppUpdateIndicator() {
        aboutItem.setBadgeVisible(LMPackageManager.hasAvailableAppUpdate)
        LMPackageManager.refreshAppUpdateStatus { [weak self] hasUpdate in
            DispatchQueue.main.async {
                self?.aboutItem.setBadgeVisible(hasUpdate)
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
        guard requireLogin(action: "view account profile") else {
            return
        }
        
        let profilePage = LMAccountProfilePage()
        navigationController?.pushViewController(profilePage, animated: true)
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
    
    private func handleDeleteAccountTapped() {
        guard requireLogin(action: "delete account") else {
            return
        }
        
        let deletePage = LMDeleteAccountPage()
        navigationController?.pushViewController(deletePage, animated: true)
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
        // 当前版本已废弃旧登录引导页，登出后回到启动流程并重新建立 guest 会话
        let launchSplash = LMLaunchSplashPage()
        let navController = LMNavigationWrapper(rootViewController: launchSplash)
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

// MARK: - Delete Account Page
class LMDeleteAccountPage: LMPageWrapper {
    
    override var usesMineNavigationBarStyle: Bool { true }
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let reasonsStackView = UIStackView()
    private let noticeLabel = UILabel()
    private let buttonStackView = UIStackView()
    private let cancelButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)
    
    private var reasonViews: [LMDeleteAccountReasonView] = []
    private var selectedReasonIndex: Int?
    private var countdownTimer: Timer?
    private var countdownRemaining = 10
    private var isRequesting = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.deleteAccount
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        startCountdown()
        updateConfirmButtonState()
    }
    
    deinit {
        invalidateCountdown()
    }
}

// MARK: - Setup Methods
extension LMDeleteAccountPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(reasonsStackView)
        contentView.addSubview(noticeLabel)
        contentView.addSubview(buttonStackView)
        
        titleLabel.text = LMText.settings.deleteAccountReasonTitle
        subtitleLabel.text = LMText.settings.deleteAccountReasonSubtitle
        
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 0
        
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIColor.systemGray
        subtitleLabel.numberOfLines = 0

        noticeLabel.text = LMText.settings.deleteAccountNotice
        noticeLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        noticeLabel.textColor = UIColor.systemGray2
        noticeLabel.numberOfLines = 0
        
        reasonsStackView.axis = .vertical
        reasonsStackView.spacing = 12
        reasonsStackView.distribution = .fill
        
        let reasons = [
            (LMText.settings.deleteAccountReasonFeatureTitle, LMText.settings.deleteAccountReasonFeatureDetail),
            (LMText.settings.deleteAccountReasonUsageTitle, LMText.settings.deleteAccountReasonUsageDetail),
            (LMText.settings.deleteAccountReasonStopTitle, LMText.settings.deleteAccountReasonStopDetail),
            (LMText.settings.deleteAccountReasonSecurityTitle, LMText.settings.deleteAccountReasonSecurityDetail)
        ]
        
        for (index, reason) in reasons.enumerated() {
            let view = LMDeleteAccountReasonView(title: reason.0, detail: reason.1)
            view.onSelect = { [weak self] in
                self?.selectReason(at: index)
            }
            reasonViews.append(view)
            reasonsStackView.addArrangedSubview(view)
        }
        
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = 12
        buttonStackView.distribution = .fillEqually
        
        cancelButton.setTitle(LMText.common.cancel, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        cancelButton.setTitleColor(UIColor.label, for: .normal)
        cancelButton.backgroundColor = UIColor.systemGray5
        cancelButton.layer.cornerRadius = 12
        cancelButton.addTarget(self, action: #selector(handleCancelTapped), for: .touchUpInside)
        
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        confirmButton.layer.cornerRadius = 12
        confirmButton.addTarget(self, action: #selector(handleConfirmTapped), for: .touchUpInside)
        
        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(confirmButton)
    }
    
    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        reasonsStackView.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        noticeLabel.snp.makeConstraints { make in
            make.top.equalTo(reasonsStackView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        buttonStackView.snp.makeConstraints { make in
            make.top.equalTo(noticeLabel.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(50)
            make.bottom.equalToSuperview().offset(-24)
        }
    }
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = UIColor.systemBackground
        scrollView.showsVerticalScrollIndicator = false
    }
}

// MARK: - Actions
extension LMDeleteAccountPage {
    
    @objc private func handleCancelTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func handleConfirmTapped() {
        guard isConfirmEnabled(), !isRequesting else { return }
        guard let selectedReasonIndex = selectedReasonIndex else { return }
        isRequesting = true
        updateConfirmButtonState()
        
        let reasonValue = selectedReasonIndex + 1
        AppTheme.Toast.showLoading()
        LMApiService.shared.deleteAccount(reason: reasonValue) { _ in
            AppTheme.Toast.hideLoading()
            self.isRequesting = false
            self.updateConfirmButtonState()
            self.showRequestReceivedDialog()
        }
    }
}

// MARK: - Private Helpers
extension LMDeleteAccountPage {
    
    private func selectReason(at index: Int) {
        selectedReasonIndex = index
        for (idx, view) in reasonViews.enumerated() {
            view.isSelectedOption = (idx == index)
        }
        updateConfirmButtonState()
    }
    
    private func startCountdown() {
        invalidateCountdown()
        countdownRemaining = 10
        updateConfirmTitleForCountdown()
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.countdownRemaining -= 1
            if self.countdownRemaining <= 0 {
                timer.invalidate()
                self.setConfirmButtonTitle(LMText.settings.deleteAccountConfirm)
                self.updateConfirmButtonState()
            } else {
                self.updateConfirmTitleForCountdown()
            }
        }
    }
    
    private func invalidateCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func updateConfirmTitleForCountdown() {
        let title = String(format: LMText.settings.deleteAccountConfirmCountdownFormat,
                           countdownRemaining)
        setConfirmButtonTitle(title)
        updateConfirmButtonState()
    }
    
    private func setConfirmButtonTitle(_ title: String) {
        UIView.performWithoutAnimation {
            confirmButton.setTitle(title, for: .normal)
            confirmButton.layoutIfNeeded()
        }
    }
    
    private func isConfirmEnabled() -> Bool {
        return countdownRemaining <= 0 && selectedReasonIndex != nil
    }
    
    private func updateConfirmButtonState() {
        let enabled = isConfirmEnabled() && !isRequesting
        confirmButton.isEnabled = enabled
        confirmButton.isUserInteractionEnabled = enabled
        confirmButton.backgroundColor = enabled ? UIColor.systemRed : UIColor.systemGray4
        confirmButton.setTitleColor(enabled ? UIColor.white : UIColor.systemGray, for: .normal)
    }
    
    private func showRequestReceivedDialog() {
        LMAlertDialog.showAlert(
            title: LMText.settings.deleteAccountRequestReceivedTitle,
            message: LMText.settings.deleteAccountRequestReceivedMessage,
            cancelText: nil,
            confirmText: LMText.settings.deleteAccountRequestReceivedConfirm,
            confirmStyle: .normal,
            onConfirm: {
                self.navigationController?.popToRootViewController(animated: true)
            }
        )
    }
}

// MARK: - Reason Option View
private class LMDeleteAccountReasonView: UIControl {
    
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let indicatorOuterView = UIView()
    private let indicatorInnerView = UIView()
    
    var onSelect: (() -> Void)?
    
    var isSelectedOption: Bool = false {
        didSet {
            updateStyle()
        }
    }
    
    init(title: String, detail: String) {
        super.init(frame: .zero)
        setupUI()
        configure(title: title, detail: detail)
        updateStyle()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        layer.cornerRadius = 12
        layer.borderWidth = 1
        backgroundColor = UIColor.systemBackground
        
        indicatorOuterView.layer.cornerRadius = 10
        indicatorOuterView.layer.borderWidth = 2
        indicatorOuterView.layer.borderColor = UIColor.systemGray3.cgColor
        indicatorOuterView.backgroundColor = UIColor.clear
        
        indicatorInnerView.layer.cornerRadius = 5
        indicatorInnerView.backgroundColor = UIColor.systemBlue
        
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 0
        
        detailLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = UIColor.systemGray
        detailLabel.numberOfLines = 0
        
        addSubview(indicatorOuterView)
        indicatorOuterView.addSubview(indicatorInnerView)
        addSubview(titleLabel)
        addSubview(detailLabel)
        
        indicatorOuterView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.top.equalToSuperview().offset(16)
            make.size.equalTo(20)
        }
        
        indicatorInnerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(10)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(14)
            make.leading.equalTo(indicatorOuterView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-14)
        }
        
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-14)
            make.bottom.equalToSuperview().offset(-14)
        }
        
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }
    
    private func configure(title: String, detail: String) {
        titleLabel.text = title
        detailLabel.text = detail
    }
    
    private func updateStyle() {
        layer.borderColor = isSelectedOption ? UIColor.systemBlue.cgColor : UIColor.systemGray5.cgColor
        indicatorOuterView.layer.borderColor = isSelectedOption ? UIColor.systemBlue.cgColor : UIColor.systemGray3.cgColor
        indicatorInnerView.isHidden = !isSelectedOption
    }
    
    @objc private func handleTap() {
        onSelect?()
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
    private let badgeView = UIView()
    private let separatorView = UIView()
    
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
        iconContainerView.addSubview(badgeView)
        containerView.addSubview(separatorView)
    }
    
    private func setupLayout() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.greaterThanOrEqualTo(84)
        }
        
        iconContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(48)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(20)
        }
        
        badgeView.snp.makeConstraints { make in
            make.size.equalTo(10)
            make.top.equalToSuperview().offset(-2)
            make.trailing.equalToSuperview().offset(2)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconContainerView.snp.trailing).offset(16)
            make.top.equalToSuperview().offset(18)
            make.trailing.lessThanOrEqualTo(arrowImageView.snp.leading).offset(-16)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.trailing.lessThanOrEqualTo(arrowImageView.snp.leading).offset(-16)
            make.bottom.equalToSuperview().offset(-18)
        }
        
        arrowImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.size.equalTo(15)
        }
        
        separatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
    }
    
    private func setupStyles() {
        backgroundColor = UIColor.clear
        containerView.backgroundColor = .white
        
        iconContainerView.layer.cornerRadius = 14
        
        badgeView.backgroundColor = .systemRed
        badgeView.layer.cornerRadius = 5
        badgeView.layer.borderWidth = 1.5
        badgeView.layer.borderColor = UIColor.systemBackground.cgColor
        badgeView.isHidden = true
        
        separatorView.backgroundColor = UIColor.systemGray6
        
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
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
        onTap?()
    }
    
    func configure(icon: UIImage?, iconBackgroundColor: UIColor, title: String, subtitle: String, showArrow: Bool = true) {
        iconImageView.image = icon
        iconContainerView.backgroundColor = iconBackgroundColor
        titleLabel.text = title
        subtitleLabel.text = subtitle
        arrowImageView.isHidden = !showArrow
    }
    
    func setBadgeVisible(_ visible: Bool) {
        badgeView.isHidden = !visible
    }
    
    func setSeparatorHidden(_ hidden: Bool) {
        separatorView.isHidden = hidden
    }
}
