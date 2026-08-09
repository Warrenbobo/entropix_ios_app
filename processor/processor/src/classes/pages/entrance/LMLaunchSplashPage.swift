//
//  LMLaunchSplashPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit
import Alamofire

class LMLaunchSplashPage: UIViewController {

    // MARK: - UI Components
    private let logoImageView = UIImageView()
    private let appNameLabel = UILabel()
    private let taglineLabel = UILabel()
    private var privacyPermissionView: LMPrivacyPermissionView?

    // MARK: - Properties
    private var showPrivacy: Bool = false
    private var hasStartedLaunchFlow = false
    private var hasContinuedToUserDataLoading = false
    private var isCheckingLaunchUpdate = false

    // MARK: - Privacy Permission Keys
    private static let privacyPermissionKey = "hasAgreedPrivacyPermission"

    // MARK: - Network Monitoring Properties
    private var networkReachabilityManager: NetworkReachabilityManager?
    private var networkTimeoutTimer: Timer?
    private var isNetworkAlertShown: Bool = false
    private let networkTimeoutDuration: TimeInterval = 30.0

    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewHierarchy()
        setupConstraints()
        registerLifecycleObservers()
        loadAppDataAndCheckVersion()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        stopNetworkMonitoring()
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
        let hasAgreed = UserDefaults.standard.bool(forKey: Self.privacyPermissionKey)

