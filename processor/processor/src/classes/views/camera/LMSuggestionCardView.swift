//
//  LMSuggestionCardView.swift
//  processor
//
//  Created by muz on 2025/11/1.
//  Refactored to inherit from UICollectionViewCell
//

import UIKit
import SnapKit

protocol LMSuggestionCardViewDelegate: AnyObject {
    func suggestionCardView(_ cardView: LMSuggestionCardView, didToggleFavorite isFavorite: Bool)
}

class LMSuggestionCardView: UIView {
    
    // MARK: - UI Components
    private let imageView = UIImageView()
    private let heartButton = UIButton()
    private let loadingView = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .medium)
    private let loadingLabel = UILabel()
    
    // MARK: - Properties
    weak var delegate: LMSuggestionCardViewDelegate?
    private var suggestion: SuggestionDisplayModel?
    
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
        backgroundColor = .gray
        layer.cornerRadius = 12
        layer.masksToBounds = true
        layer.borderColor = UIColor.clear.cgColor
        layer.borderWidth = 0
        
        // 图片视图设置
        imageView.contentMode = .scaleAspectFill
        
        // 心形按钮设置
        heartButton.setImage(UIImage(systemName: "heart"), for: .normal)
        heartButton.setImage(UIImage(systemName: "heart.fill"), for: .selected)
        heartButton.tintColor = UIColor.white
        heartButton.backgroundColor = UIColor.clear
        heartButton.addTarget(self, action: #selector(heartButtonTapped), for: .touchUpInside)
        heartButton.isHidden = true // 默认隐藏
        
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
        addSubview(imageView)
        addSubview(heartButton)
        addSubview(loadingView)
        loadingView.addSubview(loadingSpinner)
        loadingView.addSubview(loadingLabel)
        
        // 设置初始状态
        loadingView.isHidden = true
    }
    
    private func setupConstraints() {
        // 图片视图约束
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 心形按钮约束
        heartButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-8)
            make.size.equalTo(22)
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
    var isSelected: Bool = false {
        didSet {
            updateSelectionState(animated: true)
        }
    }
    
    // MARK: - Selection State
    private func updateSelectionState(animated: Bool) {
        if isSelected {
            // 更新边框颜色
            layer.borderColor = UIColor.systemBlue.cgColor
            layer.borderWidth = 3
            heartButton.isHidden = false
            
        } else {
            // 恢复边框颜色
            layer.borderColor = UIColor.clear.cgColor
            layer.borderWidth = 0
            heartButton.isHidden = true
        }
    }
    
    // MARK: - Private Methods
    private func showLoadingState() {
        loadingView.isHidden = false
        loadingSpinner.startAnimating()
        heartButton.isHidden = true
        
        // 使用渐变图片作为占位图
        let gradientImage = UIImage.gradientImage(
            size: CGSize(width: 300, height: 300),
            colors: [UIColor.systemPurple.cgColor, UIColor.systemPink.cgColor]
        )
        imageView.image = gradientImage
    }
    
    private func hideLoadingState() {
        loadingView.isHidden = true
        loadingSpinner.stopAnimating()
        updateSelectionState(animated: false)
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
}
