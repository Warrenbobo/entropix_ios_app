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
    
    var currentUser: LMUserModel? {
        get {
            guard let data = UserDefaults.standard.data(forKey: userInfoKey),
                  let user = try? JSONDecoder().decode(LMUserModel.self, from: data) else {
                return nil
            }
            return user
        }
        set {
            if let user = newValue,
               let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: userInfoKey)
                // 发送用户数据变化通知
                NotificationCenter.default.post(name: Self.userDataDidChangeNotification, object: nil)
            } else {
                UserDefaults.standard.removeObject(forKey: userInfoKey)
                NotificationCenter.default.post(name: Self.userDataDidChangeNotification, object: nil)
            }
        }
    }
    
    // 用户数据变化通知
    static let userDataDidChangeNotification = Notification.Name("LMUserDataDidChange")
    
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
    func saveLoginInfo(accessToken: String, refreshToken: String, user: LMUserInfo, subscriptionType: String = "free", inspirePoints: Int = 0) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        
        // 转换LMUserInfo为LMUserModel
        let subscriptionTypeEnum = SubscriptionType(rawValue: subscriptionType) ?? .free
        let lmUser = user.toLMUser(subscriptionType: subscriptionTypeEnum, inspirePoints: inspirePoints)
        self.currentUser = lmUser
        
        LMLogger.log("✅ User logged in: \(user.username), subscription: \(subscriptionType), points: \(inspirePoints)")
    }
    
    /// 保存订阅信息（已废弃，使用saveLoginInfo的完整版本）
    @available(*, deprecated, message: "Use saveLoginInfo with subscription parameters instead")
    func saveSubscriptionInfo(subscriptionType: String, inspirePoints: Int) {
        if var user = currentUser {
            user.subscriptionType = SubscriptionType(rawValue: subscriptionType) ?? .free
            user.inspirePoints = inspirePoints
            currentUser = user
        }
        
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
    func updateUser(_ user: LMUserModel) {
        currentUser = user
        LMLogger.log("✅ User info updated")
    }
    
    /// 更新Inspire Points
    func updateInspirePoints(_ points: Int) {
        if var user = currentUser {
            user.inspirePoints = points
            currentUser = user
            LMLogger.log("✅ Inspire points updated: \(points)")
        }
    }
    
    /// 增加Inspire Points
    func addInspirePoints(_ points: Int) {
        if var user = currentUser {
            user.inspirePoints += points
            currentUser = user
            LMLogger.log("✅ Inspire points added: +\(points), total: \(user.inspirePoints)")
        }
    }
    
    /// 减少Inspire Points
    func deductInspirePoints(_ points: Int) -> Bool {
        guard var user = currentUser else { return false }
        guard user.inspirePoints >= points else { return false }
        
        user.inspirePoints -= points
        currentUser = user
        LMLogger.log("✅ Inspire points deducted: -\(points), remaining: \(user.inspirePoints)")
        return true
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
        // 正常登录流程
        LMApiService.shared.login(identifier: identifier, password: password) { [weak self] response in
            if response.requestSuccess, let data = response.value {
                // 使用新的saveLoginInfo方法，直接传入订阅信息
                self?.saveLoginInfo(
                    accessToken: data.accessToken,
                    refreshToken: data.refreshToken,
                    user: data.user,
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
    func register(username: String, email: String, password: String, completion: @escaping (Result<LMUserInfo, Error>) -> Void) {
        LMApiService.shared.register(username: username, email: email, password: password) { response in
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
    
    /// Apple 注册
    func registerWithApple(appleUid: String, idToken: String, email: String?, fullName: String?, completion: @escaping (Result<LMUserRegisterResponse, Error>) -> Void) {
        LMApiService.shared.registerWithApple(appleUid: appleUid, idToken: idToken, email: email, fullName: fullName) { response in
            if response.requestSuccess, let data = response.value {
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Apple registration failed"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// Apple 登录（统一使用 LMLoginResponse）
    func loginWithApple(appleUid: String, idToken: String, email: String?, completion: @escaping (Result<LMLoginResponse, Error>) -> Void) {
        LMApiService.shared.loginWithApple(appleUid: appleUid, idToken: idToken, email: email) { [weak self] response in
            if response.requestSuccess, let data = response.value {
                // 使用新的saveLoginInfo方法，直接传入订阅信息
                self?.saveLoginInfo(
                    accessToken: data.accessToken,
                    refreshToken: data.refreshToken,
                    user: data.user,
                    subscriptionType: data.subscriptionType,
                    inspirePoints: data.inspirePoints
                )
                
                LMLogger.log("✅ Apple login success")
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
                // 如果当前有用户，更新用户信息
                if var currentUser = self?.currentUser {
                    currentUser.username = data.username
                    currentUser.email = data.email
                    self?.updateUser(currentUser)
                }
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
    
    /// 修改密码（需要旧密码）
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
    
    /// 重置密码（忘记密码，不需要旧密码）
    func resetPassword(email: String, newPassword: String, completion: @escaping (Result<Void, Error>) -> Void) {
        LMApiService.shared.resetPassword(email: email, newPassword: newPassword) { response in
            if response.requestSuccess {
                completion(.success(()))
            } else {
                let error = NSError(
                    domain: "UserManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Password reset failed"]
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
                        userModel = userInfo.toLMUser()
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
