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
    
    public var displayedImage: UIImage? {
        return imageView.image
    }
    
    // MARK: - UI Components
    private let backgroundImageView = UIImageView() // 底层：拉伸填充
    private let blurEffectView: UIVisualEffectView = {
        // 使用毛玻璃样式的模糊效果 - regular 提供经典的毛玻璃质感
        let blurEffect = UIBlurEffect(style: .regular)
        return UIVisualEffectView(effect: blurEffect)
    }() // 中层：模糊蒙层
    private let imageView = UIImageView() // 顶层：等比例显示
    private let heartButton = UIButton()
    private let loadingView = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .medium)
    private let loadingLabel = UILabel()
    
    // MARK: - Properties
    weak var delegate: LMSuggestionCardViewDelegate?
    private var suggestion: LMCompositionSuggestion?
    private var isFavorite: Bool = false
    
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
        
        // 底层：背景图片视图（拉伸填充）
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.clipsToBounds = true
        
        // 顶层：图片视图（等比例显示，不拉伸）
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        
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
        
        // 按层级添加子视图
        addSubview(backgroundImageView)  // 底层：拉伸背景
        addSubview(blurEffectView)       // 中层：模糊蒙层
        addSubview(imageView)            // 顶层：等比例图片
        addSubview(heartButton)
        addSubview(loadingView)
        loadingView.addSubview(loadingSpinner)
        loadingView.addSubview(loadingLabel)
        
        // 设置初始状态
        loadingView.isHidden = true
    }
    
    private func setupConstraints() {
        // 底层：背景图片视图（填充整个卡片）
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 中层：模糊效果蒙层（覆盖背景图）
        blurEffectView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 顶层：图片视图（等比例显示，居中）
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
    func configure(with suggestion: LMCompositionSuggestion, isFavorite: Bool = false) {
        self.suggestion = suggestion
        self.isFavorite = isFavorite
        
        if !suggestion.ready {
            showLoadingState()
        } else {
            hideLoadingState()
            
            // 设置图片 - 优先使用 similarImageUrl（相似构图），然后使用 imageUrl（AIGC构图）
            if let similarImageUrl = suggestion.similarImageUrl {
                loadImageFromURL(similarImageUrl)
            } else if let imageUrl = suggestion.imageUrl {
                loadImageFromURL(imageUrl)
            }
            
            // 设置收藏状态
            heartButton.isSelected = isFavorite
            heartButton.tintColor = isFavorite ? UIColor.systemRed : UIColor.white
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
        // 从 Assets.xcassets 加载本地图片
        if let image = UIImage(named: urlString) {
            // 设置三层结构：
            // 1. 底层：拉伸填充的背景图
            backgroundImageView.image = image
            
            // 2. 中层：模糊蒙层（已在 configureSubviews 中设置）
            
            // 3. 顶层：等比例显示的图片
            imageView.image = image
            
            LMLogger.log("✅ Loaded local sample image with layered style: \(urlString)")
        } else {
            // 如果找不到图片，使用占位图
            let placeholderImage = UIImage(systemName: "photo")
            backgroundImageView.image = placeholderImage
            imageView.image = placeholderImage
            imageView.tintColor = UIColor.systemGray3
            LMLogger.log("⚠️ Sample image not found: \(urlString)")
        }
    }
    
    // MARK: - Actions
    @objc private func heartButtonTapped() {
        guard let suggestion = suggestion, suggestion.ready else { return }
        
        let newFavoriteState = !heartButton.isSelected
        heartButton.isSelected = newFavoriteState
        heartButton.tintColor = newFavoriteState ? UIColor.systemRed : UIColor.white
        self.isFavorite = newFavoriteState
        
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
