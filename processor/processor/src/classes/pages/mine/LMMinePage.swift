//
//  LMMinePage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

class LMMinePage: LMPageWrapper {
	    
    private let topBar = LMProcessorTopBar()
    private var scrollView = UIScrollView()
    private var stackView: UIStackView!
    private var floatingCameraButton: LMFloatingCameraButton?
    // 用户信息
    private let profileView = LMMineUserInfoView()
    // 是否展示个人中心会员卡功能
    private let showMembershipCard = false
    // 会员及广告奖励
    private var membershipCardView = LMMembershipCardView()
    // 产品菜单
    private lazy var photoCollectionView = LMPhotoCollectionView()
    private var isMineVisible = false
    private var needsPhotoCollectionReload = true
    private var hasAppliedInitialPhotoCollectionLayout = false
    
    // 悬浮菜单相关
    private var floatingMenuContainer: UIView = UIView()
    private var photoCollectionViewOriginalFrame: CGRect = .zero
    private var isFloatingMenuVisible = false
    
    // 悬浮菜单按钮引用（用于更新文本）
    private var floatingSavedIdeasButton: UIButton!
    private var floatingSceneHistoryButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupMineContentComponents()
        setupStackView()
        setupCustomNavigationBar()
        setupFloatingMenu()
        createTheFloatingCameraEntranceView()
        viewAdapter(scrollView)
        
