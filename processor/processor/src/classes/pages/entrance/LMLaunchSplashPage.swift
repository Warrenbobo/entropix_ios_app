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
                    LMLogger.log("✅ User already signed in, entering home page")
                    let rootController = LMNavigationWrapper(rootViewController: LMMinePage())
                    LMPackageManager.switchWindowSceneContent(rootController)
                } else {
                    // 未登录，尝试 Guest 注册和登录
                    LMLogger.log("👤 No user signed in, attempting guest registration and login")
                    self.registerAndLoginAsGuest()
                }
            }
        }
    }
    
    /// Guest 用户注册和登录
    private func registerAndLoginAsGuest() {
        // 获取设备 ID
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        LMLogger.log("📱 Device ID: \(deviceId)")
        
        // 获取当前语言
        let language = LMLaunageManager.shared.currentLanguage.rawValue
        LMLogger.log("🌐 Language: \(language)")
        
        // 先尝试注册 Guest 用户（如果已存在会返回现有用户）
        LMApiService.shared.registerGuest(deviceId: deviceId, language: language) { [weak self] response in
            guard let self = self else { return }
            
            if response.requestSuccess {
                LMLogger.log("✅ Guest user registered successfully")
                // 注册成功后，进行登录
                self.performGuestLogin(deviceId: deviceId)
            } else {
                LMLogger.log("⚠️ Guest registration response: \(response.message ?? "Unknown")")
                // 即使注册失败，也尝试登录（可能用户已存在）
                self.performGuestLogin(deviceId: deviceId)
            }
        }
    }
    
    /// 执行 Guest 登录
    private func performGuestLogin(deviceId: String) {
        LMApiService.shared.loginGuest(deviceId: deviceId) { [weak self] response in
            guard self != nil else { return }
            
            DispatchQueue.main.async {
                if response.requestSuccess, let loginData = response.value {
                    LMLogger.log("✅ Guest user logged in successfully")
                    LMLogger.log("👤 Username: \(loginData.user.username)")
                    LMLogger.log("📊 Is guest: \(loginData.user.isGuest ?? false)")
                    LMLogger.log("🎯 Inspire points: \(loginData.inspirePoints)")
                    
                    // 保存 Token
                    LMUserManager.shared.accessToken = response.value?.accessToken
                    LMUserManager.shared.refreshToken = response.value?.refreshToken
                    
                    // 解析订阅类型
                    let subscriptionType: SubscriptionType
                    if let subscription = loginData.user.subscription {
                        subscriptionType = SubscriptionType(rawValue: subscription) ?? .free
                    } else {
                        subscriptionType = .free
                    }
                    
                    // 保存用户信息
                    var user = loginData.user.toLMUser(
                        subscriptionType: subscriptionType,
                        inspirePoints: loginData.inspirePoints
                    )
                    user.isGuest = true
                    LMUserManager.shared.updateUser(user)
                    
                    // 进入主页
                    let rootController = LMNavigationWrapper(rootViewController: LMMinePage())
                    LMPackageManager.switchWindowSceneContent(rootController)
                    
                } else {
                    LMLogger.log("❌ Guest login failed: \(response.message ?? "Unknown error")")
                    // 登录失败，进入新用户引导页
                    let rootController = LMNavigationWrapper(rootViewController: LMNewInstallerPage())
                    LMPackageManager.switchWindowSceneContent(rootController)
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
