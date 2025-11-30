//
//  LMSuggestionsCarouselView.swift
//  processor
//
//  Created by muz on 2025/11/1.
//  Refactored to use UIScrollView for better layout control
//

import UIKit
import SnapKit

protocol LMSuggestionsCarouselViewDelegate: AnyObject {
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didSelectSuggestion suggestion: LMCompositionSuggestion, at index: Int)
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didToggleFavorite suggestion: LMCompositionSuggestion, at index: Int)
    func suggestionsCarouselViewDidRequestMoreSuggestions(_ view: LMSuggestionsCarouselView)
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didSwipeUpSuggestion suggestion: LMCompositionSuggestion, at index: Int)
}

// MARK: - Suggestion Display Model
struct SuggestionDisplayModel {
    let id: String
    let title: String?
    let description: String?
    let imageURL: String?
    let image: UIImage?
    let personBoundingBox: BoundingBox?
    let confidence: Double?
    let isFavorite: Bool
    let isGenerating: Bool
    let aspectRatio: Double? // 添加宽高比字段
    
    init(id: String, 
         title: String? = nil,
         description: String? = nil,
         imageURL: String? = nil, 
         image: UIImage? = nil,
         personBoundingBox: BoundingBox? = nil,
         confidence: Double? = nil,
         isFavorite: Bool = false, 
         isGenerating: Bool = false,
         aspectRatio: Double? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.image = image
        self.personBoundingBox = personBoundingBox
        self.confidence = confidence
        self.isFavorite = isFavorite
        self.isGenerating = isGenerating
        self.aspectRatio = aspectRatio
    }
    
    /// 从 LMCompositionSuggestion 创建
    init(from suggestion: LMCompositionSuggestion) {
        self.init(
            id: suggestion.id,
            title: suggestion.sceneType,
            description: "Rank: \(suggestion.rank), Score: \(String(format: "%.2f", suggestion.score ?? 0))",
            imageURL: suggestion.imageUrl,
            personBoundingBox: suggestion.personBoundingBox,
            confidence: suggestion.score,
            isFavorite: false,
            isGenerating: !suggestion.ready,
            aspectRatio: suggestion.aspectRatio
        )
    }
}

class LMSuggestionsCarouselView: UIView {
    
    // MARK: - UI Components
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var cardViews: [LMSuggestionCardView] = []
    
    // MARK: - Properties
    weak var delegate: LMSuggestionsCarouselViewDelegate?
    private var suggestions: [SuggestionDisplayModel] = []
    private var selectedIndex: Int = -1 // -1 表示未选中任何卡片
    
    // MARK: - Constants
    private let normalCardSize = CGSize(width: 75, height: 100) 
    private let cardSpacing: CGFloat = 10
    private let sideInset: CGFloat = 30
    private let selectedScale: CGFloat = 1.4
    private let selectedBorderWidth: CGFloat = 3
    private let selectedYOffset: CGFloat = 20 // 选中时向上偏移20px
    
    // 计算选中时的卡片大小
    private var selectedCardSize: CGSize {
        return CGSize(
            width: normalCardSize.width * selectedScale,
            height: normalCardSize.height * selectedScale
        )
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        configureSubviews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Subview Configuration
    private func configureSubviews() {
        backgroundColor = UIColor.clear
        
        // 配置 ScrollView
        scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = false
        scrollView.decelerationRate = .fast
        
        // 性能优化：减少离屏渲染
        scrollView.layer.shouldRasterize = false
        
        // 配置 ContentView
        contentView = UIView()
        contentView.backgroundColor = .clear
        
        scrollView.addSubview(contentView)
        addSubview(scrollView)
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    func updateSuggestions(_ suggestions: [SuggestionDisplayModel]) {
        self.suggestions = suggestions
        
        // 清除旧的 card views
        cardViews.forEach { $0.removeFromSuperview() }
        cardViews.removeAll()
        
        // 创建新的 card views
        createCardViews()
        
        // 布局 card views
        layoutCardViews()
        
        // 第一次刷新数据时，默认选中第一个项目
        if suggestions.count > 0 && selectedIndex < 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.selectSuggestion(at: 0, animated: false)
                
                // 触发 delegate 回调
                let firstSuggestion = suggestions[0]
                let compositionSuggestion = self.convertToCompositionSuggestion(
                    firstSuggestion,
                    aspectRatio: 3/4
                )
                self.delegate?.suggestionsCarouselView(
                    self,
                    didSelectSuggestion: compositionSuggestion,
                    at: 0
                )
            }
        }
    }
    