        // 监听用户数据变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDataDidChange),
            name: LMUserManager.userDataDidChangeNotification,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setMineChromeHidden(false)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        updateNavigationPresentation()
        refreshUserData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isMineVisible = true
        DispatchQueue.main.async { [weak self] in
            self?.reloadPhotoCollectionIfNeeded()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isMineVisible = false
        setMineChromeHidden(true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Localization

    @objc private func userDataDidChange() {
        refreshUserData()
    }
    
    private func setupCustomNavigationBar() {
        topBar.setTitle(LMText.profile.profile)
        topBar.setBackButtonAction { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        topBar.setMoreButtonAction { [weak self] in
            self?.moreButtonTapped()
        }
        view.addSubview(topBar)
        topBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(AppTheme.Screen.safeAreaTop + 44)
        }
    }
    
    private func setupScrollView() {
        scrollView.contentInset = UIEdgeInsets(top: AppTheme.Screen.safeAreaTop + 44,
                                               left: 0,
                                               bottom: 0,
                                               right: 0)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupMineContentComponents() {
        // 用户信息组件
        profileView.setAvatarTapAction { [weak self] in
            self?.avatarTapped()
        }
        
        // 会员卡片组件
        if showMembershipCard {
            membershipCardView = LMMembershipCardView()
            membershipCardView.setWatchAdsButtonAction { [weak self] in
                self?.watchAdsButtonTapped()
            }
            membershipCardView.setUpgradeButtonAction { [weak self] in
                self?.upgradeButtonTapped()
            }
            membershipCardView.setFreeTrialButtonAction { [weak self] in
                self?.freeTrialButtonTapped()
            }
        } else {
            membershipCardView.isHidden = true
        }
        
        // 照片集合视图
        photoCollectionView.onHeightChanged = { [weak self] newHeight in
            self?.updatePhotoCollectionViewHeight(newHeight)
        }
        
        photoCollectionView.onTabChanged = { [weak self] tab in
            self?.updateFloatingMenuState(tab)
        }
        photoCollectionView.onSceneHistorySelected = { [weak self] record, cover in
            let page = LMSceneHistoryBrowsePage(record: record, cover: cover)
            self?.navigationController?.pushViewController(page, animated: true)
        }
    }
    
    private func setupStackView() {
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .fill
        scrollView.addSubview(stackView)
        
        stackView.addArrangedSubview(profileView)
        if showMembershipCard {
            stackView.addArrangedSubview(membershipCardView)
        }
        stackView.addArrangedSubview(photoCollectionView)
        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-40)
            make.width.equalTo(scrollView).offset(-40)
        }
    }
    
    // 创建界面上的悬浮相机入口
    private func createTheFloatingCameraEntranceView() {
        let floatingButton = LMFloatingCameraButton()
        floatingButton.setCameraButtonAction {
            self.cameraButtonTapped()
        }
        floatingCameraButton = floatingButton
        view.addSubview(floatingButton)
        floatingButton.snp.makeConstraints { make in
            make.bottom.equalTo(-(AppTheme.Screen.safeAreaBottom + 30))
            make.trailing.equalTo(-20)
            make.size.equalTo(60)
        }
    }

    private func updateNavigationPresentation() {
        let isPushed: Bool
        if let rootController = navigationController?.viewControllers.first {
            isPushed = rootController !== self
        } else {
            isPushed = false
        }

        topBar.setBackButtonHidden(!isPushed)
        floatingCameraButton?.isHidden = isPushed
        floatingMenuContainer.isHidden = !isFloatingMenuVisible
    }
    
    private func setMineChromeHidden(_ hidden: Bool) {
        topBar.isHidden = hidden
        floatingCameraButton?.isHidden = hidden
        floatingMenuContainer.isHidden = hidden || !isFloatingMenuVisible
    }
    
    private func moreButtonTapped() {
        let moreSetting = LMSettingPage()
        navigationController?.pushViewController(moreSetting, animated: true)
    }
    
    private func avatarTapped() {
        // FRAMAIST_BACKEND_DISABLED — account profile entry hidden.
        LMLogger.log("Account profile entry disabled")
        /*
        guard requireLogin(action: "view account profile") else {
            return
        }
        
        let profilePage = LMAccountProfilePage()
        navigationController?.pushViewController(profilePage, animated: true)
        */
    }
    
    /// 点击观看广告按钮
    private func watchAdsButtonTapped() {
        if let user = LMUserManager.userModel {
            if user.subscriptionType == .plus || user.subscriptionType == .lifelong {
                showAdWithoutReward()
            } else {
                showAdWithReward()
            }
        }
    }
    
    private func showAdWithReward() {
        // TODO: 集成Google AdMob SDK
        print("Show ad with reward - AdMob integration pending")
        simulateAdRewardSuccess()
    }
    
    private func showAdWithoutReward() {
        // TODO: 集成Google AdMob SDK
    }
    
    private func simulateAdRewardSuccess() {
        // 临时模拟：增加5个Inspire Points
    }
    
    private func upgradeButtonTapped() {
        // FRAMAIST_BACKEND_DISABLED — subscription entry hidden.
        LMLogger.log("Subscription upgrade entry disabled")
        /*
        guard requireLogin(action: "upgrade subscription") else {
            return
        }
        
        let subscription = LMSubscriptionPage()
        navigationController?.pushViewController(subscription,
                                                 animated: true)
        */
    }
    
    private func freeTrialButtonTapped() {
        // FRAMAIST_BACKEND_DISABLED — free trial entry hidden.
        LMLogger.log("Free trial entry disabled")
        /*
        guard requireLogin(action: "claim free trial") else {
            return
        }
        
        membershipCardView.updateFreeTrialButtonState(hasFreeTrial: false, isLoading: true)
        
        LMUserManager.shared.claimFreeTrial { [weak self] response in
            DispatchQueue.main.async {
                if response.requestSuccess, let data = response.value {
                    if let granted = data.granted, granted {
                        self?.membershipCardView.updateFreeTrialButtonState(hasFreeTrial: true, isLoading: false)
                        AppTheme.Toast.showText(LMText.profile.freeTrialClaimed)
                        self?.refreshUserData()
                        LMLogger.log("✅ Free trial claimed successfully")
                    } else {
                        self?.membershipCardView.updateFreeTrialButtonState(hasFreeTrial: true, isLoading: false)
                        LMLogger.log("⚠️ Free trial already claimed or not available")
                    }
                } else {
                    self?.membershipCardView.updateFreeTrialButtonState(hasFreeTrial: true, isLoading: false)
                    LMLogger.log("❌ Failed to claim free trial: \(response.message ?? "Unknown error")")
                }
            }
        }
        */
    }
    
    private func cameraButtonTapped() {
        let cameraView = LMCameraPage()
        navigationController?.pushViewController(cameraView, animated: true)
    }
    
    // MARK: - Data Management
    private func refreshUserData() {
        if let user = LMUserManager.userModel {
            updateUIForLoggedInUser(user)
        } else {
            updateUIForLoggedOutUser()
        }
    }
    
    private func updateUIForLoggedInUser(_ user: LMUserModel) {
        profileView.updateUserInfo(
            name: user.nickname ?? user.username ?? LMText.profile.defaultUserName,
            email: (user.email?.isEmpty ?? true) ? "-" : user.email!,
            avatar: user.avatar
        )
        
        if showMembershipCard {
            // 计算到期天数（从用户模型获取）
            let expiryDays: Int? = user.daysUntilExpiration
            
            // 检查用户是否已领取免费试用
            // 仅基于 subscriptionEndDate 判断：
            // - 如果 subscriptionEndDate 为空，表示从未领取过，可以领取
            // - 如果 subscriptionEndDate 已过期，表示会员已到期，可以重新领取
            // - 如果 subscriptionEndDate 未过期，表示会员有效期内，不可领取
            let hasFreeTrial = !user.isSubscriptionExpired
            
            // 更新会员卡片 - 使用 isPremiumUser 判断（考虑到期时间）
            membershipCardView.updateMembershipStatus(
                isPlusUser: user.isPremiumUser,
                inspirePoints: user.inspirePoints,
                expiryDays: expiryDays,
                hasFreeTrial: hasFreeTrial,
                subscriptionType: user.subscriptionType
            )
        }
        
        schedulePhotoCollectionReload()
    }
    
    private func updateUIForLoggedOutUser() {
        // 未登录状态显示默认内容
        profileView.updateUserInfo(
            name: LMText.auth.signIn,
            email: "",
            avatar: nil
        )
        
        if showMembershipCard {
            // 显示免费计划，0个Inspire Points，未领取免费试用
            membershipCardView.updateMembershipStatus(
                isPlusUser: false,
                inspirePoints: 0,
                expiryDays: nil,
                hasFreeTrial: false
            )
        }
        
        schedulePhotoCollectionReload()
    }

    private func schedulePhotoCollectionReload() {
        needsPhotoCollectionReload = true
        guard isMineVisible else { return }
        DispatchQueue.main.async { [weak self] in
            self?.reloadPhotoCollectionIfNeeded()
        }
    }

    private func reloadPhotoCollectionIfNeeded() {
        guard isMineVisible, needsPhotoCollectionReload else { return }
        needsPhotoCollectionReload = false
        photoCollectionView.reloadData()
    }
    
    private func setupFloatingMenu() {
        // 创建悬浮菜单容器
        floatingMenuContainer.backgroundColor = UIColor.systemBackground
        floatingMenuContainer.isHidden = true
        
        view.addSubview(floatingMenuContainer)
        floatingMenuContainer.snp.makeConstraints { make in
            make.top.equalTo(topBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(60)
        }
        
        // 获取photoCollectionView的菜单按钮引用并复制到悬浮容器中
        setupFloatingMenuButtons()
    }
    
    private func setupFloatingMenuButtons() {
        floatingSavedIdeasButton = UIButton()
        floatingSceneHistoryButton = UIButton()
        let floatingTabIndicator = UIView()
        
        floatingSavedIdeasButton.setTitle(LMText.profile.mineTabLikedSuggestion, for: .normal)
        floatingSavedIdeasButton.setTitleColor(UIColor.systemBlue, for: .selected)
        floatingSavedIdeasButton.setTitleColor(UIColor.systemGray, for: .normal)
        floatingSavedIdeasButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        floatingSavedIdeasButton.isSelected = true
        floatingSavedIdeasButton.addTarget(self, action: #selector(floatingSavedIdeasTabTapped), for: .touchUpInside)

        floatingSceneHistoryButton.setTitle(LMText.profile.mineTabSceneHistory, for: .normal)
        floatingSceneHistoryButton.setTitleColor(UIColor.systemBlue, for: .selected)
        floatingSceneHistoryButton.setTitleColor(UIColor.systemGray, for: .normal)
        floatingSceneHistoryButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        floatingSceneHistoryButton.addTarget(self, action: #selector(floatingSceneHistoryTabTapped), for: .touchUpInside)
        
        floatingTabIndicator.backgroundColor = UIColor.systemBlue
        floatingTabIndicator.layer.cornerRadius = 2
        
        floatingMenuContainer.addSubview(floatingSavedIdeasButton)
        floatingMenuContainer.addSubview(floatingSceneHistoryButton)
        floatingMenuContainer.addSubview(floatingTabIndicator)
        
        floatingSavedIdeasButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(44)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(100)
        }
        
        floatingSceneHistoryButton.snp.makeConstraints { make in
            make.leading.equalTo(floatingSavedIdeasButton.snp.trailing).offset(40)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(100)
        }
        
        floatingTabIndicator.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-8)
            make.centerX.equalTo(floatingSavedIdeasButton)
            make.width.equalTo(50)
            make.height.equalTo(4)
        }
        
        floatingMenuContainer.tag = 999
    }
    
    @objc private func floatingSavedIdeasTabTapped() {
        photoCollectionView.switchToTab(.savedIdeas)
        updateFloatingMenuState(.savedIdeas)
    }

    @objc private func floatingSceneHistoryTabTapped() {
        photoCollectionView.switchToTab(.sceneHistory)
        updateFloatingMenuState(.sceneHistory)
    }
    
    private func updateFloatingMenuState(_ tab: TabType) {
        let indicator = floatingMenuContainer.subviews.first { !($0 is UIButton) }
        let resolved = (tab == .gallery) ? .savedIdeas : tab
        
        floatingSavedIdeasButton?.isSelected = (resolved == .savedIdeas)
        floatingSceneHistoryButton?.isSelected = (resolved == .sceneHistory)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
            let anchor = (resolved == .savedIdeas)
                ? self.floatingSavedIdeasButton!
                : self.floatingSceneHistoryButton!
            indicator?.snp.remakeConstraints { make in
                make.bottom.equalToSuperview().offset(-8)
                make.centerX.equalTo(anchor)
                make.width.equalTo(50)
                make.height.equalTo(4)
            }
            self.floatingMenuContainer.layoutIfNeeded()
        }
    }
    
