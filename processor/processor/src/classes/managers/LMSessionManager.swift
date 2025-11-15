//
//  LMSessionManager.swift
//  processor
//
//  会话管理器 - 管理用户会话和自动登出
//

import Foundation
import UIKit

class LMSessionManager {
    
    // MARK: - Singleton
    static let shared = LMSessionManager()
    private init() {}
    
    // MARK: - Properties
    private var isValidating = false
    
    // MARK: - Session Validation
    
    /// 验证会话有效性
    func validateSession(completion: @escaping (Bool, String?) -> Void) {
        guard !isValidating else {
            LMLogger.log("⚠️ Session validation already in progress")
            return
        }
        
        guard LMUserManager.shared.isLoggedIn else {
            LMLogger.log("⚠️ User not logged in, skip session validation")
            completion(false, "not_logged_in")
            return
        }
        
        isValidating = true
        
        LMUserManager.shared.validateSession { [weak self] result in
            self?.isValidating = false
            
            switch result {
            case .success:
                LMLogger.log("✅ Session valid")
                completion(true, nil)
                
            case .failure(let error):
                let nsError = error as NSError
                let reason: String
                
                if nsError.code == 401 {
                    reason = "token_invalid"
                } else if nsError.domain == "device_mismatch" {
                    reason = "device_mismatch"
                } else {
                    reason = "unknown"
                }
                
                LMLogger.log("❌ Session invalid: \(reason)")
                completion(false, reason)
            }
        }
    }
    
    /// 自动登出处理
    func handleAutoLogout(reason: String) {
        LMLogger.log("🚪 Auto logout triggered, reason: \(reason)")
        
        // 清理本地登录信息（保留语言偏好）
        LMUserManager.shared.clearLoginInfo()
        
        // 显示提示信息
        DispatchQueue.main.async {
            self.showSessionExpiredAlert()
        }
    }
    
    /// 应用启动时检查会话
    func checkSessionOnAppLaunch() {
        guard LMUserManager.shared.isLoggedIn else {
            LMLogger.log("📱 App launched, user not logged in")
            return
        }
        
        LMLogger.log("📱 App launched, validating session...")
        
        validateSession { [weak self] isValid, reason in
            if !isValid {
                self?.handleAutoLogout(reason: reason ?? "unknown")
            }
        }
    }
    
    /// 应用进入前台时检查会话
    func checkSessionOnAppDidBecomeActive() {
        guard LMUserManager.shared.isLoggedIn else {
            return
        }
        
        LMLogger.log("📱 App became active, validating session...")
        
        validateSession { [weak self] isValid, reason in
            if !isValid {
                self?.handleAutoLogout(reason: reason ?? "unknown")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func showSessionExpiredAlert() {
        guard let topViewController = getTopViewController() else {
            return
        }
        
        let alert = UIAlertController(
            title: LMText.auth.sessionExpired,
            message: LMText.auth.pleaseSignInAgain,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LMText.common.ok, style: .default) { _ in
            // 跳转到登录页面
            self.navigateToLoginPage()
        })
        
        topViewController.present(alert, animated: true)
    }
    
    private func navigateToLoginPage() {
        // 获取当前的根视图控制器
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return
        }
        
        // 如果是TabBarController，切换到Profile页面
        if let tabBarController = rootViewController as? UITabBarController {
            // 假设Profile是最后一个tab
            tabBarController.selectedIndex = tabBarController.viewControllers?.count ?? 0 - 1
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        return getTopViewController(from: rootViewController)
    }
    
    private func getTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return getTopViewController(from: presented)
        }
        
        if let navigationController = viewController as? UINavigationController {
            if let visible = navigationController.visibleViewController {
                return getTopViewController(from: visible)
            }
        }
        
        if let tabBarController = viewController as? UITabBarController {
            if let selected = tabBarController.selectedViewController {
                return getTopViewController(from: selected)
            }
        }
        
        return viewController
    }
}
