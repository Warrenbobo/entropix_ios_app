//
//  LMLaunchSplashPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

class LMLaunchSplashPage: UIViewController {
    
    public weak var window: UIWindow?
    
    /// 创建开屏界面
    public static func createLaunchContentViews() -> UIView {
        let splashView = UIView(frame: UIScreen.main.bounds)
        splashView.backgroundColor = AppTheme.ThemeColor.background
        // 图标
        let iconView = UIImageView()
        iconView.image = UIImage(named: "")
        splashView.addSubview(iconView)
        
        // 文本
        let bottomTextView = UIImageView()
        bottomTextView.image = UIImage(named: "")
        splashView.addSubview(bottomTextView)
        return splashView
    }
    
    private var showPrivacy: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addSplashViews()
        loadAppDataAndCheckVersion()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true,
                                                     animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false,
                                                     animated: animated)
    }
    
    /// 进入APP时的基础配置
    private func loadAppDataAndCheckVersion() {
        LMPackageManager.setup()
        checkPrivacyPermissionState()
    }
    
    /// 检查用户是否已经同意隐私授权
    private func checkPrivacyPermissionState() {
        // 检查是否显示过隐私协议
        loadPackageDataAndEnterHomePage()
    }
    
    /// 加载配置信息并进入首页
    private func loadPackageDataAndEnterHomePage() {
        LMUserManager.loadCachedUserModelData()
        var rootController: UIViewController = LMNewInstallerPage()
        if LMUserManager.isSignIn {
            rootController = LMMinePage()
        }
        window?.rootViewController = LMNavigationWrapper(rootViewController: rootController)
    }
    
    /// 添加界面
    private func addSplashViews() {
        
    }
    
    /// 点击隐私协议的取消按钮
    private func userTapedRejectButton() {
        abort()
    }
    
    /// 用户点击同意进入下一步
    private func userTapedAgreementButton() {
        
        loadPackageDataAndEnterHomePage()
    }
    
    /// 跳转用户协议
    private func userServicesTextOnTap() {
        
    }
    
    /// 跳转隐私政策
    private func userPrivacyTextOnTap() {
       
    }
}
