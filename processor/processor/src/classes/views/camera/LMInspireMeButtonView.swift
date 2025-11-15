//
//  LMInspireMeButtonView.swift
//  processor
//
//  Created by Kiro on 2025/1/15.
//

import UIKit
import SnapKit

protocol LMInspireMeButtonViewDelegate: AnyObject {
    func inspireMeButtonViewDidTapButton()
    func inspireMeButtonViewDidTapQuestionButton()
}

class LMInspireMeButtonView: UIView {
    
    // Inspire Me 按钮
    private let inspireButton = UIButton()
    private let inspirePointsLabel = UILabel()
    private let questionButton = UIButton()
    
    weak var delegate: LMInspireMeButtonViewDelegate?
    private var inspirePoints = 1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupComponents()
        configureLayoutConstraints()
        configureDefaultStyles()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setupInspireButtonGradient()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupInspireButtonGradient() {
        // 移除现有的渐变层
        inspireButton.layer.sublayers?.removeAll { $0 is CAGradientLayer }
        
        // 添加新的渐变背景 - 紫色渐变
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 130/255, green: 140/255, blue: 220/255, alpha: 1).cgColor,
            UIColor(red: 110/255, green: 110/255, blue: 200/255, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 35
        gradientLayer.frame = inspireButton.bounds
        inspireButton.layer.insertSublayer(gradientLayer, at: 0)
    }
}

extension LMInspireMeButtonView {
    
    private func setupComponents() {
        addSubview(inspireButton)
        
        // Inspire按钮设置 - 渐变背景
        inspireButton.layer.cornerRadius = 35
        inspireButton.clipsToBounds = false
        inspireButton.addTarget(self, action: #selector(handleInspireButtonTapped), for: .touchUpInside)
        
        // 添加发光阴影效果
        inspireButton.layer.shadowColor = UIColor(red: 102/255, green: 126/255, blue: 234/255, alpha: 0.6).cgColor
        inspireButton.layer.shadowOffset = CGSize(width: 0, height: 8)
        inspireButton.layer.shadowRadius = 20
        inspireButton.layer.shadowOpacity = 1.0
        
        // 创建第一行容器（Inspire Me + 问号）
        let firstLineContainer = UIView()
        inspireButton.addSubview(firstLineContainer)
        
        // Inspire Me 文字标签
        let inspireMeLabel = UILabel()
        inspireMeLabel.text = "Inspire Me"
        inspireMeLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        inspireMeLabel.textColor = UIColor.white
        inspireMeLabel.textAlignment = .center
        firstLineContainer.addSubview(inspireMeLabel)
        
        // 问号按钮
        questionButton.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        questionButton.tintColor = UIColor.white
        questionButton.addTarget(self, action: #selector(handleQuestionButtonTapped), for: .touchUpInside)
        firstLineContainer.addSubview(questionButton)
        
        // 第二行：Inspire Point -1
        inspirePointsLabel.text = "Inspire Point -\(inspirePoints)"
        inspirePointsLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        inspirePointsLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        inspirePointsLabel.textAlignment = .center
        inspireButton.addSubview(inspirePointsLabel)
        
        // 布局第一行容器
        firstLineContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.centerX.equalToSuperview()
            make.height.equalTo(28)
        }
        
        // 布局 Inspire Me 文字
        inspireMeLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        // 布局问号按钮
        questionButton.snp.makeConstraints { make in
            make.leading.equalTo(inspireMeLabel.snp.trailing).offset(8)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        
        // 布局第二行文字
        inspirePointsLabel.snp.makeConstraints { make in
            make.top.equalTo(firstLineContainer.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }
    
    private func configureLayoutConstraints() {
        inspireButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func configureDefaultStyles() {
        backgroundColor = UIColor.clear
        updateInspireButtonAppearance()
    }
    
    private func updateInspireButtonAppearance() {
        inspirePointsLabel.text = "Inspire Point -\(inspirePoints)"
        // 根据点数更新按钮状态
        let hasPoints = inspirePoints > 0
        inspireButton.isEnabled = hasPoints
        inspireButton.alpha = hasPoints ? 1.0 : 0.6
    }
}

extension LMInspireMeButtonView {
    
    @objc private func handleInspireButtonTapped() {
        guard inspirePoints > 0 else { return }
        
        // 添加点击动画
        UIView.animate(withDuration: 0.1, animations: {
            self.inspireButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.inspireButton.transform = CGAffineTransform.identity
            }
        }
        
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
        if inspirePoints > 0 {
            inspirePoints -= 1
            updateInspireButtonAppearance()
        }
    }
    
    func getCurrentInspirePoints() -> Int {
        return inspirePoints
    }
    
    /// 设置 Inspire Me 按钮的启用/禁用状态
    /// - Parameter enabled: true 启用，false 禁用
    func setInspireMeButtonEnabled(_ enabled: Bool) {
        inspireButton.isEnabled = enabled
        inspireButton.alpha = enabled ? 1.0 : 0.5
        
        // 更新容器的交互状态
        isUserInteractionEnabled = enabled
        
        // 如果禁用，显示灰色样式
        if !enabled {
            inspireButton.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        } else {
            // 恢复渐变背景
            setupInspireButtonGradient()
        }
    }
}
