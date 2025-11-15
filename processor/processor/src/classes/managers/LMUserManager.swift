//
//  LMUserManager.swift
//  processor
//
//  User authentication and session management
//

import Foundation
import Alamofire

class LMUserManager {
    
    // MARK: - Singleton
    static let shared = LMUserManager()
    private init() {}
    
    // MARK: - Properties
    private let accessTokenKey = "lm_access_token"
    private let refreshTokenKey = "lm_refresh_token"
    private let userInfoKey = "lm_user_info"
    
    var accessToken: String? {
        get {
            return UserDefaults.standard.string(forKey: accessTokenKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: accessTokenKey)
        }
    }
    
    var refreshToken: String? {
        get {
            return UserDefaults.standard.string(forKey: refreshTokenKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: refreshTokenKey)
        }
    }
    
    var currentUser: LMUserInfo? {
        get {
            guard let data = UserDefaults.standard.data(forKey: userInfoKey),
                  let user = try? JSONDecoder().decode(LMUserInfo.self, from: data) else {
                return nil
            }
            return user
        }
        set {
            if let user = newValue,
               let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: userInfoKey)
            } else {
                UserDefaults.standard.removeObject(forKey: userInfoKey)
            }
        }
    }
    
    var isLoggedIn: Bool {
        return accessToken != nil
    }
    
    // MARK: - Subscription Info
    
    private let subscriptionTypeKey = "lm_subscription_type"
    private let inspirePointsKey = "lm_inspire_points"
    
    var subscriptionType: String? {
        get {
            return UserDefaults.standard.string(forKey: subscriptionTypeKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: subscriptionTypeKey)
        }
    }
    
    var inspirePoints: Int {
        get {
            return UserDefaults.standard.integer(forKey: inspirePointsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: inspirePointsKey)
        }
    }
    
    // MARK: - Authentication Methods
    
    /// 保存登录信息
    func saveLoginInfo(accessToken: String, refreshToken: String, user: LMUserInfo) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.currentUser = user
        
        LMLogger.log("✅ User logged in: \(user.username)")
    }
    
    /// 保存订阅信息
    func saveSubscriptionInfo(subscriptionType: String, inspirePoints: Int) {
        self.subscriptionType = subscriptionType
        self.inspirePoints = inspirePoints
        
        LMLogger.log("✅ Subscription info saved: \(subscriptionType), points: \(inspirePoints)")
    }
    
    /// 清除登录信息
    func clearLoginInfo() {
        accessToken = nil
        refreshToken = nil
        currentUser = nil
        subscriptionType = nil
        inspirePoints = 0
        
        LMLogger.log("✅ User logged out")
    }
    
    /// 更新用户信息
    func updateUserInfo(_ user: LMUserInfo) {
        currentUser = user
        LMLogger.log("✅ User info updated")
    }
    
    /// 更新 Token
    func updateTokens(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        LMLogger.log("✅ Tokens refreshed")
    }
    
    // MARK: - API Wrapper Methods
    /// 登录（邮箱+密码）
    func login(identifier: String, password: String, completion: @escaping (Result<LMLoginResponse, Error>) -> Void) {
        LMApiService.shared.login(identifier: identifier, password: password) { [weak self] response in
            if response.requestSuccess, let data = response.value {
                self?.saveLoginInfo(
                    accessToken: data.accessToken,
                    refreshToken: data.refreshToken,
                    user: data.user
                )
                // 保存订阅信息和构图次数
                self?.saveSubscriptionInfo(
                    subscriptionType: data.subscriptionType,
                    inspirePoints: data.inspirePoints
                )
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Login failed"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// 注册（邮箱+密码）
    func register(email: String, password: String, name: String?, completion: @escaping (Result<LMUserRegisterResponse, Error>) -> Void) {
        LMApiService.shared.register(email: email, password: password, name: name) { response in
            if response.requestSuccess, let data = response.value {
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Registration failed"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// Apple登录/注册
    func appleLogin(uid: String, fullName: String?, email: String?, idToken: String, completion: @escaping (Result<LMAppleLoginResponse, Error>) -> Void) {
        LMApiService.shared.appleLogin(uid: uid, fullName: fullName, email: email, idToken: idToken) { [weak self] response in
            if response.requestSuccess, let data = response.value {
                self?.saveLoginInfo(
                    accessToken: data.accessToken,
                    refreshToken: data.refreshToken,
                    user: data.user
                )
                // 保存订阅信息和构图次数
                self?.saveSubscriptionInfo(
                    subscriptionType: data.subscriptionType,
                    inspirePoints: data.inspirePoints
                )
                
                LMLogger.log("✅ Apple login success, isNewUser: \(data.isNewUser)")
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Apple login failed"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// 发送邮箱验证码
    func sendEmailVerification(email: String, completion: @escaping (Result<LMEmailVerificationResponse, Error>) -> Void) {
        LMApiService.shared.sendEmailVerification(email: email) { response in
            if response.requestSuccess, let data = response.value {
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Failed to send verification email"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// 验证邮箱验证码
    func verifyEmailCode(email: String, code: String, completion: @escaping (Result<LMEmailVerificationResponse, Error>) -> Void) {
        LMApiService.shared.verifyEmailCode(email: email, code: code) { response in
            if response.requestSuccess, let data = response.value {
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Email verification failed"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// 重新发送验证邮件
    func resendEmailVerification(email: String, completion: @escaping (Result<LMEmailVerificationResponse, Error>) -> Void) {
        LMApiService.shared.resendEmailVerification(email: email) { response in
            if response.requestSuccess, let data = response.value {
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Failed to resend verification email"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// 会话验证
    func validateSession(completion: @escaping (Result<Bool, Error>) -> Void) {
        LMApiService.shared.validateSession { response in
            if response.requestSuccess {
                completion(.success(true))
            } else {
                // 会话无效，清理本地登录信息
                if response.code == 401 {
                    LMUserManager.shared.clearLoginInfo()
                }
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Session validation failed"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// 登出
    func logout(completion: @escaping (Result<Void, Error>) -> Void) {
        LMApiService.shared.logout { [weak self] response in
            if response.requestSuccess {
                self?.clearLoginInfo()
                completion(.success(()))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Logout failed"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// 刷新 Token
    func refreshAccessToken(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let refreshToken = refreshToken else {
            let error = NSError(
                domain: "UserManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No refresh token available"]
            )
            completion(.failure(error))
            return
        }
        
        LMApiService.shared.refreshToken(refreshToken: refreshToken) { [weak self] response in
            if response.requestSuccess, let data = response.value {
                self?.updateTokens(
                    accessToken: data.accessToken,
                    refreshToken: data.refreshToken
                )
                completion(.success(()))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Token refresh failed"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// 获取用户信息
    func fetchUserInfo(completion: @escaping (Result<LMUserInfo, Error>) -> Void) {
        LMApiService.shared.getUserInfo { [weak self] response in
            if response.requestSuccess, let data = response.value {
                self?.updateUserInfo(data)
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Failed to fetch user info"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// 修改密码
    func changePassword(oldPassword: String, newPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        LMApiService.shared.changePassword(oldPassword: oldPassword, newPassword: newPassword) { response in
            if response.requestSuccess {
                completion(.success(()))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Password change failed"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// 当前是否为已登陆用户
    static var isSignIn: Bool {
        return userModel != nil
    }
    
    
    /// 用户数据（仅内存缓存，不持久化）
    static var userModel: LMUserModel?
    
    
    /// 已废弃：不再将 UserModel 存入本地
    @available(*, deprecated, message: "UserModel no longer persisted to local storage")
    static func cachedUserModelData() {
        // 不再执行任何操作
        LMLogger.log("⚠️ cachedUserModelData() is deprecated and does nothing")
    }
    
    /// 加载缓存的用户数据：先刷新 Token，然后获取最新用户信息
    static func loadCachedUserModelData(completion: ((Bool) -> Void)? = nil) {
        // 检查是否有登录状态
        guard LMUserManager.shared.isLoggedIn else {
            LMLogger.log("⚠️ No login session found, skipping user data load")
            completion?(false)
            return
        }
        
        LMLogger.log("🔄 Loading user data: refreshing token first...")
        LMUserManager.shared.refreshAccessToken { result in
            switch result {
            case .success:
                LMLogger.log("✅ Token refreshed successfully")
                LMUserManager.shared.fetchUserInfo { userResult in
                    switch userResult {
                    case .success(let userInfo):
                        // 更新 userModel（仅内存，不持久化）
                        let model = LMUserModel(
                            userId: userInfo.userId,
                            username: userInfo.username,
                            email: userInfo.email,
                            membership: nil,
                            subscriptionType: LMUserManager.shared.subscriptionType,
                            subscriptionExpirationDate: nil
                        )
                        userModel = model
                        LMLogger.log("✅ User data loaded and updated in memory")
                        completion?(true)
                    case .failure(let error):
                        LMLogger.log("❌ Failed to fetch user info: \(error.localizedDescription)")
                        completion?(false)
                    }
                }
            case .failure(let error):
                LMLogger.log("❌ Failed to refresh token: \(error.localizedDescription)")
                // Token 刷新失败，可能需要重新登录
                LMUserManager.shared.clearLoginInfo()
                completion?(false)
            }
        }
    }
    
    private static let cachedUserModelKey = "com.processor.userModel"
}
