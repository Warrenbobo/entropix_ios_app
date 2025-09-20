//
//  LMFeaturePreviewView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

protocol LMFeaturePreviewViewDelegate: AnyObject {
    func featurePreviewViewDidTapBasicCameraFeature()
    func featurePreviewViewDidTapAiInspiringFeature()
}

class LMFeaturePreviewView: UIView {
    
    private let contentStackView = UIStackView()
    private let featurePreviewTitleLabel = UILabel()
    private let featuresContainerView = UIView()
    private let basicCameraFeatureView = UIView()
    private let aiInspiringFeatureView = UIView()
    
    private let basicCameraIconImageView = UIImageView()
    private let basicCameraTitleLabel = UILabel()
    private let basicCameraDescriptionLabel = UILabel()
    
    private let aiInspiringIconImageView = UIImageView()
    private let aiInspiringTitleLabel = UILabel()
    private let aiInspiringDescriptionLabel = UILabel()
    private let aiInspiringStatusBadgeLabel = UILabel()
    
    weak var delegate: LMFeaturePreviewViewDelegate?
    private var remainingInspiringPoints: Int = 1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LMFeaturePreviewView {
    
    private func setupUserInterfaceComponents() {
        setupContentStackViewConfiguration()
        setupFeaturePreviewTitleComponents()
        setupFeaturesContainerComponents()
        setupBasicCameraFeatureComponents()
        setupAiInspiringFeatureComponents()
    }
    
    private func setupContentStackViewConfiguration() {
        addSubview(contentStackView)
        
        contentStackView.axis = .vertical
        contentStackView.spacing = 20
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        
        // 添加主要组件到堆栈视图
        contentStackView.addArrangedSubview(featurePreviewTitleLabel)
        contentStackView.addArrangedSubview(featuresContainerView)
    }
    
    private func setupFeaturePreviewTitleComponents() {
        featurePreviewTitleLabel.text = "Available Without Account"
        featurePreviewTitleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        featurePreviewTitleLabel.textColor = UIColor.label
        featurePreviewTitleLabel.textAlignment = .left
        featurePreviewTitleLabel.numberOfLines = 0
    }
    
    private func setupFeaturesContainerComponents() {
        basicCameraFeatureView.backgroundColor = .white
        basicCameraFeatureView.layer.cornerRadius = 8
        basicCameraFeatureView.layer.masksToBounds = true
        featuresContainerView.addSubview(basicCameraFeatureView)
        aiInspiringFeatureView.backgroundColor = .white
        aiInspiringFeatureView.layer.cornerRadius = 8
        aiInspiringFeatureView.layer.masksToBounds = true
        featuresContainerView.addSubview(aiInspiringFeatureView)
    }
    
    private func setupBasicCameraFeatureComponents() {
        basicCameraFeatureView.addSubview(basicCameraIconImageView)
        basicCameraFeatureView.addSubview(basicCameraTitleLabel)
        basicCameraFeatureView.addSubview(basicCameraDescriptionLabel)
        
        // 图标设置
        basicCameraIconImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        basicCameraIconImageView.layer.cornerRadius = 20
        basicCameraIconImageView.image = UIImage(systemName: "camera.fill")
        basicCameraIconImageView.tintColor = UIColor.systemBlue
        basicCameraIconImageView.contentMode = .center
        
        // 标题设置
        basicCameraTitleLabel.text = "Basic Camera"
        basicCameraTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        basicCameraTitleLabel.textColor = UIColor.label
        basicCameraTitleLabel.numberOfLines = 0
        
        // 描述设置
        basicCameraDescriptionLabel.text = "Take photos with standard features"
        basicCameraDescriptionLabel.font = UIFont.systemFont(ofSize: 14)
        basicCameraDescriptionLabel.textColor = UIColor.secondaryLabel
        basicCameraDescriptionLabel.numberOfLines = 0
        
        // 添加点击手势
        basicCameraFeatureView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleBasicCameraFeatureViewTapped))
        basicCameraFeatureView.addGestureRecognizer(tapGesture)
        
