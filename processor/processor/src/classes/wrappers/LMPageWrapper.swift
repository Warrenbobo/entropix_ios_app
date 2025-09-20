//
//  LMPageWrapper.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit

class LMPageWrapper: UIViewController {
    
    public var interactivePopGestureRecognizerEnabled: Bool = true
    
    /// 界面自适应调整
    public func viewAdapter(_ scrollView: UIScrollView) {
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
    }
    
    /// 返回按钮点击事件
    @objc public func backButtonItemOnTap() {
        if navigationController?.presentingViewController != nil {
            dismiss(animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    /// 设置界面吧标题颜色为白色
    public func changeTitleTextToWhiteTheme() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowImage = UIImage()
        appearance.shadowColor = nil
        appearance.titleTextAttributes = [.font: UIFont.systemFont(ofSize: 18, weight: .medium),
                                         .foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        backButtonCreated()
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    /// 创建返回按钮
    private func backButtonCreated() {
        guard navigationController != nil else {
            return
        }
        let backButtonItem = UIBarButtonItem(image: UIImage(named: "back_arrow")?.withRenderingMode(.alwaysOriginal),
                                             style: .done,
                                             target: self,
                                             action: #selector(backButtonItemOnTap))
        navigationItem.leftBarButtonItem = backButtonItem
    }
}

extension LMPageWrapper: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return interactivePopGestureRecognizerEnabled
    }
}
