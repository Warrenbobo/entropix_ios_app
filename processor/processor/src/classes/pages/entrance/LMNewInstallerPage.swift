//
//  LMNewInstallerPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

class LMNewInstallerPage: LMPageWrapper {
    
    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()
    
    private let welcomeView = LMWelcomeAuthenticationView()
    private var featureView = LMFeaturePreviewView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .hexColor("#EEEEEE")
        setupUserInterfaceComponents()
        configureScrollViewConstraints()
        configureScrollViewProperties()
        setupViewComponentDelegates()
        viewAdapter(scrollView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}

extension LMNewInstallerPage {
    
    func updateWelcomeMessageConfiguration(title: String, subtitle: String) {
        welcomeView.updateWelcomeMessageContent(title: title, subtitle: subtitle)
    }
    
    func updateUserAvatarImageConfiguration(_ image: UIImage?) {
        welcomeView.updateUserAvatarImageContent(image)
    }
    
    func updateFeaturePreviewConfiguration(title: String) {
        featureView.updateFeaturePreviewTitleContent(title)
    }
    
    func updateRemainingInspiringPointsConfiguration(_ count: Int) {
        featureView.updateRemainingInspiringPointsCount(count)
    }
}

extension LMNewInstallerPage {
    
    private func setupUserInterfaceComponents() {
        scrollView.contentInset = UIEdgeInsets(top: AppTheme.Screen.safeAreaTop,
                                               left: 0,
                                               bottom: AppTheme.Screen.safeAreaBottom,
                                               right: 0)
        setupScrollViewAndContentStack()
        contentStackView.addArrangedSubview(welcomeView)
        contentStackView.addArrangedSubview(featureView)
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
        featureView.delegate = self
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
        print("Sign in with email button tapped")
        presentEmailSignInViewController()
    }
    
    func welcomeAuthenticationViewDidTapContinueWithApple() {
        print("Continue with Apple button tapped")
        initiateAppleSignInProcess()
    }
    
    func welcomeAuthenticationViewDidTapTermsOfService() {
        print("Terms of Service tapped")
        presentTermsOfServiceViewController()
    }
    
    func welcomeAuthenticationViewDidTapPrivacyPolicy() {
        print("Privacy Policy tapped")
        presentPrivacyPolicyViewController()
    }
    
    func welcomeAuthenticationViewDidTapSignUpPrompt() {
        print("Sign up prompt tapped")
        presentSignUpViewController()
    }
}

extension LMNewInstallerPage: LMFeaturePreviewViewDelegate {
    
    func featurePreviewViewDidTapBasicCameraFeature() {
        print("Basic camera feature tapped")
        navigateToBasicCameraViewController()
    }
    
    func featurePreviewViewDidTapAiInspiringFeature() {
        print("AI inspiring feature tapped")
        navigateToAiInspiringViewController()
        
        // 使用一个AI启发点数
        featureView.decrementRemainingInspiringPoints()
    }
}

extension LMNewInstallerPage {
    
    private func presentEmailSignInViewController() {
        
    }
    
    private func initiateAppleSignInProcess() {
        performAppleSignInAuthentication()
    }
    
    private func presentTermsOfServiceViewController() {
        
    }
    
    private func presentPrivacyPolicyViewController() {
        
    }
    
    private func presentSignUpViewController() {
        
    }
    
    private func navigateToBasicCameraViewController() {
        
    }
    
    private func navigateToAiInspiringViewController() {
        
    }
    
    private func presentViewController(_ viewController: UIViewController, animated: Bool) {
        present(viewController, animated: animated, completion: nil)
    }
}

extension LMNewInstallerPage {
    
    private func performAppleSignInAuthentication() {
        print("Initiating Apple Sign In authentication process")
        
        // 禁用认证按钮，防止重复点击
        welcomeView.configureAuthenticationButtonsEnabled(false)
        
        // 模拟登录过程
        simulateSuccessfulAuthentication()
    }
    
    private func simulateSuccessfulAuthentication() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.handleSuccessfulAuthenticationCompletion()
        }
    }
    
    private func handleSuccessfulAuthenticationCompletion() {
        print("Authentication completed successfully")
        
        // 重新启用认证按钮
        welcomeView.configureAuthenticationButtonsEnabled(true)
        
        // 导航到主应用界面
        navigateToMainApplicationInterface()
    }
    
    private func navigateToMainApplicationInterface() {
        if let mainRootPage = AppTheme.Screen.mainPage {
            AppTheme.Screen.window()?.rootViewController = mainRootPage
        }
    }
}