        // 添加触摸反馈效果
        addTouchFeedbackEffectToView(basicCameraFeatureView)
    }
    
    private func setupAiInspiringFeatureComponents() {
        aiInspiringFeatureView.addSubview(aiInspiringIconImageView)
        aiInspiringFeatureView.addSubview(aiInspiringTitleLabel)
        aiInspiringFeatureView.addSubview(aiInspiringDescriptionLabel)
        aiInspiringFeatureView.addSubview(aiInspiringStatusBadgeLabel)
        
        // 图标设置
        aiInspiringIconImageView.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.1)
        aiInspiringIconImageView.layer.cornerRadius = 20
        aiInspiringIconImageView.image = UIImage(systemName: "wand.and.stars")
        aiInspiringIconImageView.tintColor = UIColor.systemPurple
        aiInspiringIconImageView.contentMode = .center
        
        // 标题设置
        aiInspiringTitleLabel.text = "AI Inspiring"
        aiInspiringTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        aiInspiringTitleLabel.textColor = UIColor.label
        aiInspiringTitleLabel.numberOfLines = 0
        
        // 描述设置
        aiInspiringDescriptionLabel.text = "3 free Inspire points for new downloads"
        aiInspiringDescriptionLabel.font = UIFont.systemFont(ofSize: 14)
        aiInspiringDescriptionLabel.textColor = UIColor.secondaryLabel
        aiInspiringDescriptionLabel.numberOfLines = 0
        
        // 状态标签设置
        updateAiInspiringStatusBadgeDisplay()
        
        // 添加点击手势
        aiInspiringFeatureView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleAiInspiringFeatureViewTapped))
        aiInspiringFeatureView.addGestureRecognizer(tapGesture)
        
        // 添加触摸反馈效果
        addTouchFeedbackEffectToView(aiInspiringFeatureView)
    }
    
    private func addTouchFeedbackEffectToView(_ view: UIView) {
        let touchDownGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleViewTouchDownAnimation(_:)))
        touchDownGesture.minimumPressDuration = 0
        view.addGestureRecognizer(touchDownGesture)
    }
}

extension LMFeaturePreviewView {
    
    private func configureLayoutConstraints() {
        configureContentStackViewConstraints()
        configureFeaturesContainerConstraints()
        configureBasicCameraFeatureConstraints()
        configureAiInspiringFeatureConstraints()
    }
    
    private func configureContentStackViewConstraints() {
        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func configureFeaturesContainerConstraints() {
        basicCameraFeatureView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
        }
        
        aiInspiringFeatureView.snp.makeConstraints { make in
            make.top.equalTo(basicCameraFeatureView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    private func configureBasicCameraFeatureConstraints() {
        basicCameraIconImageView.snp.makeConstraints { make in
            make.leading.equalTo(20)
            make.top.equalTo(20)
            make.size.equalTo(40)
            make.bottom.equalTo(-20)
        }
        
        basicCameraTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(basicCameraIconImageView.snp.trailing).offset(16)
            make.top.equalTo(basicCameraIconImageView).offset(2)
            make.trailing.equalToSuperview()
        }
        
        basicCameraDescriptionLabel.snp.makeConstraints { make in
            make.leading.equalTo(basicCameraTitleLabel)
            make.top.equalTo(basicCameraTitleLabel.snp.bottom).offset(4)
            make.trailing.equalToSuperview()
        }
    }
    
    private func configureAiInspiringFeatureConstraints() {
        aiInspiringIconImageView.snp.makeConstraints { make in
            make.leading.equalTo(20)
            make.top.equalTo(20)
            make.size.equalTo(40)
            make.bottom.equalTo(-20)
        }
        
        aiInspiringTitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(aiInspiringIconImageView.snp.trailing).offset(16)
            make.top.equalTo(aiInspiringIconImageView).offset(2)
            make.trailing.lessThanOrEqualTo(aiInspiringStatusBadgeLabel.snp.leading).offset(-8)
        }
        
        aiInspiringDescriptionLabel.snp.makeConstraints { make in
            make.leading.equalTo(aiInspiringTitleLabel)
            make.top.equalTo(aiInspiringTitleLabel.snp.bottom).offset(4)
            make.trailing.equalToSuperview()
        }
        
        aiInspiringStatusBadgeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(-20)
            make.top.equalTo(12)
            make.width.equalTo(50)
            make.height.equalTo(20)
        }
    }
}

