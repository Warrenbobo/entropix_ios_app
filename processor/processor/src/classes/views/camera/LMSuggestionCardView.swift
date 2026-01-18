//
//  LMSuggestionCardView.swift
//  processor
//
//  Created by muz on 2025/11/1.
//  Refactored to inherit from UICollectionViewCell
//

import UIKit
import SnapKit
import Kingfisher

protocol LMSuggestionCardViewDelegate: AnyObject {
    func suggestionCardView(_ cardView: LMSuggestionCardView, didToggleFavorite isFavorite: Bool)
}

class LMSuggestionCardView: UIView {
    
    public var displayedImage: UIImage? {
        return imageView.image
    }
    
    // MARK: - Adaptive Size Constants
    private static let baseScreenWidth: CGFloat = 393.0
    
    private static var screenScaleFactor: CGFloat {
        return UIScreen.main.bounds.width / baseScreenWidth
    }
    
    private static func adaptiveSize(_ baseSize: CGFloat) -> CGFloat {
        return baseSize * screenScaleFactor
    }
    
    // MARK: - UI Components
    private let backgroundImageView = UIImageView() // 底层：拉伸填充
    private let blurEffectView: UIVisualEffectView = {
        // 使用毛玻璃样式的模糊效果 - regular 提供经典的毛玻璃质感
        let blurEffect = UIBlurEffect(style: .regular)
        return UIVisualEffectView(effect: blurEffect)
    }() // 中层：模糊蒙层
    private let imageView = UIImageView() // 顶层：等比例显示
    private let placeholderImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center  // 居中显示，不缩放
        imageView.tintColor = .lightGray
        let pointSize = adaptiveSize(32)
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        imageView.image = UIImage(systemName: "photo", withConfiguration: config)
        imageView.isHidden = true
        return imageView
    }() // Placeholder 图标（居中显示）
    private let heartButton = UIButton()
    private let loadingView = UIView()
    private let loadingSpinner = UIActivityIndicatorView(style: .medium)
    private let loadingLabel = UILabel()
    private let aigcBadgeImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "aigc")
        imageView.contentMode = .scaleAspectFit
        imageView.alpha = 0.7  // 30% 透明度即70%不透明度
        imageView.isHidden = true  // 默认隐藏
        return imageView
    }() // AIGC 标识图
    
    // MARK: - Properties
    weak var delegate: LMSuggestionCardViewDelegate?
    private var suggestion: LMCompositionSuggestion?
    private var isFavorite: Bool = false
    private var currentImageUrl: String? = nil // ✅ Track current image URL to prevent redundant loads
    
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
        backgroundColor = .lightGray
        layer.cornerRadius = Self.adaptiveSize(12)
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
        loadingView.layer.cornerRadius = Self.adaptiveSize(12)
        
        loadingSpinner.color = UIColor.white
        loadingSpinner.hidesWhenStopped = true
        
        loadingLabel.text = LMText.camera.generating
        loadingLabel.font = UIFont.systemFont(ofSize: Self.adaptiveSize(12), weight: .medium)
        loadingLabel.textColor = UIColor.white
        loadingLabel.textAlignment = .center
        
        // 按层级添加子视图
        addSubview(backgroundImageView)  // 底层：拉伸背景
        addSubview(blurEffectView)       // 中层：模糊蒙层
        addSubview(imageView)            // 顶层：等比例图片
        addSubview(placeholderImageView) // Placeholder 图标
        addSubview(aigcBadgeImageView)   // AIGC 标识图
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
        
        // Placeholder 图标（居中显示）
        placeholderImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(Self.adaptiveSize(64))  // 自适应大小
        }
        
        // AIGC 标识图（左上角）
        aigcBadgeImageView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(8)
            make.size.equalTo(Self.adaptiveSize(24))
        }
        
        // 心形按钮约束
        heartButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-8)
            make.size.equalTo(Self.adaptiveSize(22))
        }
        
        // 加载视图约束
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 加载指示器约束
        loadingSpinner.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-Self.adaptiveSize(10))
        }
        
        // 加载标签约束
        loadingLabel.snp.makeConstraints { make in
            make.top.equalTo(loadingSpinner.snp.bottom).offset(Self.adaptiveSize(8))
            make.leading.trailing.equalToSuperview().inset(Self.adaptiveSize(8))
        }
    }
    
    // MARK: - Public Methods
    func configure(with suggestion: LMCompositionSuggestion, isFavorite: Bool = false) {
        self.suggestion = suggestion
        self.isFavorite = isFavorite
        
        // 根据 source 字段显示/隐藏 AIGC 标识（source = "generated" 时显示）
        aigcBadgeImageView.isHidden = !suggestion.isAIGC
        
        if suggestion.ready != true {
            showLoadingState()
        } else {
            hideLoadingState()
            
            // ✅ CRITICAL FIX: Only reload image if URL has actually changed
            // This prevents unnecessary image reloading when returning from reference image
            if let imageUrl = suggestion.imageUrl {
                if currentImageUrl != imageUrl {
                    // URL changed - load new image
                    loadImageFromURL(imageUrl)
                    currentImageUrl = imageUrl
                    LMLogger.log("🖼️ Loading new image: \(imageUrl)")
                } else {
                    // URL unchanged - skip reload, image is already displayed
                    LMLogger.log("⏭️ Skipping image reload - URL unchanged: \(imageUrl)")
                }
            } else {
                // No image URL - clear current URL and show placeholder
                currentImageUrl = nil
                placeholderImageView.isHidden = false
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
        
        // 隐藏背景图片、模糊效果和主图片
        backgroundImageView.isHidden = true
        blurEffectView.isHidden = true
        imageView.isHidden = true
    }
    
    private func hideLoadingState() {
        loadingView.isHidden = true
        loadingSpinner.stopAnimating()
        
        // 显示背景图片、模糊效果和主图片
        backgroundImageView.isHidden = false
        blurEffectView.isHidden = false
        imageView.isHidden = false
        
        updateSelectionState(animated: false)
    }
    
    private func loadImageFromURL(_ urlString: String) {
        // 显示 placeholder 图标
        placeholderImageView.isHidden = false
        
        imageView.kf.setImage(with: URL(string: urlString),
                              placeholder: nil) { [weak self] result in
            guard let self = self else { return }
            
            // 隐藏 placeholder 图标
            self.placeholderImageView.isHidden = true
            
            switch result {
            case .success(let image):
                self.backgroundImageView.image = image.image
            case .failure(let error):
                // 加载失败时保持显示 placeholder
                self.placeholderImageView.isHidden = false
                LMLogger.log("❌ Failed to load image: \(error)")
            }
        }
    }
    
    // MARK: - Actions
    @objc private func heartButtonTapped() {
        guard let suggestion = suggestion, suggestion.ready == true else { return }
        
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


// MARK: - Touch Event Logging (Debug)
extension LMSuggestionCardView {
    
    /// 记录触摸开始事件
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        LMLogger.log("🎴 [CARD_TOUCH] ========== CARD TOUCH BEGAN ==========")
        LMLogger.log("🎴 [CARD_TOUCH] Card index: \(self.tag)")
        LMLogger.log("🎴 [CARD_TOUCH] Location: \(location)")
        LMLogger.log("🎴 [CARD_TOUCH] Card frame: \(self.frame)")
        LMLogger.log("🎴 [CARD_TOUCH] Card isUserInteractionEnabled: \(self.isUserInteractionEnabled)")
        LMLogger.log("🎴 [CARD_TOUCH] Card alpha: \(self.alpha)")
        LMLogger.log("🎴 [CARD_TOUCH] Card transform: \(self.transform)")
        
        // 检查是否点击在心形按钮上
        let heartLocation = touch.location(in: heartButton)
        if heartButton.bounds.contains(heartLocation) {
            LMLogger.log("🎴 [CARD_TOUCH] Touch is on heart button")
        }
    }
    
    /// 记录触摸移动事件
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)
        let delta = CGPoint(x: location.x - previousLocation.x, y: location.y - previousLocation.y)
        
        // 只记录显著的移动
        if abs(delta.x) > 5 || abs(delta.y) > 5 {
            LMLogger.log("🎴 [CARD_TOUCH] ========== CARD TOUCH MOVED ==========")
            LMLogger.log("🎴 [CARD_TOUCH] Card index: \(self.tag)")
            LMLogger.log("🎴 [CARD_TOUCH] Delta: \(delta)")
        }
    }
    
    /// 记录触摸结束事件
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        LMLogger.log("🎴 [CARD_TOUCH] ========== CARD TOUCH ENDED ==========")
        LMLogger.log("🎴 [CARD_TOUCH] Card index: \(self.tag)")
    }
    
    /// 记录触摸取消事件
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        LMLogger.log("🎴 [CARD_TOUCH] ========== CARD TOUCH CANCELLED ==========")
        LMLogger.log("🎴 [CARD_TOUCH] Card index: \(self.tag)")
        LMLogger.log("🎴 [CARD_TOUCH] ⚠️ Card touch was cancelled")
    }
}