    func selectSuggestion(at index: Int, animated: Bool = true) {
        guard index >= 0 && index < cardViews.count else { return }
        
        let previousIndex = selectedIndex
        selectedIndex = index
        
        // 取消之前选中的 card
        if previousIndex >= 0 && previousIndex < cardViews.count {
            let previousCard = cardViews[previousIndex]
            previousCard.isSelected = false
        }
        
        // 选中新的 card
        let currentCard = cardViews[index]
        currentCard.isSelected = true
        
        // 重新布局所有 cards（带动画）
        if animated {
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [.curveEaseInOut, .allowUserInteraction]
            ) {
                self.layoutCardViews()
            }
        } else {
            layoutCardViews()
        }
        
        // 滚动到中心位置
        DispatchQueue.main.asyncAfter(deadline: .now() + (animated ? 0.1 : 0)) {
            self.scrollToCard(at: index, animated: animated)
        }
    }
    
    func addGeneratingCard() {
        let generatingSuggestion = SuggestionDisplayModel(
            id: UUID().uuidString,
            isGenerating: true
        )
        suggestions.append(generatingSuggestion)
        
        // 创建并添加新的 card view
        let cardView = createCardView(for: generatingSuggestion, at: cardViews.count)
        cardViews.append(cardView)
        contentView.addSubview(cardView)
        
        // 重新布局
        layoutCardViews()
    }
    
    /// 更新指定索引的构图方案
    /// - Parameters:
    ///   - suggestion: 新的构图方案数据
    ///   - index: 要更新的索引位置
    func updateSuggestion(_ suggestion: SuggestionDisplayModel, at index: Int) {
        guard index >= 0 && index < suggestions.count && index < cardViews.count else {
            LMLogger.log("⚠️ Invalid index for updating suggestion: \(index)")
            return
        }
        
        // 更新数据源
        suggestions[index] = suggestion
        
        // 更新对应的 card view
        let cardView = cardViews[index]
        cardView.configure(with: suggestion)
        
        // 如果是当前选中的卡片，可能需要重新布局以更新边框等样式
        if index == selectedIndex {
            UIView.animate(withDuration: 0.2) {
                self.layoutCardViews()
            }
        }
        
        LMLogger.log("✅ Updated suggestion at index \(index): \(suggestion.id)")
    }
    
    /// 批量更新多个构图方案
    /// - Parameter updates: 字典，key为索引，value为新的构图方案数据
    func updateSuggestions(_ updates: [Int: SuggestionDisplayModel]) {
        var needsLayout = false
        
        for (index, suggestion) in updates {
            guard index >= 0 && index < suggestions.count && index < cardViews.count else {
                LMLogger.log("⚠️ Invalid index for updating suggestion: \(index)")
                continue
            }
            
            // 更新数据源
            suggestions[index] = suggestion
            
            // 更新对应的 card view
            let cardView = cardViews[index]
            cardView.configure(with: suggestion)
            
            // 如果更新了选中的卡片，标记需要重新布局
            if index == selectedIndex {
                needsLayout = true
            }
        }
        
        // 如果需要，重新布局
        if needsLayout {
            UIView.animate(withDuration: 0.2) {
                self.layoutCardViews()
            }
        }
        
        LMLogger.log("✅ Batch updated \(updates.count) suggestions")
    }
    
    // MARK: - Private Methods
    
    private func createCardViews() {
        for (index, suggestion) in suggestions.enumerated() {
            let cardView = createCardView(for: suggestion, at: index)
            cardViews.append(cardView)
            contentView.addSubview(cardView)
        }
    }
    
    private func createCardView(for suggestion: SuggestionDisplayModel, at index: Int) -> LMSuggestionCardView {
        let cardView = LMSuggestionCardView(frame: .zero)
        cardView.configure(with: suggestion)
        cardView.delegate = self
        cardView.tag = index
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.delegate = self
        cardView.addGestureRecognizer(tapGesture)
        
        // 添加拖动手势（用于上划动画）
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(cardPanned(_:)))
        panGesture.delegate = self
        cardView.addGestureRecognizer(panGesture)
        
        return cardView
    }
    
    private func layoutCardViews() {
        guard !cardViews.isEmpty else { return }
        
        // 计算总宽度（所有卡片使用统一间距10px，左右各30px边距）
        // totalWidth = 左边距(30) + 所有卡片宽度 + 卡片间距 + 右边距(30)
        let totalWidth = sideInset + CGFloat(cardViews.count) * normalCardSize.width + CGFloat(cardViews.count - 1) * cardSpacing + sideInset
        
        // 设置 contentView 大小（高度要足够容纳放大的卡片）
        let contentHeight = max(bounds.height, selectedCardSize.height)
        
        // 只在必要时更新 contentView 的 frame 和 scrollView 的 contentSize
        if contentView.frame.size != CGSize(width: totalWidth, height: contentHeight) {
            contentView.frame = CGRect(x: 0, y: 0, width: totalWidth, height: contentHeight)
            scrollView.contentSize = CGSize(width: totalWidth, height: contentHeight)
        }
        
        // 布局每个 card
        var currentX = sideInset
        for (index, cardView) in cardViews.enumerated() {
            let isSelected = (index == selectedIndex)
            let cardSize = isSelected ? selectedCardSize : normalCardSize
            
            // 所有卡片的底部对齐到 contentView 的底部
            // 选中的卡片向上偏移20px
            let y = contentHeight - cardSize.height - (isSelected ? selectedYOffset : 0)
            
            // 如果当前卡片被选中，从左下角放大，不需要额外偏移
            // 如果当前卡片在选中卡片右侧，需要向右移动以腾出放大空间
            var xOffset: CGFloat = 0
            if selectedIndex >= 0 && index > selectedIndex {
                // 计算选中卡片放大后增加的宽度
                let extraWidth = selectedCardSize.width - normalCardSize.width
                xOffset = extraWidth
            }
            
            let newFrame = CGRect(
                x: currentX + xOffset,
                y: y,
                width: cardSize.width,
                height: cardSize.height
            )
            
            // 只在 frame 真正改变时才更新，避免不必要的布局
            if cardView.frame != newFrame {
                cardView.frame = newFrame
            }
            
            // 只在边框宽度需要改变时才更新
            let newBorderWidth = isSelected ? selectedBorderWidth : 1
            if cardView.layer.borderWidth != newBorderWidth {
                cardView.layer.borderWidth = newBorderWidth
            }
            
            // 更新下一个卡片的 x 位置
            currentX += normalCardSize.width + cardSpacing
        }
    }
    
    private func scrollToCard(at index: Int, animated: Bool) {
        guard index >= 0 && index < cardViews.count else { return }
        
        let cardView = cardViews[index]
        let cardCenterX = cardView.frame.midX
        let scrollViewCenterX = scrollView.bounds.width / 2
        let targetOffsetX = cardCenterX - scrollViewCenterX
        
        let maxOffsetX = scrollView.contentSize.width - scrollView.bounds.width
        let clampedOffsetX = max(0, min(targetOffsetX, maxOffsetX))
        
        scrollView.setContentOffset(CGPoint(x: clampedOffsetX, y: 0), animated: animated)
    }
    
    @objc private func cardTapped(_ gesture: UITapGestureRecognizer) {
        guard let cardView = gesture.view as? LMSuggestionCardView else { return }
        let index = cardView.tag
        
        LMLogger.log("👆 Card tapped at index: \(index)")
        
        if index != selectedIndex {
            selectSuggestion(at: index, animated: true)
            
            // 触发 delegate 回调
            let suggestion = suggestions[index]
            let compositionSuggestion = convertToCompositionSuggestion(suggestion)
            delegate?.suggestionsCarouselView(self, didSelectSuggestion: compositionSuggestion, at: index)
        }
    }
    
    // MARK: - Swipe Up Gesture Properties
    private let swipeUpThreshold: CGFloat = 150.0 // 生效阈值
    private var isDraggingCard = false
    private var draggedCardOriginalFrame: CGRect = .zero
    
    @objc private func cardPanned(_ gesture: UIPanGestureRecognizer) {
        guard let cardView = gesture.view as? LMSuggestionCardView else { return }
        let index = cardView.tag
        
        guard index >= 0 && index < suggestions.count else { return }
        
        let translation = gesture.translation(in: self)
//        let velocity = gesture.velocity(in: self)
        
        switch gesture.state {
        case .began:
            // 记录初始状态
            isDraggingCard = true
            draggedCardOriginalFrame = cardView.frame
            
//            // 如果拖动的不是当前选中的卡片，先选中它
//            if index != selectedIndex {
//                selectSuggestion(at: index, animated: false)
//            }
            
            LMLogger.log("🎯 Started dragging card at index: \(index)")
            
        case .changed:
            // 只处理向上的拖动
            if translation.y < 0 {
                // 计算上移距离（限制最大移动距离为阈值的1.5倍）
                let moveDistance = min(abs(translation.y), swipeUpThreshold * 1.5)
                
                // 应用平移变换（向上移动）
                cardView.transform = CGAffineTransform(translationX: 0, y: -moveDistance)
                
                // 根据移动距离调整透明度（提供视觉反馈）
                let progress = min(moveDistance / swipeUpThreshold, 1.0)
                cardView.alpha = 1.0 - (progress * 0.2) // 最多降低20%透明度
                
                LMLogger.log("📏 Dragging distance: \(moveDistance), progress: \(progress)")
            }
            
        case .ended, .cancelled:
            // 判断是否达到阈值
            let swipeDistance = abs(translation.y)
            let shouldTrigger = swipeDistance >= swipeUpThreshold && translation.y < 0
            
            LMLogger.log("🏁 Drag ended - distance: \(swipeDistance), threshold: \(swipeUpThreshold), trigger: \(shouldTrigger)")
            
            if shouldTrigger {
                // 达到阈值：执行上划动画并触发回调
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    options: .curveEaseOut,
                    animations: {
                        // 继续向上移动并淡出
                        cardView.transform = CGAffineTransform(translationX: 0, y: -self.bounds.height)
                        cardView.alpha = 0
                    },
                    completion: { _ in
                        LMLogger.log("⬆️ Card swiped up at index: \(index)")
                        
                        // 触发上划回调
                        self.selectedIndex = index
                        let suggestion = self.suggestions[index]
                        let compositionSuggestion = self.convertToCompositionSuggestion(suggestion)
                        self.delegate?.suggestionsCarouselView(
                            self,
                            didSwipeUpSuggestion: compositionSuggestion,
                            at: index
                        )
                        
                        // 重置卡片状态（延迟一点，避免用户看到）
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            cardView.transform = .identity
                            cardView.alpha = 1.0
                        }
                    }
                )
            } else {
                // 未达到阈值：回弹动画
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 0.5,
                    options: .curveEaseOut,
                    animations: {
                        cardView.transform = .identity
                        cardView.alpha = 1.0
                    }
                )
                
                LMLogger.log("↩️ Card bounced back - distance not enough")
            }
            
            // 重置状态
            isDraggingCard = false
            
        default:
            break
        }
    }
    
    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 只在 bounds 真正改变时才重新布局，避免滚动时频繁触发
        if bounds.size != scrollView.bounds.size {
            layoutCardViews()
        }
    }
    
    // MARK: - Helper Methods
    /// 将 SuggestionDisplayModel 转换为 LMCompositionSuggestion
    private func convertToCompositionSuggestion(_ displayModel: SuggestionDisplayModel, aspectRatio: Double? = nil) -> LMCompositionSuggestion {
        return LMCompositionSuggestion(
            id: displayModel.id,
            sceneType: displayModel.title ?? "",
            source: "",
            ready: !displayModel.isGenerating,
            imageUrl: displayModel.imageURL,
            similarImageUrl: nil,
            rank: 0,
            score: displayModel.confidence,
            modelVersion: "",
            personBoundingBox: displayModel.personBoundingBox,
            aspectRatio: aspectRatio ?? displayModel.aspectRatio // 优先使用传入的 aspectRatio，否则使用 displayModel 中的
        )
    }
    
    // MARK: - Public Methods
    
    /// 获取当前选中的构图方案
    /// - Returns: 当前选中的 LMCompositionSuggestion，如果没有选中则返回 nil
    func getSelectedSuggestion() -> LMCompositionSuggestion? {
        guard selectedIndex >= 0 && selectedIndex < suggestions.count else {
            return nil
        }
        
        let selectedModel = suggestions[selectedIndex]
        
        // 将 SuggestionDisplayModel 转换为 LMCompositionSuggestion
        let suggestion = LMCompositionSuggestion(
            id: selectedModel.id,
            sceneType: selectedModel.title ?? "Unknown",
            source: "carousel_selection",
            ready: !selectedModel.isGenerating,
            imageUrl: selectedModel.imageURL,
            similarImageUrl: nil,
            rank: selectedIndex + 1,
            score: selectedModel.confidence,
            modelVersion: "v1.0",
            personBoundingBox: selectedModel.personBoundingBox,
            aspectRatio: nil
        )
        
        return suggestion
    }
    
    /// 获取当前选中的索引
    /// - Returns: 当前选中的索引，如果没有选中则返回 -1
    func getSelectedIndex() -> Int {
        return selectedIndex
    }
    
    // MARK: - Gesture Handling
}

