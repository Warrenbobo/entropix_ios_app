//
//  LMPageWrapper.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit

enum LMMineNavigationLayoutMode {
    case safeAreaInset
    case manualNavigatorHeightOffset
}

class LMPageWrapper: UIViewController {
    
    public var interactivePopGestureRecognizerEnabled: Bool = true
    var usesMineNavigationBarStyle: Bool { false }
    var mineNavigationLayoutMode: LMMineNavigationLayoutMode { .safeAreaInset }
    
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
            mineNavigationBar.setTitle(barTitle)
        }
    }
    
    private let titleLabel = UILabel()
    let mineNavigationBar = LMProcessorTopBar()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        configureNavigationTitleLabel()
        if usesMineNavigationBarStyle {
            setupMineNavigationBar()
        } else {
            backButtonCreated()
            setupCustomNavigationBarTitleView()
        }
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if usesMineNavigationBarStyle {
            navigationController?.setNavigationBarHidden(true, animated: animated)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if usesMineNavigationBarStyle {
            view.bringSubviewToFront(mineNavigationBar)
        }
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
        barButton.backgroundColor = .clear
        barButton.contentHorizontalAlignment = .leading
        barButton.contentVerticalAlignment = .center
        barButton.imageView?.contentMode = .scaleAspectFit
        if usesMineNavigationBarStyle {
            barButton.imageEdgeInsets = LMProfileNavigationMetrics.backButtonImageInsets
        } else {
            barButton.imageEdgeInsets = UIEdgeInsets(top: 13, left: 0, bottom: 13, right: 26)
        }
        if #available(iOS 15.0, *) {
            barButton.preferredBehavioralStyle = .pad
        }
        barButton.addTarget(self,
                            action: #selector(backButtonItemOnTap),
                            for: .touchUpInside)
        
        let backItem = UIBarButtonItem(customView: barButton)
        navigationItem.leftBarButtonItem = backItem
    }
    
    /// 创建自定义的导航栏标题
    private func setupCustomNavigationBarTitleView() {
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
    
    private func configureNavigationTitleLabel() {
        titleLabel.font = LMProfileNavigationMetrics.titleFont
        titleLabel.textColor = usesMineNavigationBarStyle ? LMProfileNavigationMetrics.titleColor : .black
        titleLabel.textAlignment = .left
        titleLabel.lineBreakMode = .byTruncatingTail
    }
    
    private func setupMineNavigationBar() {
        view.addSubview(mineNavigationBar)
        mineNavigationBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(AppTheme.Screen.navigatorHeight)
        }
        
        mineNavigationBar.setTitle(barTitle)
        mineNavigationBar.setBackButtonHidden(false)
        mineNavigationBar.setTrailingButtonHidden(true)
        mineNavigationBar.setBackButtonAction { [weak self] in
            self?.backButtonItemOnTap()
        }
        configureMineNavigationBar(mineNavigationBar)
        
        switch mineNavigationLayoutMode {
        case .safeAreaInset:
            additionalSafeAreaInsets.top = 44
        case .manualNavigatorHeightOffset:
            additionalSafeAreaInsets.top = 0
        }
    }
    
    func configureMineNavigationBar(_ navigationBar: LMProcessorTopBar) {
    }
}

extension LMPageWrapper: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return interactivePopGestureRecognizerEnabled
    }
}
