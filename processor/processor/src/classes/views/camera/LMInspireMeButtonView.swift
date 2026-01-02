//
//  LMInspireMeButtonView.swift
//  processor
//
//  Created by muz on 2025/1/15.
//

import UIKit
import SnapKit

protocol LMInspireMeButtonViewDelegate: AnyObject {
    func inspireMeButtonViewDidTapButton()
    func inspireMeButtonViewDidTapQuestionButton()
    func inspireMeButtonViewDidTapDisabledButton() // 前摄时点击按钮的回调
}

class LMInspireMeButtonView: UIView {
    
    // 背景按钮
    private let inspireButton = UIButton()
    
    // 顶部标题
    private let titleLabel = UILabel()
    
    // 底部信息栏（星星 + 次数 + 问号）
    private let bottomStackView = UIStackView()
    private let starImageView = UIImageView()
    private let pointsLabel = UILabel()
    private let questionButton = UIButton()
    
    weak var delegate: LMInspireMeButtonViewDelegate?
    private var inspirePoints = 1
    private var isEnabledForCamera = true // 是否因为相机状态而启用（前摄时为false）
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupComponents()
        configureLayoutConstraints()
        configureDefaultStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Hit Testing
    /// 重写 hitTest 方法，确保问号按钮可以响应点击，其他区域传递给 inspireButton
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 首先检查点击是否在视图范围内
        guard self.point(inside: point, with: event) else {
            return nil
        }
        
        // 检查是否点击了问号按钮区域（扩大触摸区域）
        let questionButtonFrame = questionButton.convert(questionButton.bounds, to: self)
        let expandedQuestionFrame = questionButtonFrame.insetBy(dx: -8, dy: -8) // 扩大触摸区域
        
        if expandedQuestionFrame.contains(point) {
            return questionButton
        }
        
        // 其他区域返回 inspireButton
        return inspireButton
    }
    
}

extension LMInspireMeButtonView {
    
    private func setupComponents() {
        setupBackgroundButton()
        setupTitleLabel()
        setupBottomInfoBar()
    }
    
    private func setupBackgroundButton() {
        addSubview(inspireButton)
        
        // 设置渐变背景
        layer.cornerRadius = 20
        layer.masksToBounds = true
        let gradientImage = UIImage.gradientImage(
            size: CGSize(width: AppTheme.Screen.width, height: 120),
            colors: [UIColor.hexColor("#6680E6").cgColor,
                    UIColor.hexColor("#9966E6").cgColor],
            direction: .vertical
        )
        inspireButton.setBackgroundImage(gradientImage, for: .normal)
        inspireButton.adjustsImageWhenHighlighted = false
        inspireButton.addTarget(self, action: #selector(handleInspireButtonTapped), for: .touchUpInside)
    }
    
    private func setupTitleLabel() {
        titleLabel.text = LMText.camera.inspireMeButton
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = UIColor.white
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        // 添加到 inspireButton 上，确保不会拦截触摸事件
        inspireButton.addSubview(titleLabel)
    }
    
    private func setupBottomInfoBar() {
        // 配置 StackView
        bottomStackView.axis = .horizontal
        bottomStackView.alignment = .center
        bottomStackView.spacing = 6
        // 禁用 stackView 的交互，让触摸事件穿透到 inspireButton
        bottomStackView.isUserInteractionEnabled = false
        // 添加到 inspireButton 上
        inspireButton.addSubview(bottomStackView)
        
        // 星星图标
        starImageView.image = UIImage(named: "star_fill")
        starImageView.isUserInteractionEnabled = false
        bottomStackView.addArrangedSubview(starImageView)
        
        // 次数文字
        pointsLabel.text = "-\(inspirePoints)"
        pointsLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        pointsLabel.textColor = UIColor.white
        pointsLabel.textAlignment = .center
        pointsLabel.isUserInteractionEnabled = false
        bottomStackView.addArrangedSubview(pointsLabel)
        
        // 问号按钮 - 需要单独处理点击事件
        questionButton.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        questionButton.tintColor = UIColor.white
        questionButton.isUserInteractionEnabled = true
        questionButton.addTarget(self, action: #selector(handleQuestionButtonTapped), for: .touchUpInside)
        bottomStackView.addArrangedSubview(questionButton)
        
        // 设置星星图标尺寸
        starImageView.snp.makeConstraints { make in
            make.width.height.equalTo(18)
        }
        
        // 设置问号按钮尺寸（增加触摸区域）
        questionButton.snp.makeConstraints { make in
            make.width.height.equalTo(32)
        }
    }
    
    private func configureLayoutConstraints() {
        // 背景按钮填充整个视图
        inspireButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 顶部标题（相对于 inspireButton）
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        // 底部信息栏（相对于 inspireButton）
        bottomStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(1)
            make.centerX.equalToSuperview().offset(6)
        }
    }
    
    private func configureDefaultStyles() {
        backgroundColor = UIColor.clear
        updateInspireButtonAppearance()
    }
    
    private func updateInspireButtonAppearance() {
//        pointsLabel.text = "-\(inspirePoints > 99 ? "99+" : "\(inspirePoints)")"
//        let hasPoints = inspirePoints > 0
        
        // 注意：这里只根据 isEnabledForCamera 更新按钮的视觉状态
        // 实际的 isHidden 状态由 LMCameraPage 根据 currentCameraState 控制
        // 不要在这里直接设置 isHidden，避免覆盖页面级别的隐藏状态
        
        // 更新按钮的透明度来表示启用/禁用状态
        inspireButton.alpha = isEnabledForCamera ? 1.0 : 0.5
    }
}

extension LMInspireMeButtonView {
    
    @objc private func handleInspireButtonTapped() {
        // 如果按钮被隐藏，不响应任何点击
        guard !isHidden else { return }
        
        // 如果因为前摄而禁用，通知代理显示提示
        if !isEnabledForCamera {
            delegate?.inspireMeButtonViewDidTapDisabledButton()
            return
        }
        
        guard inspirePoints > 0 else { return }
        delegate?.inspireMeButtonViewDidTapButton()
    }
    
    @objc private func handleQuestionButtonTapped() {
        // 如果按钮被隐藏，不响应任何点击
        guard !isHidden else { return }
        delegate?.inspireMeButtonViewDidTapQuestionButton()
    }
}

extension LMInspireMeButtonView {
    
    func updateInspirePointsCount(_ points: Int) {
        inspirePoints = max(0, points)
        updateInspireButtonAppearance()
    }
    
    func decrementInspirePointsCount() {
        updateInspireButtonAppearance()
//        if inspirePoints > 0 {
//            inspirePoints -= 1
//            
//        }
    }
    
    func getCurrentInspirePoints() -> Int {
        return inspirePoints
    }
    
    /// 设置 Inspire Me 按钮的启用/禁用状态（基于相机状态）
    /// - Parameter enabled: true 启用（后摄），false 禁用（前摄）
    /// 注意：此方法只控制按钮的交互状态，不控制可见性
    /// 可见性由 LMCameraPage 根据 currentCameraState 控制
    func setInspireMeButtonEnabled(_ enabled: Bool) {
        isEnabledForCamera = enabled
        updateInspireButtonAppearance()
    }
}
