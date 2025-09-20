//
//  LMPageWrapper.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit

class LMPageWrapper: UIViewController {
    
    public var contentView: UIView { return offsetContentView }
    public var interactivePopGestureRecognizerEnabled: Bool = true
    
    /// 界面自适应调整
    public func viewAdapter(_ scrollView: UIScrollView) {
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
    }
    
    /// 是否隐藏顶部渐变色背景区域
    public var isHiddenGradientTopView: Bool {
        set {
            gradientBackgroundView?.isHidden = newValue
        }
        get {
            return gradientBackgroundView?.isHidden ?? false
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
    
    private lazy var offsetContentView: UIView = {
        let contentView = UIView(frame: CGRect(origin: CGPoint(x: 0,
                                                               y: AppTheme.Screen.navigatorHeight),
                                               size: CGSize(width: AppTheme.Screen.width,
                                                            height: AppTheme.Screen.height - AppTheme.Screen.navigatorHeight)))
        return contentView
    }()
    private var gradientBackgroundView: UIImageView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupContentAppearance()
        backButtonCreated()
        setupContentViewBackgroundStyles()
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
    
    /// 界面背景设置
    private func setupContentViewBackgroundStyles() {
        view.backgroundColor = AppTheme.ThemeColor.background
        let gradientView = UIImageView(frame: CGRect(origin: .zero,
                                                size: CGSize(width: AppTheme.Screen.width, height: 216 + AppTheme.Screen.safeAreaTop)))
        gradientView.image = UIImage(named: "view_header_bg")
        view.addSubview(gradientView)
        gradientBackgroundView = gradientView
        
        view.addSubview(offsetContentView)
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