        if hasAgreed {
            // 已同意隐私授权，直接进入首页
            LMLogger.log("✅ Privacy permission already agreed, proceeding...")
            beginLaunchFlowIfNeeded()
        } else {
            // 未同意隐私授权，显示授权弹窗
            LMLogger.log("📋 Showing privacy permission dialog...")
            showPrivacyPermissionDialog()
        }
    }

    private func registerLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// 显示隐私授权弹窗
    private func showPrivacyPermissionDialog() {
        let permissionView = LMPrivacyPermissionView()
        permissionView.delegate = self
        permissionView.show(in: view, animated: true)
        self.privacyPermissionView = permissionView
    }

    /// 标记用户已同意隐私授权
    private func markPrivacyPermissionAgreed() {
        UserDefaults.standard.set(true, forKey: Self.privacyPermissionKey)
        UserDefaults.standard.synchronize()
        LMLogger.log("✅ Privacy permission marked as agreed")
    }


    /// 加载配置信息并进入首页
    private func loadPackageDataAndEnterHomePage() {
        beginLaunchFlowIfNeeded()
    }

    private func beginLaunchFlowIfNeeded() {
        guard !hasStartedLaunchFlow else { return }
        hasStartedLaunchFlow = true

        // Direct Gemini BYOK: enter home with a local session — no FramAist guest auth.
        if LMFeatureFlagsManager.inspireMeDirectGeminiEnabled {
            LMLogger.log("Direct Gemini BYOK — skipping network and guest login")
            LMUserManager.setupLocalBYOKUser()
            LMPackageManager.switchToHomeRootController()
            return
        }

        if !LMFeatureFlagsManager.backendApiEnabled {
            LMLogger.log("Offline demo mode — skipping network and guest login")
            LMUserManager.setupOfflineDemoUser()
            LMPackageManager.switchToHomeRootController()
            return
        }

        startNetworkMonitoringAndProceed()
    }

    @objc private func handleApplicationDidBecomeActive() {
        guard isViewLoaded, view.window != nil else { return }
        guard UserDefaults.standard.bool(forKey: Self.privacyPermissionKey) else { return }
        guard hasStartedLaunchFlow, !hasContinuedToUserDataLoading else { return }
        guard !isCheckingLaunchUpdate else { return }
        guard networkReachabilityManager == nil else { return }

        checkLaunchAppUpdateAndContinue(forceRefresh: true)
    }

    // MARK: - Network Monitoring

    /// 开始网络监听并在有网络时继续执行
    private func startNetworkMonitoringAndProceed() {
        networkReachabilityManager = NetworkReachabilityManager()

        // 检查当前网络状态
        if let isReachable = networkReachabilityManager?.isReachable, isReachable {
            LMLogger.log("✅ Network is available, proceeding...")
            stopNetworkMonitoring()
            proceedWithUserDataLoading()
            return
        }

        LMLogger.log("⏳ Waiting for network connection...")

        // 启动超时计时器
        startNetworkTimeoutTimer()

        // 开始监听网络状态变化
        networkReachabilityManager?.startListening { [weak self] status in
            guard let self = self else { return }

            switch status {
            case .reachable(.ethernetOrWiFi), .reachable(.cellular):
                LMLogger.log("✅ Network connected: \(status)")
                self.stopNetworkMonitoring()
                self.proceedWithUserDataLoading()

            case .notReachable:
                LMLogger.log("❌ Network not reachable")

            case .unknown:
                LMLogger.log("⚠️ Network status unknown")
            }
        }
    }

    /// 启动网络超时计时器
    private func startNetworkTimeoutTimer() {
        networkTimeoutTimer?.invalidate()
        networkTimeoutTimer = Timer.scheduledTimer(withTimeInterval: networkTimeoutDuration,
                                                    repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.handleNetworkTimeout()
        }
    }

    /// 处理网络超时
    private func handleNetworkTimeout() {
        guard !isNetworkAlertShown else { return }

        // 再次检查网络状态
        if let isReachable = networkReachabilityManager?.isReachable, isReachable {
            LMLogger.log("✅ Network became available before timeout alert")
            stopNetworkMonitoring()
            proceedWithUserDataLoading()
            return
        }

        isNetworkAlertShown = true
        LMLogger.log("⚠️ Network timeout after \(networkTimeoutDuration) seconds")

        // 显示无网络提示
        DispatchQueue.main.async {
            LMAlertDialog.showConfirmAlert(LMText.entrance.noNetworkConnection) {
                // 无网络状态退出APP
                exit(0)
            }
        }
    }

    /// 停止网络监听
    private func stopNetworkMonitoring() {
        networkTimeoutTimer?.invalidate()
        networkTimeoutTimer = nil
        networkReachabilityManager?.stopListening()
        networkReachabilityManager = nil
    }

    /// 继续执行用户数据加载
    private func proceedWithUserDataLoading() {
        checkLaunchAppUpdateAndContinue(forceRefresh: true)
    }

    private func checkLaunchAppUpdateAndContinue(forceRefresh: Bool) {
        guard !hasContinuedToUserDataLoading else { return }
        guard !isCheckingLaunchUpdate else { return }
        isCheckingLaunchUpdate = true

        LMLogger.log("📦 Checking launch app update status...")
        LMPackageManager.queryAppUpdateStatus(forceRefresh: forceRefresh) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isCheckingLaunchUpdate = false
                guard self.view.window != nil else { return }

                LMPackageManager.presentLaunchAppUpdateIfNeeded(from: self) { [weak self] in
                    self?.continueWithUserDataLoadingIfNeeded()
                }
            }
        }
    }

    private func continueWithUserDataLoadingIfNeeded() {
        guard !hasContinuedToUserDataLoading else { return }
        hasContinuedToUserDataLoading = true
        continueWithUserDataLoading()
    }

    private func continueWithUserDataLoading() {
        // 尝试加载用户数据（刷新 Token + 获取用户信息）
        LMUserManager.loadCachedUserModelData { _ in
            DispatchQueue.main.async {
                if LMUserManager.isSignIn {
                    // 已登录，进入主页
                    LMLogger.log("✅ User already signed in, entering home page")
                    LMPackageManager.switchToHomeRootController()
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
        // 获取当前语言
        let language = LMLaunageManager.shared.currentLanguage.apiLanguageCode
        LMLogger.log("🌐 Language: \(language)")

        // 先尝试注册 Guest 用户（如果已存在会返回现有用户）
        LMApiService.shared.registerGuest(language: language) { [weak self] response in
            guard let self = self else { return }

            if response.requestSuccess {
                LMLogger.log("✅ Guest user registered successfully")
                // 注册成功后，进行登录
                self.performGuestLogin()
            } else {
                LMLogger.log("⚠️ Guest registration response: \(response.message ?? "Unknown")")
                // 即使注册失败，也尝试登录（可能用户已存在）
                self.performGuestLogin()
            }
        }
    }

    /// 执行 Guest 登录
    private func performGuestLogin() {
        LMApiService.shared.loginGuest { [weak self] response in
            guard self != nil else { return }

            DispatchQueue.main.async {
                if response.requestSuccess, let loginData = response.value {
                    LMLogger.log("✅ Guest user logged in successfully")
                    LMLogger.log("👤 Username: \(loginData.user?.username ?? "nil")")
                    LMLogger.log("📊 Is guest: \(loginData.user?.isGuest ?? false)")

                    // 保存 Token
                    LMUserManager.shared.accessToken = response.value?.accessToken
                    LMUserManager.shared.refreshToken = response.value?.refreshToken

                    // 保存用户信息
                    LMUserManager.shared.updateUser(loginData.user)

                    // 进入主页
                    LMPackageManager.switchToHomeRootController()

                } else {
                    LMLogger.log("❌ Guest login failed: \(response.message ?? "Unknown error")")
                    self?.showGuestLaunchRecoveryAlert(message: response.message)
                }
            }
        }
    }

    private func showGuestLaunchRecoveryAlert(message: String?) {
        let resolvedMessage: String
        if let message = message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            resolvedMessage = message
        } else {
            resolvedMessage = LMText.common.networkError
        }

        LMAlertDialog.showAlert(
            title: LMText.common.error,
            message: resolvedMessage,
            cancelText: LMText.common.exit,
            confirmText: LMText.common.retry,
            confirmStyle: .normal,
            onConfirm: { [weak self] in
                self?.registerAndLoginAsGuest()
            },
            onCancel: {
                exit(0)
            }
        )
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
        appNameLabel.text = LMText.entrance.entropix
        appNameLabel.font = UIFont.boldSystemFont(ofSize: 32)
        appNameLabel.textColor = .label
        appNameLabel.textAlignment = .center
        view.addSubview(appNameLabel)

        // 标语
        taglineLabel.text = LMText.entrance.unleashCreativity
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

// MARK: - LMPrivacyPermissionViewDelegate
extension LMLaunchSplashPage: LMPrivacyPermissionViewDelegate {

    func privacyPermissionViewDidAgree(_ view: LMPrivacyPermissionView) {
        LMLogger.log("✅ User agreed to privacy permission")
        // 标记已同意
        markPrivacyPermissionAgreed()
        // 隐藏弹窗并进入首页
        view.hide(animated: true) { [weak self] in
            self?.privacyPermissionView = nil
            self?.loadPackageDataAndEnterHomePage()
        }
    }

    func privacyPermissionViewDidReject(_ view: LMPrivacyPermissionView) {
        LMLogger.log("❌ User rejected privacy permission, exiting app")
        // 用户不同意，退出 APP
        exit(0)
    }

    func privacyPermissionViewDidTapPrivacyPolicy(_ view: LMPrivacyPermissionView) {
        LMLogger.log("📋 User tapped Privacy Policy link")
        // 打开隐私政策页面
        if let url = URL(string: LMApi.Terms.privacy) {
            UIApplication.shared.open(url)
        }
    }

    func privacyPermissionViewDidTapTermsOfService(_ view: LMPrivacyPermissionView) {
        LMLogger.log("📋 User tapped Terms of Service link")
        // 打开服务条款页面
        if let url = URL(string: LMApi.Terms.service) {
            UIApplication.shared.open(url)
        }
    }
}
