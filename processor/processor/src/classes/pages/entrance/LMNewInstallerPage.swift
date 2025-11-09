//
//  LMNewInstallerPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit
import AuthenticationServices

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
        
    }
    
    func welcomeAuthenticationViewDidTapPrivacyPolicy() {
        
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
        // 创建Apple Sign In请求
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        // 请求用户信息
        request.requestedScopes = [.fullName, .email]
        // 创建授权控制器
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        // 发起授权请求
        authorizationController.performRequests()
    }
    
    private func handleSuccessfulAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
        // 提取用户信息
        let userID = credential.user
        let email = credential.email
        let fullName = credential.fullName
        let identityToken = credential.identityToken
        let authorizationCode = credential.authorizationCode
        
        // 构建用户数据
        var userData: [String: Any] = [
            "userID": userID,
            "provider": "apple"
        ]
        
        if let email = email {
            userData["email"] = email
        }
        
        if let fullName = fullName {
            var nameComponents: [String: String] = [:]
            if let givenName = fullName.givenName {
                nameComponents["givenName"] = givenName
            }
            if let familyName = fullName.familyName {
                nameComponents["familyName"] = familyName
            }
            userData["fullName"] = nameComponents
        }
        
        if let identityToken = identityToken,
           let tokenString = String(data: identityToken, encoding: .utf8) {
            userData["identityToken"] = tokenString
        }
        
        if let authorizationCode = authorizationCode,
           let codeString = String(data: authorizationCode, encoding: .utf8) {
            userData["authorizationCode"] = codeString
        }
        
        // 发送到服务端
        sendAppleSignInDataToServer(userData: userData)
    }
    
    private func sendAppleSignInDataToServer(userData: [String: Any]) {
        print("Sending Apple Sign In data to server...")
        print("User data: \(userData)")
        
        // 创建网络请求
        guard let url = URL(string: "https://api.inspirecam.com/auth/apple-signin") else {
            handleAppleSignInError(message: "Invalid server URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: userData, options: [])
            request.httpBody = jsonData
        } catch {
            handleAppleSignInError(message: "Failed to encode user data")
            return
        }
        
        // 发送请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.handleServerResponse(data: data, response: response, error: error)
            }
        }
        
        task.resume()
    }
    
    private func handleServerResponse(data: Data?, response: URLResponse?, error: Error?) {
        // 重新启用认证按钮
        welcomeView.configureAuthenticationButtonsEnabled(true)
        
        if let error = error {
            handleAppleSignInError(message: "Network error: \(error.localizedDescription)")
            return
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            handleAppleSignInError(message: "Invalid server response")
            return
        }
        
        guard let data = data else {
            handleAppleSignInError(message: "No data received from server")
            return
        }
        
        if httpResponse.statusCode == 200 {
            // 解析服务端响应
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    handleSuccessfulServerResponse(response: jsonResponse)
                } else {
                    handleAppleSignInError(message: "Invalid response format")
                }
            } catch {
                handleAppleSignInError(message: "Failed to parse server response")
            }
        } else {
            // 处理服务端错误
            do {
                if let errorResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let errorMessage = errorResponse["message"] as? String {
                    handleAppleSignInError(message: errorMessage)
                } else {
                    handleAppleSignInError(message: "Server error: \(httpResponse.statusCode)")
                }
            } catch {
                handleAppleSignInError(message: "Server error: \(httpResponse.statusCode)")
            }
        }
    }
    
    private func handleSuccessfulServerResponse(response: [String: Any]) {
        print("Server response: \(response)")
        
        // 提取服务端返回的用户信息
        guard let userInfo = response["user"] as? [String: Any],
              let accessToken = response["accessToken"] as? String else {
            handleAppleSignInError(message: "Invalid user data from server")
            return
        }
        
        // 保存用户信息和token
        saveUserAuthenticationData(userInfo: userInfo, accessToken: accessToken)
        
        // 显示成功提示
        showSignInSuccessMessage()
        
        // 导航到主应用界面
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.navigateToMainApplicationInterface()
        }
    }
    
    private func saveUserAuthenticationData(userInfo: [String: Any], accessToken: String) {
        // 保存到UserDefaults或Keychain
        UserDefaults.standard.set(accessToken, forKey: "user_access_token")
        UserDefaults.standard.set(userInfo, forKey: "user_profile_data")
        UserDefaults.standard.set(true, forKey: "user_is_logged_in")
        UserDefaults.standard.synchronize()
        
        print("User authentication data saved successfully")
    }
    
    private func handleAppleSignInError(message: String) {
        print("Apple Sign In error: \(message)")
        
        // 重新启用认证按钮
        welcomeView.configureAuthenticationButtonsEnabled(true)
        
        // 显示错误提示
        let alert = UIAlertController(
            title: "Sign In Failed",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showSignInSuccessMessage() {
        let alert = UIAlertController(
            title: "Welcome!",
            message: "You have successfully signed in with Apple.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Continue", style: .default))
        present(alert, animated: true)
    }
    
    private func navigateToMainApplicationInterface() {
        if let mainRootPage = AppTheme.Screen.mainPage {
            AppTheme.Screen.window()?.rootViewController = mainRootPage
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension LMNewInstallerPage: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // 处理Apple ID凭证
            handleSuccessfulAppleSignIn(credential: appleIDCredential)
            
        } else {
            // 处理其他类型的凭证（如果有）
            handleAppleSignInError(message: "Unsupported credential type")
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // 处理授权错误
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                print("User canceled Apple Sign In")
                // 用户取消，重新启用按钮但不显示错误
                welcomeView.configureAuthenticationButtonsEnabled(true)
                
            case .failed:
                handleAppleSignInError(message: "Apple Sign In failed. Please try again.")
                
            case .invalidResponse:
                handleAppleSignInError(message: "Invalid response from Apple. Please try again.")
                
            case .notHandled:
                handleAppleSignInError(message: "Apple Sign In not handled. Please try again.")
                
            case .unknown:
                handleAppleSignInError(message: "Unknown error occurred. Please try again.")
                
            @unknown default:
                handleAppleSignInError(message: "An unexpected error occurred. Please try again.")
            }
        } else {
            handleAppleSignInError(message: "Apple Sign In failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension LMNewInstallerPage: ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}

