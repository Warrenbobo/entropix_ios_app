//
//  LMLaunchSplashPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

class LMLaunchSplashPage: UIViewController {
    
    // MARK: - UI Components
    private let logoImageView = UIImageView()
    private let appNameLabel = UILabel()
    private let taglineLabel = UILabel()
    
    // MARK: - Properties
    private var showPrivacy: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewHierarchy()
        setupConstraints()
        loadAppDataAndCheckVersion()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true,
                                                     animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false,
                                                     animated: animated)
    }
    
    /// 进入APP时的基础配置
    private func loadAppDataAndCheckVersion() {
        LMPackageManager.setup()
        checkPrivacyPermissionState()
    }
    
    /// 检查用户是否已经同意隐私授权
    private func checkPrivacyPermissionState() {
        // 检查是否显示过隐私协议
        loadPackageDataAndEnterHomePage()
    }
    
    /// 加载配置信息并进入首页
    private func loadPackageDataAndEnterHomePage() {
        // 尝试加载用户数据（刷新 Token + 获取用户信息）
        LMUserManager.loadCachedUserModelData { success in
            DispatchQueue.main.async {
                if LMUserManager.isSignIn {
                    // 已登录，进入主页
                   let rootController = LMNavigationWrapper(rootViewController: LMMinePage())
                    LMPackageManager.switchWindowSceneContent( rootController)
                } else {
                    let rootController = LMNavigationWrapper(rootViewController: LMNewInstallerPage())
                    LMPackageManager.switchWindowSceneContent( rootController)
                }
            }
        }
    }
    
    // MARK: - UI Setup
    private func configureViewHierarchy() {
        // 背景色
        view.backgroundColor = .white
        
        // Logo 图片
        logoImageView.image = UIImage(named: "app_logo_transparent_bg")
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        view.addSubview(logoImageView)
        
        // 应用名称
        appNameLabel.text = "Entropix"
        appNameLabel.font = UIFont.boldSystemFont(ofSize: 32)
        appNameLabel.textColor = .label
        appNameLabel.textAlignment = .center
        view.addSubview(appNameLabel)
        
        // 标语
        taglineLabel.text = "Unleash Your Creativity in Photography"
        taglineLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        taglineLabel.textColor = UIColor(white: 0.67, alpha: 1.0)
        taglineLabel.textAlignment = .center
        taglineLabel.numberOfLines = 1
        taglineLabel.adjustsFontSizeToFitWidth = true
        view.addSubview(taglineLabel)
    }
    
    private func setupConstraints() {
        // Logo 约束
        logoImageView.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(62)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-62)
            make.centerY.equalTo(view.safeAreaLayoutGuide).offset(-90)
            make.width.equalTo(logoImageView.snp.height).multipliedBy(465.0 / 379.0)
        }
        
        // 应用名称约束
        appNameLabel.snp.makeConstraints { make in
            make.centerX.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(taglineLabel.snp.top).offset(-16)
        }
        
        // 标语约束
        taglineLabel.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(30)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-30)
            make.centerX.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-40)
        }
    }
    
    /// 点击隐私协议的取消按钮
    private func userTapedRejectButton() {
        abort()
    }
    
    /// 用户点击同意进入下一步
    private func userTapedAgreementButton() {
        
        loadPackageDataAndEnterHomePage()
    }
    
    /// 跳转用户协议
    private func userServicesTextOnTap() {
        
    }
    
    /// 跳转隐私政策
    private func userPrivacyTextOnTap() {
       
    }
}
