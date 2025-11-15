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
    private var completion: ((Result<LMAppleLoginResponse, Error>) -> Void)?
    
    // MARK: - Public Methods
    
    /// 发起Apple登录
    func signInWithApple(completion: @escaping (Result<LMAppleLoginResponse, Error>) -> Void) {
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
        // 调用后端API
        LMUserManager.shared.appleLogin(
            uid: userID,
            fullName: fullNameString,
            email: email,
            idToken: identityToken
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.completion?(result)
                self?.completion = nil
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
