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
        titleLabel.text = "Inspire Me"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = UIColor.white
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)
    }
    
    private func setupBottomInfoBar() {
        // 配置 StackView
        bottomStackView.axis = .horizontal
        bottomStackView.alignment = .center
        bottomStackView.spacing = 6
        bottomStackView.isUserInteractionEnabled = true
        addSubview(bottomStackView)
        
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
        
        // 问号按钮
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
        
        // 顶部标题
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        // 底部信息栏
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
        if isEnabledForCamera {
            self.isHidden = false
        } else {
            self.isHidden = true
        }
    }
}

extension LMInspireMeButtonView {
    
    @objc private func handleInspireButtonTapped() {
        // 如果因为前摄而禁用，通知代理显示提示
        if !isEnabledForCamera {
            delegate?.inspireMeButtonViewDidTapDisabledButton()
            return
        }
        
        guard inspirePoints > 0 else { return }
        delegate?.inspireMeButtonViewDidTapButton()
    }
    
    @objc private func handleQuestionButtonTapped() {
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
    func setInspireMeButtonEnabled(_ enabled: Bool) {
        isEnabledForCamera = enabled
        updateInspireButtonAppearance()
    }
}
