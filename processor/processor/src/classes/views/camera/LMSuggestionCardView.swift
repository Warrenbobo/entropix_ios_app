//
//  LMSuggestionCardView.swift
//  processor
//
//  Created by Kiro on 2025/11/1.
//  Refactored to inherit from UICollectionViewCell
//

import UIKit
import SnapKit

protocol LMSuggestionCardViewDelegate: AnyObject {
    func suggestionCardView(_ cardView: LMSuggestionCardView, didToggleFavorite isFavorite: Bool)
    func suggestionCardView(_ cardView: LMSuggestionCardView, didSwipeUp suggestion: SuggestionDisplayModel)
}

class LMSuggestionCardView: UICollectionViewCell {
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let imageView = UIImageView()
    private let heartButton = UIButton()
    private let loadingView = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .medium)
    private let loadingLabel = UILabel()
    
    // MARK: - Properties
    weak var delegate: LMSuggestionCardViewDelegate?
    private var suggestion: SuggestionDisplayModel?
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
    // MARK: - Constants
    private let selectedScale: CGFloat = 1.1 // 适中的放大倍数
    private let selectedTranslationY: CGFloat = -7 // 适中的向上偏移
    
    // MARK: - Swipe Up Constants
    private let maxSwipeDistance: CGFloat = 80
    private let maxSwipeScale: CGFloat = 1.15
    private let minSwipeAlpha: CGFloat = 0.7
    private let swipeThreshold: CGFloat = 50
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Subview Configuration
    private func configureSubviews() {
        // 允许 cell 内容超出边界显示（用于缩放效果）
        contentView.clipsToBounds = false
        clipsToBounds = false
        
        // 添加向上滑动手势识别器
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        contentView.addGestureRecognizer(panGestureRecognizer)
        
        // 容器视图设置
        containerView.layer.cornerRadius = 12
        containerView.clipsToBounds = true
        containerView.layer.borderWidth = 3
        containerView.layer.borderColor = UIColor.clear.cgColor
        containerView.backgroundColor = UIColor.systemGray6
        
        // 图片视图设置
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        
        // 心形按钮设置
        heartButton.setImage(UIImage(systemName: "heart"), for: .normal)
        heartButton.setImage(UIImage(systemName: "heart.fill"), for: .selected)
        heartButton.tintColor = UIColor.white
        heartButton.backgroundColor = UIColor.clear
        heartButton.layer.shadowColor = UIColor.black.cgColor
        heartButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        heartButton.layer.shadowRadius = 3
        heartButton.layer.shadowOpacity = 0.8
        heartButton.addTarget(self, action: #selector(heartButtonTapped), for: .touchUpInside)
        heartButton.alpha = 0 // 默认隐藏
        
        // 加载视图设置
        loadingView.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.9)
        loadingView.layer.cornerRadius = 12
        
        loadingSpinner.color = UIColor.white
        loadingSpinner.hidesWhenStopped = true
        
        loadingLabel.text = LMText.camera.generating
        loadingLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        loadingLabel.textColor = UIColor.white
        loadingLabel.textAlignment = .center
        
        // 添加子视图到 contentView
        contentView.addSubview(containerView)
        containerView.addSubview(imageView)
        containerView.addSubview(heartButton)
        containerView.addSubview(loadingView)
        loadingView.addSubview(loadingSpinner)
        loadingView.addSubview(loadingLabel)
        
        // 设置初始状态
        loadingView.isHidden = true
    }
    
    private func setupConstraints() {
        // 容器视图约束
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 图片视图约束
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 心形按钮约束
        heartButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.size.equalTo(18)
        }
        
        // 加载视图约束
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 加载指示器约束
        loadingSpinner.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-10)
        }
        
        // 加载标签约束
        loadingLabel.snp.makeConstraints { make in
            make.top.equalTo(loadingSpinner.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(8)
        }
    }
    
    // MARK: - Cell Lifecycle
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // 重置所有状态
        imageView.image = nil
        heartButton.isSelected = false
        heartButton.tintColor = UIColor.white
        heartButton.alpha = 0
        suggestion = nil
        
        // 移除所有动画
        layer.removeAllAnimations()
        containerView.layer.removeAllAnimations()
        
        // 重置变换
        containerView.layer.transform = CATransform3DIdentity
        containerView.alpha = 1.0
        layer.zPosition = 0
        
        // 重置边框
        containerView.layer.borderColor = UIColor.clear.cgColor
    }
    
    // MARK: - Public Methods
    func configure(with suggestion: SuggestionDisplayModel) {
        self.suggestion = suggestion
        
        if suggestion.isGenerating {
            showLoadingState()
        } else {
            hideLoadingState()
            
            // 设置图片
            if let image = suggestion.image {
                imageView.image = image
            } else if let imageURL = suggestion.imageURL {
                // 这里可以添加网络图片加载逻辑
                loadImageFromURL(imageURL)
            }
            
            // 设置收藏状态
            heartButton.isSelected = suggestion.isFavorite
            heartButton.tintColor = suggestion.isFavorite ? UIColor.systemRed : UIColor.white
        }
    }
    
    // MARK: - UICollectionViewCell Override
    override var isSelected: Bool {
        didSet {
            updateSelectionState(animated: true)
        }
    }
    
    // MARK: - Selection State
    private func updateSelectionState(animated: Bool) {
        // 移除之前的动画，避免冲突
        containerView.layer.removeAnimation(forKey: "scaleAnimation")
        
        if isSelected {
            // 更新边框颜色
            containerView.layer.borderColor = UIColor.systemBlue.cgColor
            
            // 提升 zPosition，让选中的 cell 显示在最上层
            layer.zPosition = 100
            
            // 显示收藏按钮
            heartButton.alpha = 1.0
            
            // 计算变换
            let scale = selectedScale
            let translateY = selectedTranslationY
            
            var transform = CATransform3DIdentity
            transform = CATransform3DScale(transform, scale, scale, 1.0)
            transform = CATransform3DTranslate(transform, 0, translateY, 0)
            
            if animated {
                // 使用 UIView 动画而不是 CAAnimation，更可靠
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    usingSpringWithDamping: 0.8,
                    initialSpringVelocity: 0.5,
                    options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState]
                ) {
                    self.containerView.layer.transform = transform
                }
            } else {
                // 直接设置，不使用动画
                containerView.layer.transform = transform
            }
            
        } else {
            // 恢复边框颜色
            containerView.layer.borderColor = UIColor.clear.cgColor
            
            // 恢复 zPosition
            layer.zPosition = 0
            
            // 根据收藏状态决定是否显示收藏按钮
            heartButton.alpha = suggestion?.isFavorite == true ? 1.0 : 0.0
            
            if animated {
                // 使用 UIView 动画
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    usingSpringWithDamping: 0.8,
                    initialSpringVelocity: 0.5,
                    options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState]
                ) {
                    self.containerView.layer.transform = CATransform3DIdentity
                }
            } else {
                // 直接设置，不使用动画
                containerView.layer.transform = CATransform3DIdentity
            }
        }
    }
    
    // MARK: - Private Methods
    private func showLoadingState() {
        loadingView.isHidden = false
        loadingSpinner.startAnimating()
        imageView.isHidden = true
        heartButton.isHidden = true
        
        // 添加渐变背景
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemPurple.cgColor,
            UIColor.systemPink.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.frame = loadingView.bounds
        gradientLayer.cornerRadius = 12
        
        loadingView.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    private func hideLoadingState() {
        loadingView.isHidden = true
        loadingSpinner.stopAnimating()
        imageView.isHidden = false
        heartButton.isHidden = false
        
        // 移除渐变层
        loadingView.layer.sublayers?.removeAll { $0 is CAGradientLayer }
    }
    
    private func loadImageFromURL(_ urlString: String) {
        // 这里应该实现网络图片加载逻辑
        // 为了演示，我们使用占位图片
        imageView.image = UIImage(systemName: "photo")
        imageView.tintColor = UIColor.systemGray3
    }
    
    // MARK: - Actions
    @objc private func heartButtonTapped() {
        guard let suggestion = suggestion, !suggestion.isGenerating else { return }
        
        let newFavoriteState = !heartButton.isSelected
        heartButton.isSelected = newFavoriteState
        heartButton.tintColor = newFavoriteState ? UIColor.systemRed : UIColor.white
        
        // 添加心跳动画
        if newFavoriteState {
            addHeartBeatAnimation()
        }
        
        delegate?.suggestionCardView(self, didToggleFavorite: newFavoriteState)
    }
    
    private func addHeartBeatAnimation() {
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [1.0, 1.2, 1.0]
        animation.keyTimes = [0.0, 0.5, 1.0]
        animation.duration = 0.3
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        heartButton.layer.add(animation, forKey: "heartBeat")
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 更新渐变层frame
        if let gradientLayer = loadingView.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
            gradientLayer.frame = loadingView.bounds
        }
    }
    
    // MARK: - Gesture Handling
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        
        switch gesture.state {
        case .began:
            LMLogger.log("👆 Pan gesture began on cell")
            
        case .changed:
            // 只处理向上滑动
            if translation.y < 0 {
                let upwardDistance = abs(translation.y)
                
                // 限制最大移动距离
                let actualDistance = min(upwardDistance, maxSwipeDistance)
                
                // 计算缩放比例
                let scaleProgress = actualDistance / maxSwipeDistance
                let scale = 1.0 + (maxSwipeScale - 1.0) * scaleProgress
                
                // 计算透明度
                let alpha = 1.0 - (1.0 - minSwipeAlpha) * scaleProgress
                
                // 应用变换：向上移动 + 缩放
                var transform = CATransform3DIdentity
                transform = CATransform3DTranslate(transform, 0, -actualDistance, 0)
                transform = CATransform3DScale(transform, scale, scale, 1.0)
                
                containerView.layer.transform = transform
                containerView.alpha = alpha
                
                // 触觉反馈
                if upwardDistance > swipeThreshold && upwardDistance < swipeThreshold + 2 {
                    if #available(iOS 10.0, *) {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                }
            } else {
                // 向下移动时，恢复到当前应有的状态
                restoreToCurrentState(animated: false)
            }
            
        case .ended, .cancelled:
            let upwardDistance = abs(translation.y)
            let isSwipeUp = translation.y < 0 && upwardDistance > swipeThreshold
            
            if isSwipeUp, let suggestion = suggestion {
                LMLogger.log("⬆️ Swipe up detected - distance: \(upwardDistance)")
                
                // 飞出动画
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    options: [.curveEaseIn]
                ) {
                    var transform = CATransform3DIdentity
                    transform = CATransform3DTranslate(transform, 0, -200, 0)
                    transform = CATransform3DScale(transform, 0.8, 0.8, 1.0)
                    self.containerView.layer.transform = transform
                    self.containerView.alpha = 0
                } completion: { _ in
                    // 触发回调
                    self.delegate?.suggestionCardView(self, didSwipeUp: suggestion)
                }
            } else {
                // 恢复到当前应有的状态
                LMLogger.log("↩️ Swipe cancelled - restoring to current state")
                restoreToCurrentState(animated: true)
            }
            
        default:
            break
        }
    }
    
    /// 恢复到当前应有的状态（根据选中状态决定）
    private func restoreToCurrentState(animated: Bool) {
        if isSelected {
            // 恢复到选中状态的放大效果
            let scale = selectedScale
            let translateY = selectedTranslationY
            
            var transform = CATransform3DIdentity
            transform = CATransform3DScale(transform, scale, scale, 1.0)
            transform = CATransform3DTranslate(transform, 0, translateY, 0)
            
            if animated {
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 0.5,
                    options: [.curveEaseOut]
                ) {
                    self.containerView.layer.transform = transform
                    self.containerView.alpha = 1.0
                }
            } else {
                containerView.layer.transform = transform
                containerView.alpha = 1.0
            }
        } else {
            // 恢复到未选中状态
            if animated {
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 0.5,
                    options: [.curveEaseOut]
                ) {
                    self.containerView.layer.transform = CATransform3DIdentity
                    self.containerView.alpha = 1.0
                }
            } else {
                containerView.layer.transform = CATransform3DIdentity
                containerView.alpha = 1.0
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension LMSuggestionCardView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 只允许向上滑动
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            let translation = panGesture.translation(in: self)
            return abs(translation.y) > abs(translation.x) && translation.y < 0
        }
        return true
    }
}