// MARK: - UIGestureRecognizerDelegate
extension LMSuggestionsCarouselView: UIGestureRecognizerDelegate {
    
    /// 允许多个手势同时识别
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 如果是卡片上的手势，不允许同时识别
        if gestureRecognizer.view is LMSuggestionCardView || otherGestureRecognizer.view is LMSuggestionCardView {
            return false
        }
        return true
    }
    
    /// 手势是否应该开始
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Pan 手势：只在卡片上生效
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            guard gestureRecognizer.view is LMSuggestionCardView else { return false }
            
            // 检查是否为向上的拖动
            let velocity = panGesture.velocity(in: self)
            let translation = panGesture.translation(in: self)
            
            // 如果是明显的横向滑动，不触发（让 scrollView 处理）
            if abs(velocity.x) > abs(velocity.y) * 2 {
                return false
            }
            
            return true
        }
        
        // Tap 手势：总是允许
        if gestureRecognizer is UITapGestureRecognizer {
            return true
        }
        
        return true
    }
    
    /// 手势是否应该要求其他手势失败
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Tap 手势应该等待 Pan 手势失败后再触发
        if gestureRecognizer is UITapGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
}

// MARK: - LMSuggestionCardViewDelegate
extension LMSuggestionsCarouselView: LMSuggestionCardViewDelegate {
    func suggestionCardView(_ cardView: LMSuggestionCardView, didToggleFavorite isFavorite: Bool) {
        // 通过 tag 获取 index
        let index = cardView.tag
        
        guard index >= 0 && index < suggestions.count else { return }
        
        var suggestion = suggestions[index]
        suggestion = SuggestionDisplayModel(
            id: suggestion.id,
            title: suggestion.title,
            description: suggestion.description,
            imageURL: suggestion.imageURL,
            image: suggestion.image,
            personBoundingBox: suggestion.personBoundingBox,
            confidence: suggestion.confidence,
            isFavorite: isFavorite,
            isGenerating: suggestion.isGenerating
        )
        suggestions[index] = suggestion
        
        // 转换为 LMCompositionSuggestion 用于 delegate 回调
        let compositionSuggestion = convertToCompositionSuggestion(suggestion)
        
        // 保存或删除 Saved Idea
        if isFavorite {
            saveSuggestionAsIdea(suggestion: compositionSuggestion, displayModel: suggestion)
        } else {
            removeSavedIdea(suggestionId: compositionSuggestion.id)
        }
        
        delegate?.suggestionsCarouselView(self, didToggleFavorite: compositionSuggestion, at: index)
    }
    
