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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupMineContentComponents()
        setupStackView()
        setupCustomNavigationBar()
        createTheFloatingCameraEntranceView()
        viewAdapter(scrollView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    private func setupCustomNavigationBar() {
        topBar.setTitle("Profile")
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
        
        // 照片集合视图
        photoCollectionView.onHeightChanged = { [weak self] newHeight in
            self?.updatePhotoCollectionViewHeight(newHeight)
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
    
    private func watchAdsButtonTapped() {
        print("Watch ads button tapped")
    }
    
    private func galleryTabTapped() {
        print("Gallery tab tapped")
    }
    
    private func savedIdeasTabTapped() {
        print("Saved ideas tab tapped")
    }
    
    private func imageView1Tapped() {
        print("Image view 1 tapped")
    }
    
    private func imageView2Tapped() {
        print("Image view 2 tapped")
    }
    
    private func cameraButtonTapped() {
        let cameraView = LMCameraPage()
        navigationController?.pushViewController(cameraView, animated: true)
    }
    
    private func updatePhotoCollectionViewHeight(_ newHeight: CGFloat) {
        // 当照片集合视图高度变化时，更新布局
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
}