    private func updatePhotoCollectionViewHeight(_ newHeight: CGFloat) {
        _ = newHeight
        if !hasAppliedInitialPhotoCollectionLayout {
            hasAppliedInitialPhotoCollectionLayout = true
            UIView.performWithoutAnimation {
                self.view.layoutIfNeeded()
            }
            return
        }

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - UIScrollViewDelegate
extension LMMinePage: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.contentOffset.y > 100 else {
            return
        }
        // 计算photoCollectionView在scrollView中的位置
        let photoCollectionViewFrame = photoCollectionView.convert(photoCollectionView.bounds,
                                                                   to: scrollView)
        let scrollOffset = scrollView.contentOffset.y
        let topBarHeight = AppTheme.Screen.safeAreaTop + 44
        
        // 计算photoCollectionView的菜单栏位置
        let menuTabsPosition = photoCollectionViewFrame.minY - scrollOffset
        let shouldShowFloatingMenu = menuTabsPosition <= topBarHeight
        
        // 显示或隐藏悬浮菜单
        if shouldShowFloatingMenu && !isFloatingMenuVisible {
            showFloatingMenu()
        } else if !shouldShowFloatingMenu && isFloatingMenuVisible {
            hideFloatingMenu()
        }
    }
    
    private func showFloatingMenu() {
        guard !isFloatingMenuVisible else { return }
        
        isFloatingMenuVisible = true
        floatingMenuContainer.isHidden = false
        floatingMenuContainer.alpha = 0
        
        // 同步当前tab状态
        let currentTab = photoCollectionView.getCurrentTab()
        updateFloatingMenuState(currentTab)
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.floatingMenuContainer.alpha = 1
        }
    }
    
    private func hideFloatingMenu() {
        guard isFloatingMenuVisible else { return }
        
        isFloatingMenuVisible = false
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.floatingMenuContainer.alpha = 0
        } completion: { _ in
            self.floatingMenuContainer.isHidden = true
        }
    }
}
