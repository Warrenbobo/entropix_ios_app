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
    // 用户信息
    private let profileView = LMMineUserInfoView()
    // 会员及广告奖励
    private var membershipCardView = LMMembershipCardView()
    // 产品菜单
    private var photoCollectionView = LMPhotoCollectionView()
    
    // 悬浮菜单相关
    private var floatingMenuContainer: UIView = UIView()
    private var photoCollectionViewOriginalFrame: CGRect = .zero
    private var isFloatingMenuVisible = false
    
    // 悬浮菜单按钮引用（用于更新文本）
    private var floatingGalleryButton: UIButton!
    private var floatingSavedIdeasButton: UIButton!
    
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
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshUserData()
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
        membershipCardView = LMMembershipCardView()
        membershipCardView.setWatchAdsButtonAction { [weak self] in
            self?.watchAdsButtonTapped()
        }
        membershipCardView.setUpgradeButtonAction { [weak self] in
            self?.upgradeButtonTapped()
        }
        
        // 照片集合视图
        photoCollectionView.onHeightChanged = { [weak self] newHeight in
            self?.updatePhotoCollectionViewHeight(newHeight)
        }
        
        photoCollectionView.onTabChanged = { [weak self] tab in
            self?.updateFloatingMenuState(tab)
        }
    }
    
    private func setupStackView() {
        stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .fill
        scrollView.addSubview(stackView)
        
        stackView.addArrangedSubview(profileView)
        stackView.addArrangedSubview(membershipCardView)
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
        view.addSubview(floatingButton)
        floatingButton.snp.makeConstraints { make in
            make.bottom.equalTo(-(AppTheme.Screen.safeAreaBottom + 30))
            make.trailing.equalTo(-20)
            make.size.equalTo(80)
        }
    }
    
    private func moreButtonTapped() {
        let moreSetting = LMSettingPage()
        navigationController?.pushViewController(moreSetting, animated: true)
    }
    
    private func avatarTapped() {
        let loginView = LMSignInPage()
        let router = LMNavigationWrapper(rootViewController: loginView)
        router.modalPresentationStyle = .fullScreen
        present(router, animated: true)
    }
    
    /// 点击观看广告按钮
    private func watchAdsButtonTapped() {
        if let user = LMUserManager.shared.currentUser {
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
        print("Show ad without reward - AdMob integration pending")
        let alert = UIAlertController(
            title: "Thanks for watching!",
            message: "Your support helps us improve the app",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LMText.common.ok, style: .default))
        present(alert, animated: true)
    }
    
    private func simulateAdRewardSuccess() {
        // 临时模拟：增加5个Inspire Points
        LMUserManager.shared.addInspirePoints(5)
        // 显示成功消息
        let alert = UIAlertController(
            title: "Success!",
            message: "You earned 5 Inspire Points!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LMText.common.ok, style: .default))
        present(alert, animated: true)
    }
    
    private func upgradeButtonTapped() {
        let subscription = LMSubscriptionPage()
        navigationController?.pushViewController(subscription,
                                                 animated: true)
    }
    
    private func cameraButtonTapped() {
        let cameraView = LMCameraPage()
        navigationController?.pushViewController(cameraView, animated: true)
    }
    
    // MARK: - Data Management
    private func refreshUserData() {
        let userManager = LMUserManager.shared
        if let user = userManager.currentUser {
            updateUIForLoggedInUser(user)
        } else {
            updateUIForLoggedOutUser()
        }
    }
    
    private func updateUIForLoggedInUser(_ user: LMUserModel) {
        profileView.updateUserInfo(
            name: user.nickname ?? user.username ?? "User",
            email: user.email ?? "",
            avatar: user.avatar
        )
        
        // 计算到期天数
        var expiryDays: Int?
        if let expiryDate = user.subscriptionExpiryDate {
            let calendar = Calendar.current
            let now = Date()
            let components = calendar.dateComponents([.day], from: now, to: expiryDate)
            expiryDays = components.day
        }
        
        // 更新会员卡片
        let isPlusUser = (user.subscriptionType == .plus || user.subscriptionType == .lifelong)
        membershipCardView.updateMembershipStatus(
            isPlusUser: isPlusUser,
            inspirePoints: user.inspirePoints,
            expiryDays: expiryDays
        )
        
        // 刷新Gallery和Saved Ideas
        photoCollectionView.reloadData()
    }
    
    private func updateUIForLoggedOutUser() {
        // 未登录状态显示默认内容
        profileView.updateUserInfo(
            name: "Sign-in",
            email: "",
            avatar: nil
        )
        
        // 显示免费计划，0个Inspire Points
        membershipCardView.updateMembershipStatus(
            isPlusUser: false,
            inspirePoints: 0,
            expiryDays: nil
        )
        
        // 清空Gallery和Saved Ideas
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
        // 创建悬浮菜单按钮
        floatingGalleryButton = UIButton()
        floatingSavedIdeasButton = UIButton()
        let floatingTabIndicator = UIView()
        
        // 设置按钮样式
        floatingGalleryButton.setTitle(LMText.profile.gallery, for: .normal)
        floatingGalleryButton.setTitleColor(UIColor.systemBlue, for: .selected)
        floatingGalleryButton.setTitleColor(UIColor.systemGray, for: .normal)
        floatingGalleryButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        floatingGalleryButton.isSelected = true
        floatingGalleryButton.addTarget(self, action: #selector(floatingGalleryTabTapped), for: .touchUpInside)
        
        floatingSavedIdeasButton.setTitle(LMText.profile.savedIdeas, for: .normal)
        floatingSavedIdeasButton.setTitleColor(UIColor.systemBlue, for: .selected)
        floatingSavedIdeasButton.setTitleColor(UIColor.systemGray, for: .normal)
        floatingSavedIdeasButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        floatingSavedIdeasButton.addTarget(self, action: #selector(floatingSavedIdeasTabTapped), for: .touchUpInside)
        
        floatingTabIndicator.backgroundColor = UIColor.systemBlue
        floatingTabIndicator.layer.cornerRadius = 2
        
        floatingMenuContainer.addSubview(floatingGalleryButton)
        floatingMenuContainer.addSubview(floatingSavedIdeasButton)
        floatingMenuContainer.addSubview(floatingTabIndicator)
        
        // 设置约束
        floatingGalleryButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(44)
            make.centerY.equalToSuperview()
            make.width.equalTo(80)
        }
        
        floatingSavedIdeasButton.snp.makeConstraints { make in
            make.leading.equalTo(floatingGalleryButton.snp.trailing).offset(40)
            make.centerY.equalToSuperview()
            make.width.equalTo(120)
        }
        
        floatingTabIndicator.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-8)
            make.centerX.equalTo(floatingGalleryButton)
            make.width.equalTo(50)
            make.height.equalTo(4)
        }
        
        // 保存引用以便后续更新
        floatingMenuContainer.tag = 999 // 用于标识
    }
    
    @objc private func floatingGalleryTabTapped() {
        photoCollectionView.switchToTab(.gallery)
        updateFloatingMenuState(.gallery)
    }
    
    @objc private func floatingSavedIdeasTabTapped() {
        photoCollectionView.switchToTab(.savedIdeas)
        updateFloatingMenuState(.savedIdeas)
    }
    
    private func updateFloatingMenuState(_ tab: TabType) {
        let indicator = floatingMenuContainer.subviews.first { !($0 is UIButton) }
        
        floatingGalleryButton?.isSelected = (tab == .gallery)
        floatingSavedIdeasButton?.isSelected = (tab == .savedIdeas)
        
        // 动画移动指示器
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
            if tab == .gallery {
                indicator?.snp.remakeConstraints { make in
                    make.bottom.equalToSuperview().offset(-8)
                    make.centerX.equalTo(self.floatingGalleryButton!)
                    make.width.equalTo(50)
                    make.height.equalTo(4)
                }
            } else {
                indicator?.snp.remakeConstraints { make in
                    make.bottom.equalToSuperview().offset(-8)
                    make.centerX.equalTo(self.floatingSavedIdeasButton!)
                    make.width.equalTo(50)
                    make.height.equalTo(4)
                }
            }
            self.floatingMenuContainer.layoutIfNeeded()
        }
    }
    
    private func updatePhotoCollectionViewHeight(_ newHeight: CGFloat) {
        // 当照片集合视图高度变化时，更新布局
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
