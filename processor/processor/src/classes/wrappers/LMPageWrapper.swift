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
            let routeCount = navigationController?.children.count ?? 0
            if routeCount <= 1 {
                dismiss(animated: true)
            } else {
                navigationController?.popViewController(animated: true)
            }
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
    
    /// 设置导航栏标题
    public var barTitle: String = "" {
        didSet {
            titleLabel.text = barTitle
        }
    }
    
    private let titleLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        backButtonCreated()
        setupCustomNavigationBarTitleView()
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
        let barButton = UIButton(type: .custom)
        barButton.frame = CGRect(origin: .zero,
                                 size: CGSize(width: 44,
                                              height: 44))
        barButton.setImage(UIImage(named: "left_arrow_dark")?.withRenderingMode(.alwaysOriginal),
                           for: .normal)
        barButton.imageView?.contentMode = .scaleAspectFill
        barButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        barButton.addTarget(self,
                            action: #selector(backButtonItemOnTap),
                            for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: barButton)
    }
    
    /// 创建自定义的导航栏标题
    private func setupCustomNavigationBarTitleView() {
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .black
        let titleView = LMNavigationTitleView(frame: CGRect(origin: .zero,
                                                            size: CGSize(width: AppTheme.Screen.width,
                                                                         height: 44)))
        titleView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(-10)
            make.top.bottom.trailing.equalToSuperview()
        }
        navigationItem.titleView = titleView
    }
}

extension LMPageWrapper: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return interactivePopGestureRecognizerEnabled
    }
}
