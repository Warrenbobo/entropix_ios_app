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
        appearance.backgroundEffect = nil
        appearance.backgroundColor = AppTheme.ThemeColor.background
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

        let buttonAppearance = createPlainBarButtonAppearance()
        appearance.buttonAppearance = buttonAppearance
        appearance.backButtonAppearance = buttonAppearance.copy()
        appearance.prominentButtonAppearance = buttonAppearance.copy()

        applyNavigationBarAppearance(appearance)
        navigationBar.prefersLargeTitles = false
        
        navigationBar.isTranslucent = false
        navigationBar.backgroundColor = AppTheme.ThemeColor.background
        navigationBar.tintColor = AppTheme.ThemeColor.buttonText
        if #available(iOS 16.0, *) {
            navigationBar.preferredBehavioralStyle = .pad
        }
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if children.count > 0 {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }
}


extension LMNavigationWrapper {
    
    private func createPlainBarButtonAppearance() -> UIBarButtonItemAppearance {
        let appearance = UIBarButtonItemAppearance(style: .plain)
        [appearance.normal, appearance.highlighted, appearance.disabled, appearance.focused].forEach { state in
            state.backgroundImage = UIImage()
            state.backgroundImagePositionAdjustment = .zero
            state.titleTextAttributes = [
                .foregroundColor: AppTheme.ThemeColor.buttonText
            ]
        }
        return appearance
    }
    
    private func applyNavigationBarAppearance(_ appearance: UINavigationBarAppearance) {
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationBar.compactScrollEdgeAppearance = appearance
        }
    }
    
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
        
        applyNavigationBarAppearance(appearance)
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
        
        applyNavigationBarAppearance(appearance)
    }
    
    /// 设置导航栏背景透明度
    func setNavigationBarBackgroundAlpha(_ alpha: CGFloat) {
        let appearance = navigationBar.standardAppearance.copy()
        
        if alpha < 1.0 {
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = nil
            appearance.backgroundColor = AppTheme.ThemeColor.background.withAlphaComponent(alpha)
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundEffect = nil
            appearance.backgroundColor = AppTheme.ThemeColor.background
        }
        
        applyNavigationBarAppearance(appearance)
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
