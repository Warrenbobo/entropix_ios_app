//
//  LMAuthGuard.swift
//  processor
//
//  游客用户登录拦截管理器
//  当游客用户（is_guest = true）尝试访问需要登录的功能时，弹出登录页面
//

import UIKit

class LMAuthGuard {
    
    // MARK: - Singleton
    static let shared = LMAuthGuard()
    private init() {}
    
    // MARK: - Properties
    
    /// 检查当前用户是否为游客
    var isGuestUser: Bool {
        guard let user = LMUserManager.userModel else {
            // 没有用户信息，视为游客
            return true
        }
        
        // 检查用户是否为游客（根据实际API返回的字段判断）
        // 如果没有登录token，也视为游客
        return user.isGuest ?? true
    }
    
    // MARK: - Public Methods
    
    /// 检查是否需要登录，如果是游客则弹出登录页
    /// - Parameters:
    ///   - from: 当前视图控制器
    ///   - action: 需要登录才能执行的操作描述（用于日志）
    ///   - completion: 登录成功后的回调（可选）
    /// - Returns: 如果是游客返回false，已登录返回true
    @discardableResult
    func requireLogin(from viewController: UIViewController,
                     action: String,
                     completion: (() -> Void)? = nil) -> Bool {
        
        if isGuestUser {
            LMLogger.log("🚫 Guest user attempting to: \(action)")
            LMAppleAuthManager.shared.signInWithApple { result in
                LMLogger.log("✅ Logged in user finished, guest value is: \(self.isGuestUser)")
                completion?()
            }
            return false
        }
        
        LMLogger.log("✅ Logged in user can: \(action)")
        return true
    }
    
    /// 显示登录页面
    /// - Parameters:
    ///   - viewController: 当前视图控制器
    ///   - completion: 登录成功后的回调
    private func showLoginPage(from viewController: UIViewController,
                              completion: (() -> Void)? = nil) {
        
        // 如果有completion，监听登录成功通知
        if let completion = completion {
            // 添加登录成功监听
            NotificationCenter.default.addObserver(
                forName: LMUserManager.userDataDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak viewController] _ in
                // 检查是否登录成功
                if !LMAuthGuard.shared.isGuestUser {
                    LMLogger.log("✅ User logged in successfully, executing completion")
                    completion()
                    
                    // 移除监听
                    NotificationCenter.default.removeObserver(
                        viewController as Any,
                        name: LMUserManager.userDataDidChangeNotification,
                        object: nil
                    )
                }
            }
        }
        
    }
    
    // MARK: - Convenience Methods
    
    /// 快速检查并拦截游客用户（用于按钮点击等场景）
    /// - Parameters:
    ///   - viewController: 当前视图控制器
    ///   - action: 操作描述
    /// - Returns: 是否允许继续执行
    func checkAndBlock(from viewController: UIViewController, action: String) -> Bool {
        return requireLogin(from: viewController, action: action)
    }
}

// MARK: - UIViewController Extension
extension UIViewController {
    
    /// 便捷方法：检查登录状态并在需要时弹出登录页
    /// - Parameters:
    ///   - action: 操作描述
    ///   - completion: 登录成功后的回调
    /// - Returns: 是否已登录
    @discardableResult
    func requireLogin(action: String, completion: (() -> Void)? = nil) -> Bool {
        return LMAuthGuard.shared.requireLogin(
            from: self,
            action: action,
            completion: completion
        )
    }
}
