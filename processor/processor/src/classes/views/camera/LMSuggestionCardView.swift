//
//  LMSuggestionCardView.swift
//  processor
//
//  Created by Kiro on 2025/11/1.
//

import UIKit
import SnapKit

protocol LMSuggestionCardViewDelegate: AnyObject {
    func suggestionCardView(_ cardView: LMSuggestionCardView, didToggleFavorite isFavorite: Bool)
}

enum AdjacentMarginSide {
    case left, right
}

class LMSuggestionCardView: UIView {
    
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
    private var isSelected: Bool = false
    private var adjacentMargins: Set<AdjacentMarginSide> = []
    
    // MARK: - Constants
    private let cardSize = CGSize(width: 75, height: 100)
    private let selectedScale: CGFloat = 1.3
    private let selectedTranslationY: CGFloat = -15
    
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
        
        // 添加子视图
        addSubview(containerView)
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
            make.center.equalToSuperview()
            make.size.equalTo(cardSize)
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
        
        // 设置视图大小
        self.snp.makeConstraints { make in
            make.size.equalTo(cardSize)
        }
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
    
    func setSelected(_ selected: Bool, animated: Bool) {
        guard isSelected != selected else { return }
        isSelected = selected
        
        let animations = {
            if selected {
                self.containerView.layer.borderColor = UIColor.systemBlue.cgColor
                self.containerView.transform = CGAffineTransform(scaleX: self.selectedScale, y: self.selectedScale)
                    .concatenating(CGAffineTransform(translationX: 0, y: self.selectedTranslationY))
                self.heartButton.alpha = 1.0
            } else {
                self.containerView.layer.borderColor = UIColor.clear.cgColor
                self.containerView.transform = CGAffineTransform.identity
                self.heartButton.alpha = self.suggestion?.isFavorite == true ? 1.0 : 0.0
            }
            
            self.updateAdjacentMarginsTransform()
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: animations)
        } else {
            animations()
        }
    }
    
    func addAdjacentMargin(_ side: AdjacentMarginSide) {
        adjacentMargins.insert(side)
        updateAdjacentMarginsTransform()
    }
    
    func removeAdjacentMargins() {
        adjacentMargins.removeAll()
        updateAdjacentMarginsTransform()
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
    
    private func updateAdjacentMarginsTransform() {
        var marginTransform = CGAffineTransform.identity
        
        if adjacentMargins.contains(.left) {
            marginTransform = marginTransform.concatenating(CGAffineTransform(translationX: 16, y: 0))
        }
        if adjacentMargins.contains(.right) {
            marginTransform = marginTransform.concatenating(CGAffineTransform(translationX: -16, y: 0))
        }
        
        // 合并选中状态的变换
        if isSelected {
            let selectedTransform = CGAffineTransform(scaleX: selectedScale, y: selectedScale)
                .concatenating(CGAffineTransform(translationX: 0, y: selectedTranslationY))
            containerView.transform = selectedTransform.concatenating(marginTransform)
        } else {
            containerView.transform = marginTransform
        }
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
}