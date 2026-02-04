//
//  LMAppleAuthManager.swift
//  processor
//
//  Apple登录管理器
//

import Foundation
import AuthenticationServices

class LMAppleAuthManager: NSObject {
    
    // MARK: - Singleton
    static let shared = LMAppleAuthManager()
    private override init() {}
    
    // MARK: - Properties
    private var completion: ((Result<LMUserModel, Error>) -> Void)?
    
    // MARK: - Public Methods
    
    /// 发起Apple登录
    func signInWithApple(completion: @escaping (Result<LMUserModel, Error>) -> Void) {
        self.completion = completion
        
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
            completion?(.failure(error))
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
            completion?(.failure(error))
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
                        self?.completion?(.success(latestUser))
                        self?.completion = nil
                    }
                }
            } else {
                LMLogger.log("❌ Apple registration failed: \(registerResponse.message ?? "Unknown error")")
                AppTheme.Toast.showText(registerResponse.message)
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
            completion?(.failure(cancelError))
        } else {
            completion?(.failure(error))
        }
        
        completion = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension LMAppleAuthManager: ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return LMPackageManager.window!
    }
}
