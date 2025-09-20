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
        appearance.configureWithTransparentBackground()
        appearance.shadowImage = UIImage()
        appearance.shadowColor = nil
        appearance.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 18, weight: .medium),
                                          .foregroundColor: AppTheme.ThemeColor.text]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if children.count > 0 {
            viewController.hidesBottomBarWhenPushed = true
        }
        super.pushViewController(viewController, animated: animated)
    }
}


