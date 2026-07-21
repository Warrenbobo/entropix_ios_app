//
//  LMUserManager.swift
//  processor
//
//  User authentication and session management
//  Updated: 2025-01-20 - 统一使用 LMApiCallback 作为回调类型
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
    
    // 用户数据变化通知
    static let userDataDidChangeNotification = Notification.Name("LMUserDataDidChange")
    
    var isLoggedIn: Bool {
        return accessToken != nil
    }
    
    // MARK: - Authentication Methods
    
    /// 保存登录信息
    func saveLoginInfo(accessToken: String,
                       refreshToken: String,
                       user: LMUserModel?) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        updateUser(user)
    }
    
    /// 清除登录信息
    func clearLoginInfo() {
        accessToken = nil
        refreshToken = nil
        // 同步清除静态变量 userModel
        LMUserManager.userModel = nil
        
        LMLogger.log("✅ User logged out")
    }
    
    /// 更新用户信息
    func updateUser(_ user: LMUserModel?) {
        // 同步更新静态变量 userModel
        LMUserManager.userModel = user
        // 发送用户数据变化通知
        NotificationCenter.default.post(name: Self.userDataDidChangeNotification, object: nil)
        LMLogger.log("✅ User info updated")
    }
    
    /// 更新Inspire Points
    func updateInspirePoints(_ points: Int) {
        if var user = LMUserManager.userModel {
            user.inspirePoints = points
            // 同步更新静态变量 userModel
            LMUserManager.userModel = user
            LMLogger.log("✅ Inspire points updated: \(points)")
        }
    }
    
    /// 增加Inspire Points
    func addInspirePoints(_ points: Int) {
        if var user = LMUserManager.userModel {
            user.inspirePoints = (user.inspirePoints ?? 0) + points
            // 同步更新静态变量 userModel
            LMUserManager.userModel = user
            LMLogger.log("✅ Inspire points added: +\(points), total: \(user.inspirePoints ?? 0)")
        }
    }
    
    /// 减少Inspire Points
    func deductInspirePoints(_ points: Int) -> Bool {
        guard var user = LMUserManager.userModel else { return false }
        guard (user.inspirePoints ?? 0) >= points else { return false }
        
        user.inspirePoints = (user.inspirePoints ?? 0) - points
        // 同步更新静态变量 userModel
        LMUserManager.userModel = user
        LMLogger.log("✅ Inspire points deducted: -\(points), remaining: \(user.inspirePoints ?? 0)")
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
    func login(identifier: String, password: String, completion: @escaping LMApiCallback<LMLoginResponse>) {
        // 正常登录流程
        LMApiService.shared.login(identifier: identifier, password: password) { [weak self] response in
            if response.requestSuccess, let data = response.value {
                // 使用新的saveLoginInfo方法，直接传入订阅信息
                self?.saveLoginInfo(
                    accessToken: data.accessToken ?? "",
                    refreshToken: data.refreshToken ?? "",
                    user: data.user)
            }
            completion(response)
        }
    }
    
    /// 注册（邮箱+密码）
    func register(username: String, email: String, password: String, completion: @escaping LMApiCallback<LMUserModel>) {
        LMApiService.shared.register(username: username, email: email, password: password) { response in
            completion(response)
        }
    }
    
    /// Apple 登录（统一使用 LMLoginResponse）
    func loginWithApple(appleUid: String, idToken: String, email: String?, completion: @escaping LMApiCallback<LMLoginResponse>) {
        LMApiService.shared.loginWithApple(appleUid: appleUid, idToken: idToken) { [weak self] response in
            if response.requestSuccess, let data = response.value {
                // 使用新的saveLoginInfo方法，直接传入订阅信息
                self?.saveLoginInfo(
                    accessToken: data.accessToken ?? "",
                    refreshToken: data.refreshToken ?? "",
                    user: data.user)
                
                LMLogger.log("✅ Apple login success")
            }
            completion(response)
        }
    }
    

    
    /// 登出
    func logout(completion: @escaping LMApiCallback<LMEmptyModel>) {
        LMApiService.shared.logout { [weak self] response in
            if response.requestSuccess {
                self?.clearLoginInfo()
            }
            completion(response)
        }
    }
    
    /// 获取用户信息
    func fetchUserInfo(completion: @escaping LMApiCallback<LMUserModel>) {
        LMApiService.shared.getUserInfo { [weak self] response in
            if response.requestSuccess, let data = response.value {
                self?.updateUser(data)
            }
            completion(response)
        }
    }
    
    /// 修改密码（需要旧密码）
    func changePassword(oldPassword: String, newPassword: String, completion: @escaping LMApiCallback<LMEmptyModel>) {
        LMApiService.shared.changePassword(oldPassword: oldPassword, newPassword: newPassword) { response in
            completion(response)
        }
    }
    
    /// 重置密码（忘记密码，不需要旧密码）
    /// 注意：此功能需要后端支持，目前 API 未实现
    func resetPassword(email: String, newPassword: String, completion: @escaping LMApiCallback<LMEmptyModel>) {
        // TODO: 等待后端实现 resetPassword API
        LMLogger.log("⚠️ resetPassword API not implemented yet")
        let errorResponse = LMApiResponseModel<LMEmptyModel>()
        completion(errorResponse)
    }
    
    /// 领取免费试用（14天）
    /// 首次调用会立即下发 14 天试用订阅；已领取或已有正式订阅的用户会返回相应错误提示
    func claimFreeTrial(completion: @escaping LMApiCallback<LMFreeTrialResponse>) {
        LMApiService.shared.claimFreeTrial { [weak self] response in
            if response.requestSuccess, let data = response.value {
                // 更新用户订阅状态
                if let granted = data.granted, granted,
                   let subscription = data.subscription {
                    if var user = LMUserManager.userModel {
                        user.subscription = subscription.planType
                        user.subscriptionEndDate = subscription.endDate
                        self?.updateUser(user)
                        LMLogger.log("✅ Free trial claimed successfully: \(subscription.planType ?? "trial")")
                    }
                }
            }
            completion(response)
        }
    }
    
    /// 当前是否为已登陆用户
    static var isSignIn: Bool {
        return userModel != nil
    }

    /// Initializes a mock user for offline demo mode.
    static func setupOfflineDemoUser() {
        let demoUser = LMUserModel(
            userId: "demo_user",
            username: "Demo User",
            nickname: "Demo",
            email: "demo@framaist.com",
            avatar: nil,
            subscription: SubscriptionType.plus.rawValue,
            subscriptionEndDate: nil,
            inspirePoints: 9999,
            isGuest: false,
            birthDate: nil,
            language: nil
        )
        shared.updateUser(demoUser)
        LMLogger.log("Offline demo user configured")
    }
    
    
    /// 用户数据（仅内存缓存，不持久化）
    static var userModel: LMUserModel?
    
    /// 加载缓存的用户数据：先刷新 Token，然后获取最新用户信息
    static func loadCachedUserModelData(completion: ((Bool) -> Void)? = nil) {
        // 检查是否有登录状态
        guard LMUserManager.shared.isLoggedIn else {
            LMLogger.log("⚠️ No login session found, skipping user data load")
            completion?(false)
            return
        }
        LMLogger.log("🔄 Loading user data: refreshing token first...")
        LMSessionManager.shared.validateSession { tokenValidate, message in
            if (tokenValidate) {
                LMLogger.log("✅ Token refreshed successfully")
                LMUserManager.shared.fetchUserInfo { userResponse in
                    if userResponse.requestSuccess, let userInfo = userResponse.value {
                        userModel = userInfo
                        LMLogger.log("✅ User data loaded and updated in memory")
                        completion?(true)
                    } else {
                        LMLogger.log("❌ Failed to fetch user info: \(userResponse.message ?? "Unknown error")")
                        completion?(false)
                    }
                }
            } else {
                LMLogger.log("❌ Failed to refresh token: \(message ?? "Unknown error")")
                // Token 刷新失败，可能需要重新登录
                LMUserManager.shared.clearLoginInfo()
                completion?(false)
            }
        }
    }
}
