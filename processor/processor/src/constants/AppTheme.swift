//
//  AppTheme.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit

struct AppTheme {
    
    /// App主题颜色
    struct ThemeColor {
        
        // 背景色
        static let background = UIColor.white
        
        // 文本颜色
        static let text = UIColor.hexColor("#09244F")
        
        // 灰色文本色
        static let greyText = UIColor.hexColor("#9DA0A5")
        
        // 内容文本颜色
        static let contentText = UIColor.hexColor("#5B7999")
        
        // 链接文本的颜色
        static let linkText = UIColor.hexColor("#7BA9E8")
        
        // 按钮文本颜色
        static let buttonText = UIColor.hexColor("#0A84FF")
        
        // 会员文本颜色
        static let vipText = UIColor.hexColor("#FFE0BA")
        
        // 倒计时颜色
        static let timeText = UIColor.hexColor("#FF453A")
        
        // 占位文字颜色
        static let placeholder = UIColor.hexColor("#B7BAC1")
        
        // 进度条颜色
        static let progress = UIColor.hexColor("#EA0000")
        
        // 阴影颜色
        static let shadow = UIColor.hexColor("#B2CFEB", alpha: 0.4)
        
        // 按钮渐变色
        static let buttonGradient = [UIColor.hexColor("#70BFFF"), AppTheme.ThemeColor.buttonText]
        
        // 高亮颜色
        static let highlight = UIColor.hexColor("#F85C00")
        
        // 深灰色
        static let highGray = UIColor.hexColor("#535458")
        
        // 支付默认色
        static let pay = UIColor.hexColor("#838383")
        
        // 微信高亮文字颜色
        static let payWx = UIColor.hexColor("#35CD68")
        
        // 支付宝高亮文字颜色
        static let payAli = UIColor.hexColor("#3476FE")
        
        // 支付按钮的渐变色
        static let payButtonGradient = [UIColor.hexColor("#FF863C"), UIColor.hexColor("#FE3434"), UIColor.hexColor("#EA2B2B")]
        
        // 协议文本颜色
        static let agreementText = UIColor.hexColor("#9596A6")
        
        // 会员产品名称颜色
        static let productName = UIColor.hexColor("#9F3E00")
        
        // 会员产品内容颜色
        static let productContent = UIColor.hexColor("#BEA493")
        
        // 价格颜色
        static let price = UIColor.hexColor("#FE3434")
        
        // 产品背景色
        static let productBackground = UIColor.hexColor("#FFFEFD")
        
        // 产品选择边框颜色
        static let productBorder = UIColor.hexColor("#C9CACE")
    }
    
    struct Screen {
        
        // 程序的主界面
        static var mainPage: LMMainRootPage?
        
        // 屏幕宽度
        static let width = UIScreen.main.bounds.size.width
        // 屏幕高度
        static let height = UIScreen.main.bounds.size.height
        // 导航栏高度
        static let navigatorHeight = safeAreaTop + 44
        // 状态栏高度
        static let tabBarHeight = safeAreaBottom + 49
        // 安全区域的顶部间距
        static var safeAreaTop: CGFloat {
            guard let window = window() else { return 0 }
            return window.safeAreaInsets.top
        }
        // 安全区域的底部间距
        static var safeAreaBottom: CGFloat {
            guard let window = window() else { return 0 }
            return window.safeAreaInsets.bottom
        }
        // 当前可用导航控制器
        static var navigationController: UINavigationController? {
            return visibleController()?.navigationController 
        }
        
        /// 正在显示的顶层Window
        static func window() -> UIWindow? {
            return LMPackageManager.window
        }
        
        /// 当前可见的最上层controller
        static func visibleController() -> UIViewController? {
            //获取rootController
            var rootController = window()?.rootViewController
            while (true) {
                if rootController?.isKind(of: UINavigationController.self) ?? false {
                    if let navController = rootController as? UINavigationController {
                        rootController = navController.visibleViewController
                    }
                } else if rootController?.isKind(of: UITabBarController.self) ?? false {
                    if let tabBarController = rootController as? UITabBarController {
                        rootController = tabBarController.selectedViewController
                    }
                } else if rootController?.presentedViewController != nil {
                    rootController = rootController?.presentedViewController
                } else {
                    break
                }
            }
            return rootController
        }
        
        /// 显示一个控制器
        static func showAlertController(_ alertController: UIAlertController,
                                        ignoreText: String = "取消") {
            Screen.visibleController()?.present(alertController, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                let actionView = alertController.view.subviews.first?.subviews.last?.subviews.last?.subviews.last?.subviews.first
                if let subView = actionView?.subviews.first as? UIStackView {
                    for hookTextView in subView.arrangedSubviews {
                        if let label = hookTextView.subviews.first?.subviews.first?.subviews.first as? UILabel {
                            if label.text == ignoreText {
                                label.font = .systemFont(ofSize: label.font.pointSize, weight: .regular)
                            } else {
                                label.font = .systemFont(ofSize: label.font.pointSize, weight: .semibold)
                            }
                            label.tintColor = AppTheme.ThemeColor.buttonText
                        }
                    }
                }
            }
        }
    }
    
    struct Toast {
        
        /// 显示toast提示
        static func showText(_ message: String?,
                          duration: TimeInterval = 3.0,
                          completion: ((Bool) -> Void)? = nil) {
            guard let windowView = Screen.window() else { return }
            windowView.hideAllToasts()
            windowView.makeToast(message, duration: duration, position: .center, completion: completion)
        }
    }

}

