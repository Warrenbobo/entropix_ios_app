//
//  LMNewInstallerPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit
import AuthenticationServices
import Toast_Swift

class LMNewInstallerPage: LMPageWrapper {
    
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    
    private let welcomeView = LMWelcomeAuthenticationView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUserInterfaceComponents()
        configureScrollViewConstraints()
        configureScrollViewProperties()
        setupViewComponentDelegates()
        viewAdapter(scrollView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true,
                                                     animated: animated)
    }
}

extension LMNewInstallerPage {
    
    func updateWelcomeMessageConfiguration(title: String, subtitle: String) {
        welcomeView.updateWelcomeMessageContent(title: title, subtitle: subtitle)
    }
    
    func updateUserAvatarImageConfiguration(_ image: UIImage?) {
        welcomeView.updateUserAvatarImageContent(image)
    }
    
//    func updateFeaturePreviewConfiguration(title: String) {
//        featureView.updateFeaturePreviewTitleContent(title)
//    }
//    
//    func updateRemainingInspiringPointsConfiguration(_ count: Int) {
//        featureView.updateRemainingInspiringPointsCount(count)
//    }
}

extension LMNewInstallerPage {
    
    private func setupUserInterfaceComponents() {
        scrollView.contentInset = UIEdgeInsets(top: AppTheme.Screen.safeAreaTop,
                                               left: 0,
                                               bottom: AppTheme.Screen.safeAreaBottom,
                                               right: 0)
        setupScrollViewAndContentStack()
        contentStackView.addArrangedSubview(welcomeView)
//        contentStackView.addArrangedSubview(featureView)
    }
    
    private func setupScrollViewAndContentStack() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)
        
        contentStackView.axis = .vertical
        contentStackView.spacing = 40
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
    }
    
    private func configureScrollViewProperties() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
    }
    
    private func setupViewComponentDelegates() {
        welcomeView.delegate = self
//        featureView.delegate = self
    }
    
    private func configureScrollViewConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(20)
            make.width.equalTo(AppTheme.Screen.width - 40)
        }
    }
}

extension LMNewInstallerPage: LMWelcomeAuthenticationViewDelegate {
    
    func welcomeAuthenticationViewDidTapSignInWithEmail() {
        let signIn = LMSignInPage()
        navigationController?.pushViewController(signIn,
                                                 animated: true)
    }
    
    func welcomeAuthenticationViewDidTapContinueWithApple() {
        performAppleSignInAuthentication()
    }
    
    func welcomeAuthenticationViewDidTapTermsOfService() {
        // TODO: 显示服务条款
    }
    
    func welcomeAuthenticationViewDidTapPrivacyPolicy() {
        // TODO: 显示隐私政策
    }
    
    func welcomeAuthenticationViewDidTapSignUpPrompt() {
        let signUp = LMSignUpPage()
        navigationController?.pushViewController(signUp,
                                                 animated: true)
    }
}

// MARK: - Apple Sign In Implementation
extension LMNewInstallerPage {
    
    private func performAppleSignInAuthentication() {
        // 禁用认证按钮，防止重复点击
        welcomeView.configureAuthenticationButtonsEnabled(false)
        
        // 使用 LMAppleAuthManager 处理 Apple 登录
        LMAppleAuthManager.shared.signInWithApple { [weak self] result in
            guard let self = self else { return }
            
            // 重新启用认证按钮
            self.welcomeView.configureAuthenticationButtonsEnabled(true)
            
            switch result {
            case .success(let response):
                // Apple 登录成功
                LMLogger.log("✅ Apple Sign In successful")
                LMLogger.log("   User: \(response.user.username)")
//                LMLogger.log("   Is New User: \(response.user.isNewUser)")
                LMLogger.log("   Subscription: \(response.subscriptionType)")
                LMLogger.log("   Inspire Points: \(response.inspirePoints)")
                
                // 处理登录成功
                self.handleAppleLoginSuccess()
                
            case .failure(let error):
                // Apple 登录失败
                LMLogger.log("❌ Apple Sign In failed: \(error.localizedDescription)")
                self.handleAppleSignInError(message: error.localizedDescription)
            }
        }
    }
    
    private func handleAppleLoginSuccess() {
        // 导航到主应用界面
        if let mainRootPage = AppTheme.Screen.mainPage {
            AppTheme.Screen.window()?.rootViewController = mainRootPage
        }
    }
    
    private func handleAppleSignInError(message: String) {
        showToast(message)
    }
}

