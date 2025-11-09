//
//  LMCameraPreviewManager.swift
//  processor
//
//  Created by Kiro on 2025/11/1.
//

import UIKit
import SnapKit

protocol LMCameraPreviewManagerDelegate: AnyObject {
    func cameraPreviewManager(_ manager: LMCameraPreviewManager, didSelectSuggestion suggestion: LMCompositionSuggestion)
    func cameraPreviewManager(_ manager: LMCameraPreviewManager, didToggleFavorite suggestion: LMCompositionSuggestion)
    func cameraPreviewManagerDidRequestBack(_ manager: LMCameraPreviewManager)
    func cameraPreviewManager(_ manager: LMCameraPreviewManager, didUpdateARGuidanceState isActive: Bool)
}

enum LMCameraPreviewState {
    case camera           // 普通相机模式
    case suggestions      // 显示建议列表
    case composition      // 选择了构图，显示引导
}

class LMCameraPreviewManager: NSObject {
    
    // MARK: - UI Components
    private let containerView: UIView
    private let suggestionsCarousel = LMSuggestionsCarouselView()
    private let guidanceOverlay = LMCameraGuidanceOverlayView()
    private let backButton = UIButton()
    
    // MARK: - Properties
    weak var delegate: LMCameraPreviewManagerDelegate?
    private var currentState: LMCameraPreviewState = .camera
    private var suggestions: [LMCompositionSuggestion] = []
    private var selectedSuggestion: LMCompositionSuggestion?
    
    // MARK: - Initialization
    init(containerView: UIView) {
        self.containerView = containerView
        super.init()
        setupUI()
        setupConstraints()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        // 建议轮播视图设置
        suggestionsCarousel.delegate = self
        suggestionsCarousel.isHidden = true
        
        // 引导覆盖层设置
        guidanceOverlay.delegate = self
        guidanceOverlay.isHidden = true
        
        // 返回按钮设置
        setupBackButton()
        
        // 添加到容器视图
        containerView.addSubview(suggestionsCarousel)
        containerView.addSubview(guidanceOverlay)
        containerView.addSubview(backButton)
    }
    
    private func setupBackButton() {
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = UIColor.white
        backButton.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        backButton.layer.cornerRadius = 8
        backButton.layer.shadowColor = UIColor.black.cgColor
        backButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        backButton.layer.shadowRadius = 3
        backButton.layer.shadowOpacity = 0.5
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.isHidden = true
        
        // 添加模糊效果
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.layer.cornerRadius = 8
        blurView.clipsToBounds = true
        blurView.isUserInteractionEnabled = false
        backButton.insertSubview(blurView, at: 0)
        
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupConstraints() {
        // 建议轮播视图约束
        suggestionsCarousel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
            make.height.equalTo(180)
        }
        
        // 引导覆盖层约束
        guidanceOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 返回按钮约束
        backButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(60)
            make.leading.equalToSuperview().offset(16)
            make.size.equalTo(40)
        }
    }
    
    // MARK: - Public Methods
    
    /// 显示建议列表
    func showSuggestions(_ suggestions: [LMCompositionSuggestion]) {
        self.suggestions = suggestions
        currentState = .suggestions
        
        // 转换为 SuggestionDisplayModel
        let displayModels = suggestions.map { SuggestionDisplayModel(from: $0) }
        suggestionsCarousel.updateSuggestions(displayModels)
        updateViewVisibility()
    }
    
    /// 隐藏建议列表，回到相机模式
    func hideSuggestions() {
        currentState = .camera
        selectedSuggestion = nil
        updateViewVisibility()
    }
    
    /// 选择一个建议进入构图模式
    func selectSuggestion(_ suggestion: LMCompositionSuggestion) {
        selectedSuggestion = suggestion
        currentState = .composition
        
        // 显示参考图片
        // 注意：LMCompositionSuggestion 没有 image 属性，需要从 imageUrl 加载
        if let imageUrl = suggestion.imageUrl {
            // TODO: 从 URL 加载图片
            // 暂时跳过图片显示
            LMLogger.log("📷 Should load reference image from: \(imageUrl)")
        }
        
        updateViewVisibility()
    }
    
    /// 开始AR引导
    func startARGuidance() {
        guard currentState == .composition else { return }
        guidanceOverlay.startARGuidance()
    }
    
    /// 停止AR引导
    func stopARGuidance() {
        guard currentState == .composition else { return }
        guidanceOverlay.stopARGuidance()
    }
    
    /// 添加正在生成的建议卡片
    func addGeneratingSuggestion() {
        suggestionsCarousel.addGeneratingCard()
    }
    
    /// 显示引导提示
    func showGuidanceNotice(_ message: String) {
        guidanceOverlay.showGuidanceNotice(message)
    }
    
    /// 获取当前状态
    func getCurrentState() -> LMCameraPreviewState {
        return currentState
    }
    
    /// 获取选中的建议
    func getSelectedSuggestion() -> LMCompositionSuggestion? {
        return selectedSuggestion
    }
    
    // MARK: - Private Methods
    private func updateViewVisibility() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            switch self.currentState {
            case .camera:
                self.suggestionsCarousel.isHidden = true
                self.guidanceOverlay.isHidden = true
                self.backButton.isHidden = true
                
            case .suggestions:
                self.suggestionsCarousel.isHidden = false
                self.guidanceOverlay.isHidden = true
                self.backButton.isHidden = false
                
            case .composition:
                self.suggestionsCarousel.isHidden = true
                self.guidanceOverlay.isHidden = false
                self.backButton.isHidden = false
            }
        }
    }
    
    private func showGiveUpConfirmation() {
        let alert = UIAlertController(
            title: "Give Up Inspires?",
            message: "You will return to the camera. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Give Up", style: .destructive) { _ in
            self.hideSuggestions()
            self.delegate?.cameraPreviewManagerDidRequestBack(self)
        })
        
        // 获取当前视图控制器来展示alert
        if let viewController = containerView.findViewController() {
            viewController.present(alert, animated: true)
        }
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        switch currentState {
        case .suggestions:
            showGiveUpConfirmation()
            
        case .composition:
            // 回到建议列表
            currentState = .suggestions
            guidanceOverlay.hideReferenceImage()
            updateViewVisibility()
            
        case .camera:
            break
        }
    }
}

// MARK: - LMSuggestionsCarouselViewDelegate
extension LMCameraPreviewManager: LMSuggestionsCarouselViewDelegate {
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didSelectSuggestion suggestion: LMCompositionSuggestion, at index: Int) {
        selectSuggestion(suggestion)
        delegate?.cameraPreviewManager(self, didSelectSuggestion: suggestion)
    }
    
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didToggleFavorite suggestion: LMCompositionSuggestion, at index: Int) {
        delegate?.cameraPreviewManager(self, didToggleFavorite: suggestion)
    }
    
    func suggestionsCarouselViewDidRequestMoreSuggestions(_ view: LMSuggestionsCarouselView) {
        addGeneratingSuggestion()
    }
}

// MARK: - LMCameraGuidanceOverlayViewDelegate
extension LMCameraPreviewManager: LMCameraGuidanceOverlayViewDelegate {
    func cameraGuidanceOverlayViewDidRequestCloseReference(_ view: LMCameraGuidanceOverlayView) {
        // 回到建议列表
        currentState = .suggestions
        updateViewVisibility()
    }
    
    func cameraGuidanceOverlayView(_ view: LMCameraGuidanceOverlayView, didUpdateAlignment isAligned: Bool) {
        delegate?.cameraPreviewManager(self, didUpdateARGuidanceState: isAligned)
    }
}
