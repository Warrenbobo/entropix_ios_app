//
//  LMAppleAuthManager.swift
//  processor
//
//  Apple登录管理器
//

import Foundation
import AuthenticationServices
import UIKit

class LMAppleAuthManager: NSObject {
    
    // MARK: - Singleton
    static let shared = LMAppleAuthManager()
    private override init() {}
    
    // MARK: - Properties
    private var completion: ((Result<LMUserModel, Error>) -> Void)?
    private weak var presentationAnchorWindow: ASPresentationAnchor?
    
    // MARK: - Public Methods
    
    /// 发起Apple登录
    func signInWithApple(completion: @escaping (Result<LMUserModel, Error>) -> Void) {
        self.completion = completion
        presentationAnchorWindow = resolvePresentationAnchorWindow()
        
        LMLogger.log("🍎 Starting Apple Sign In process...")
        
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        
        LMLogger.log("🍎 Performing authorization requests...")
        authorizationController.performRequests()
        
        LMLogger.log("🍎 Apple Sign In initiated")
    }
    
    /// 检查Apple登录状态
    func checkAppleSignInState(userID: String, completion: @escaping (ASAuthorizationAppleIDProvider.CredentialState) -> Void) {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.getCredentialState(forUserID: userID) { credentialState, error in
            DispatchQueue.main.async {
                if let error = error {
                    LMLogger.log("❌ Failed to check Apple Sign In state: \(error)")
                }
                completion(credentialState)
            }
        }
    }
    
    private func resolvePresentationAnchorWindow() -> ASPresentationAnchor? {
        if let visibleWindow = AppTheme.Screen.visibleController()?.view.window {
            return visibleWindow
        }
        
        if let packageWindow = LMPackageManager.window {
            return packageWindow
        }
        
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .sorted { lhs, rhs in
                lhs.activationState.sortPriority < rhs.activationState.sortPriority
            }
        
        for scene in windowScenes {
            if let keyWindow = scene.windows.first(where: \.isKeyWindow) {
                return keyWindow
            }
            
            if let visibleWindow = scene.windows.first(where: { !$0.isHidden && $0.alpha > 0 }) {
                return visibleWindow
            }
        }
        
        return nil
    }
    
    private func completeSignIn(with result: Result<LMUserModel, Error>) {
        completion?(result)
        completion = nil
        presentationAnchorWindow = nil
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension LMAppleAuthManager: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        LMLogger.log("🍎 Authorization completed successfully")
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            LMLogger.log("❌ Invalid Apple ID credential")
            let error = NSError(
                domain: "AppleAuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Apple ID credential"]
            )
            completeSignIn(with: .failure(error))
            return
        }
        
        let userID = appleIDCredential.user
        let fullName = appleIDCredential.fullName
        let email = appleIDCredential.email
        
        // 获取 ID Token
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            let error = NSError(
                domain: "AppleAuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to get identity token"]
            )
            completeSignIn(with: .failure(error))
            return
        }
        
        // 构建完整姓名
        var fullNameString: String?
        if let fullName = fullName {
            let components = [fullName.givenName, fullName.familyName].compactMap { $0 }
            if !components.isEmpty {
                fullNameString = components.joined(separator: " ")
            }
        }
        
        LMLogger.log("🍎 Apple Sign In success")
        LMLogger.log("   User ID: \(userID)")
        LMLogger.log("   Full Name: \(fullNameString ?? "nil")")
        LMLogger.log("   Email: \(email ?? "nil")")
        
        // ✅ Apple 登录流程：先注册，再登录
        LMLogger.log("🍎 Step 1: Registering Apple user...")
        LMApiService.shared.registerWithApple(
            appleUid: userID,
            idToken: identityToken,
            email: email,
            fullName: fullNameString,
            username: LMUserManager.userModel?.username,
            deviceId: LMPackageManager.package.uuid
        ) { [weak self] registerResponse in
            if registerResponse.requestSuccess, let response = registerResponse.value {
                LMLogger.log("✅ Apple registration successful for user: \(response.username ?? "unknown")")
                LMUserManager.shared.updateUser(response)
                // 新用户注册成功后，自动领取免费试用（14天）
                LMLogger.log("🍎 Step 2: Claiming free trial for new user...")
                self?.claimFreeTrialAfterRegistration { _ in
                    DispatchQueue.main.async {
                        // 无论免费试用是否成功，都返回登录成功结果
                        let latestUser = LMUserManager.userModel ?? response
                        self?.completeSignIn(with: .success(latestUser))
                    }
                }
            } else {
                LMLogger.log("❌ Apple registration failed: \(registerResponse.message ?? "Unknown error")")
                let registrationError = NSError(
                    domain: "AppleAuthManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: registerResponse.message ?? "Unknown error"]
                )
                self?.completeSignIn(with: .failure(registrationError))
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 注册成功后领取免费试用
    private func claimFreeTrialAfterRegistration(completion: @escaping (Bool) -> Void) {
        LMUserManager.shared.claimFreeTrial { response in
            if response.requestSuccess, let data = response.value {
                if let granted = data.granted, granted {
                    LMLogger.log("🎉 Free trial claimed successfully!")
                    if let subscription = data.subscription {
                        LMLogger.log("   Plan: \(subscription.planType ?? "trial")")
                        LMLogger.log("   Status: \(subscription.status ?? "active")")
                        LMLogger.log("   End Date: \(subscription.endDate ?? "N/A")")
                    }
                    completion(true)
                } else {
                    LMLogger.log("⚠️ Free trial not granted (may already have subscription)")
                    completion(false)
                }
            } else {
                LMLogger.log("⚠️ Failed to claim free trial: \(response.message ?? "Unknown error")")
                // 免费试用领取失败不影响登录流程
                completion(false)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        LMLogger.log("❌ Apple Sign In failed: \(error.localizedDescription)")
        
        let nsError = error as NSError
        
        // 用户取消授权
        if nsError.code == ASAuthorizationError.canceled.rawValue {
            let cancelError = NSError(
                domain: "AppleAuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Apple Sign In canceled"]
            )
            completeSignIn(with: .failure(cancelError))
        } else {
            completeSignIn(with: .failure(error))
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension LMAppleAuthManager: ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let anchor = presentationAnchorWindow ?? resolvePresentationAnchorWindow() {
            return anchor
        }
        
        LMLogger.log("⚠️ Apple Sign In presentation anchor missing, returning an empty fallback window")
        return ASPresentationAnchor()
    }
}

private extension UIScene.ActivationState {
    var sortPriority: Int {
        switch self {
        case .foregroundActive:
            return 0
        case .foregroundInactive:
            return 1
        case .background:
            return 2
        case .unattached:
            return 3
        @unknown default:
            return 4
        }
    }
}