    /// 保存构图方案为 Saved Idea
    private func saveSuggestionAsIdea(suggestion: LMCompositionSuggestion, displayModel: SuggestionDisplayModel) {
        // 使用 LMPhotoStorageManager 保存
        let manager = LMPhotoStorageManager.shared
        
        // 如果有图片，使用图片；否则尝试从 URL 下载
        if let image = displayModel.image {
            manager.saveSuggestionAsIdea(suggestion: suggestion, image: image)
            LMLogger.log("💾 Saved idea with image: \(suggestion.id)")
        } else if let imageURL = displayModel.imageURL {
            // 异步下载图片并保存
            downloadAndSaveIdea(suggestion: suggestion, imageURL: imageURL)
        } else {
            // 没有图片，只保存元数据
            manager.saveSuggestionAsIdea(suggestion: suggestion, image: nil)
            LMLogger.log("💾 Saved idea without image: \(suggestion.id)")
        }
        
        // 显示成功提示
        showSaveSuccessToast()
    }
    
    /// 下载图片并保存 Idea
    private func downloadAndSaveIdea(suggestion: LMCompositionSuggestion, imageURL: String) {
        guard let url = URL(string: imageURL) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, let image = UIImage(data: data) else {
                LMLogger.log("❌ Failed to download idea image: \(error?.localizedDescription ?? "Unknown error")")
                // 即使下载失败，也保存元数据
                DispatchQueue.main.async {
                    LMPhotoStorageManager.shared.saveSuggestionAsIdea(suggestion: suggestion, image: nil)
                }
                return
            }
            
            DispatchQueue.main.async {
                LMPhotoStorageManager.shared.saveSuggestionAsIdea(suggestion: suggestion, image: image)
                LMLogger.log("💾 Saved idea with downloaded image: \(suggestion.id)")
            }
        }.resume()
    }
    
    /// 删除已保存的 Idea
    private func removeSavedIdea(suggestionId: String) {
        let manager = LMPhotoStorageManager.shared
        manager.deleteSavedIdea(byId: suggestionId)
        LMLogger.log("🗑️ Removed saved idea: \(suggestionId)")
        
        // 显示删除提示
        showRemoveSuccessToast()
    }
    
    /// 显示保存成功提示
    private func showSaveSuccessToast() {
        if let window = LMPackageManager.window {
            window.makeToast("Saved to your collection", position: .center)
        }
    }
    
    /// 显示删除成功提示
    private func showRemoveSuccessToast() {
        if let window = LMPackageManager.window {
            window.makeToast("Removed from collection", position: .center)
        }
    }
    

}
