//
//  LMNavigationWrapper.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit

class LMNavigationWrapper: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupContentAppearance()
    }
    
    /// 界面初始设置
    private func setupContentAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.shadowImage = UIImage()
        appearance.shadowColor = nil
        
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: AppTheme.ThemeColor.text,
        ]
        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: AppTheme.ThemeColor.text,
        ]
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.prefersLargeTitles = false
        
        navigationBar.backgroundColor = AppTheme.ThemeColor.background
        navigationBar.tintColor = AppTheme.ThemeColor.buttonText
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if children.count > 0 {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }
}


extension LMNavigationWrapper {
    
    /// 设置导航栏标题对齐方式
    func setNavigationBarTitleAlignment(_ alignment: NSTextAlignment) {
        let appearance = navigationBar.standardAppearance.copy()
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        
        var titleAttributes = appearance.titleTextAttributes
        titleAttributes[.paragraphStyle] = paragraphStyle
        appearance.titleTextAttributes = titleAttributes
        
        var largeTitleAttributes = appearance.largeTitleTextAttributes
        largeTitleAttributes[.paragraphStyle] = paragraphStyle
        appearance.largeTitleTextAttributes = largeTitleAttributes
        
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
    }
    
    /// 设置导航栏标题字体和颜色
    func setNavigationBarTitleStyle(font: UIFont, color: UIColor) {
        let appearance = navigationBar.standardAppearance.copy()
        
        let existingParagraphStyle = (appearance.titleTextAttributes[.paragraphStyle] as? NSParagraphStyle) ?? NSParagraphStyle()
        
        appearance.titleTextAttributes = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: existingParagraphStyle
        ]
        
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
    }
    
    /// 设置导航栏背景透明度
    func setNavigationBarBackgroundAlpha(_ alpha: CGFloat) {
        let appearance = navigationBar.standardAppearance.copy()
        
        if alpha < 1.0 {
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = AppTheme.ThemeColor.background.withAlphaComponent(alpha)
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = AppTheme.ThemeColor.background
        }
        
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
    }
    
    func resetNavigationBarAppearanceToDefault() {
        setupContentAppearance()
    }
}


extension LMNavigationWrapper {
    
    func configureLeftAlignedTitle() {
        setNavigationBarTitleAlignment(.left)
    }
    
    func configureCenteredTitle() {
        setNavigationBarTitleAlignment(.center)
    }
    
    func configureRightAlignedTitle() {
        setNavigationBarTitleAlignment(.right)
    }
    
    func configureTransparentNavigationBar() {
        setNavigationBarBackgroundAlpha(0.0)
    }
    
    func configureTranslucentNavigationBar() {
        setNavigationBarBackgroundAlpha(0.8)
    }
    
    func configureOpaqueNavigationBar() {
        setNavigationBarBackgroundAlpha(1.0)
    }
}

extension LMNavigationWrapper {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupContentAppearance()
    }
    
    override func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        configureBottomBarHidingBehavior()
    }
    
    private func configureBottomBarHidingBehavior() {
        for (index, viewController) in viewControllers.enumerated() {
            if index > 0 {
                viewController.hidesBottomBarWhenPushed = true
            }
        }
    }
}
