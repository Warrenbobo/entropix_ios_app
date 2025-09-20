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
    private var scrollView: UIScrollView!
    private var stackView: UIStackView!
    // 用户信息
    private let profileView = LMMineUserInfoView()
    // 会员及广告奖励
    private var membershipCardView = LMMembershipCardView()
    // 产品菜单
    private var galleryMenuView = LMGalleryMenuView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCustomNavigationBar()
        setupScrollView()
        setupMineContentComponents()
        setupStackView()
        createTheFloatingCameraEntranceView()
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
        scrollView = UIScrollView()
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
        
        // 标签页组件
        galleryMenuView = LMGalleryMenuView()
        galleryMenuView.setGalleryButtonAction { [weak self] in
            self?.galleryTabTapped()
        }
        galleryMenuView.setSavedIdeasButtonAction { [weak self] in
            self?.savedIdeasTabTapped()
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
        stackView.addArrangedSubview(galleryMenuView)
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
        print("More button tapped")
    }
    
    private func avatarTapped() {
        let loginView = LMLoginPage()
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
}