extension LMFeaturePreviewView {
    
    private func configureDefaultContentAndStyles() {
        backgroundColor = .clear
        updateAiInspiringStatusBadgeDisplay()
    }
    
    private func updateAiInspiringStatusBadgeDisplay() {
        aiInspiringStatusBadgeLabel.text = "\(remainingInspiringPoints) left"
        aiInspiringStatusBadgeLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        aiInspiringStatusBadgeLabel.textColor = UIColor.systemBlue
        aiInspiringStatusBadgeLabel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        aiInspiringStatusBadgeLabel.layer.cornerRadius = 10
        aiInspiringStatusBadgeLabel.clipsToBounds = true
        aiInspiringStatusBadgeLabel.textAlignment = .center
    }
}

extension LMFeaturePreviewView {
    
    @objc private func handleBasicCameraFeatureViewTapped() {
        delegate?.featurePreviewViewDidTapBasicCameraFeature()
    }
    
    @objc private func handleAiInspiringFeatureViewTapped() {
        delegate?.featurePreviewViewDidTapAiInspiringFeature()
    }
    
    @objc private func handleViewTouchDownAnimation(_ gesture: UILongPressGestureRecognizer) {
        guard let view = gesture.view else { return }
        
        switch gesture.state {
        case .began:
            UIView.animate(withDuration: 0.1) {
                view.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                view.alpha = 0.8
            }
        case .ended, .cancelled:
            UIView.animate(withDuration: 0.1) {
                view.transform = CGAffineTransform.identity
                view.alpha = 1.0
            }
        default:
            break
        }
    }
}

extension LMFeaturePreviewView {
    
    func updateFeaturePreviewTitleContent(_ title: String) {
        featurePreviewTitleLabel.text = title
    }
    
    func updateBasicCameraFeatureContent(title: String, description: String, icon: UIImage?) {
        basicCameraTitleLabel.text = title
        basicCameraDescriptionLabel.text = description
        if let icon = icon {
            basicCameraIconImageView.image = icon
        }
    }
    
    func updateAiInspiringFeatureContent(title: String, description: String, icon: UIImage?) {
        aiInspiringTitleLabel.text = title
        aiInspiringDescriptionLabel.text = description
        if let icon = icon {
            aiInspiringIconImageView.image = icon
        }
    }
    
    func updateRemainingInspiringPointsCount(_ count: Int) {
        remainingInspiringPoints = max(0, count)
        updateAiInspiringStatusBadgeDisplay()
        
        // 如果没有剩余点数，禁用AI功能
        aiInspiringFeatureView.isUserInteractionEnabled = remainingInspiringPoints > 0
        aiInspiringFeatureView.alpha = remainingInspiringPoints > 0 ? 1.0 : 0.6
    }
    
    func configureFeatureAvailabilityStatus(basicCameraEnabled: Bool, aiInspiringEnabled: Bool) {
        basicCameraFeatureView.isUserInteractionEnabled = basicCameraEnabled
        basicCameraFeatureView.alpha = basicCameraEnabled ? 1.0 : 0.6
        
        aiInspiringFeatureView.isUserInteractionEnabled = aiInspiringEnabled && remainingInspiringPoints > 0
        aiInspiringFeatureView.alpha = (aiInspiringEnabled && remainingInspiringPoints > 0) ? 1.0 : 0.6
    }
    
    func decrementRemainingInspiringPoints() {
        if remainingInspiringPoints > 0 {
            remainingInspiringPoints -= 1
            updateAiInspiringStatusBadgeDisplay()
            
            if remainingInspiringPoints == 0 {
                configureFeatureAvailabilityStatus(basicCameraEnabled: true, aiInspiringEnabled: false)
            }
        }
    }
}
