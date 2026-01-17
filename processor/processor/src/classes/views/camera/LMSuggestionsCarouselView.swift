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
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didSwipeUpWithOffset offset: CGFloat)
}

class LMSuggestionsCarouselView: UIView {
    
    // MARK: - UI Components
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var cardViews: [LMSuggestionCardView] = []
    
    // MARK: - Properties
    weak var delegate: LMSuggestionsCarouselViewDelegate?
    private var suggestions: [LMCompositionSuggestion] = []
    private var favoriteSuggestionIds: Set<String> = [] // 收藏的构图方案ID集合
    private var selectedIndex: Int = -1 // -1 表示未选中任何卡片
    private var isUpdatingSuggestions: Bool = false // 防止并发更新
    private var lastDataHash: Int = 0 // 上次数据的哈希值，用于检测数据是否真正变化
    
    // MARK: - Constants
    // 基准尺寸（基于 iPhone 15 Pro 393pt 宽度设计，放大 1.1 倍）
    private let baseScreenWidth: CGFloat = 393.0
    private let baseNormalCardWidth: CGFloat = 82.5  // 75 * 1.1
    private let baseNormalCardHeight: CGFloat = 110  // 100 * 1.1
    private let baseCardSpacing: CGFloat = 11       // 10 * 1.1
    private let baseSideInset: CGFloat = 33         // 30 * 1.1
    
    // 自适应计算后的尺寸
    private var normalCardSize: CGSize {
        let scale = screenScaleFactor
        return CGSize(
            width: baseNormalCardWidth * scale,
            height: baseNormalCardHeight * scale
        )
    }
    
    private var cardSpacing: CGFloat {
        return baseCardSpacing * screenScaleFactor
    }
    
    private var sideInset: CGFloat {
        return baseSideInset * screenScaleFactor
    }
    
    private let selectedScale: CGFloat = 1.4
    private let selectedBorderWidth: CGFloat = 3
    private let selectedYOffset: CGFloat = 20 // 选中时向上偏移20px
    
    // 屏幕缩放因子
    private var screenScaleFactor: CGFloat {
        return UIScreen.main.bounds.width / baseScreenWidth
    }
    
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
        // ✅ CRITICAL FIX: Set clipsToBounds = false to allow enlarged cards to extend beyond bounds
        // This prevents the top of selected cards from being clipped when they scale up and move up
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
    func updateSuggestions(_ suggestions: [LMCompositionSuggestion]) {
        LMLogger.log("🔄 Updating suggestions: \(suggestions.count) items")
        
        // 防止并发更新导致的状态混乱
        guard !isUpdatingSuggestions else {
            LMLogger.log("⚠️ Already updating suggestions, skipping this call")
            return
        }
        
        isUpdatingSuggestions = true
        
        // ✅ Use defer to ensure flag is reset even if early return occurs
        defer {
            isUpdatingSuggestions = false
            LMLogger.log("🔓 Update lock released")
        }
        
        // ✅ CRITICAL: Check if this is initial load (first time creating cards)
        let isInitialLoad = cardViews.isEmpty
        
        // ✅ Calculate data hash to detect actual changes
        let newDataHash = calculateDataHash(suggestions)
        let dataActuallyChanged = (newDataHash != lastDataHash)
        
        if !dataActuallyChanged && !isInitialLoad {
            LMLogger.log("⏭️ Data unchanged (hash: \(newDataHash)), skipping update to prevent scroll reset")
            return
        }
        
        lastDataHash = newDataHash
        LMLogger.log("📊 Data changed (new hash: \(newDataHash)), proceeding with update")
        
        // 保存当前选中的索引
        let previousSelectedIndex = selectedIndex
        
        self.suggestions = suggestions
        
        // 同步加载已保存的 Saved Ideas ID 集合（避免异步导致的状态问题）
        // 对于小数据量，同步操作更可靠
        loadSavedIdeaIds()
        
        // ✅ CRITICAL: Only use smartUpdateCardViews for non-initial updates
        // Initial load must create all cards from scratch
        if isInitialLoad {
            // 首次加载：创建所有卡片
            createCardViews()
            LMLogger.log("✅ Initial load: Created \(cardViews.count) card views")
        } else {
            // 后续更新：智能复用现有卡片
            smartUpdateCardViews()
            LMLogger.log("✅ Smart updated \(cardViews.count) card views")
        }
        
        // 布局 card views
        layoutCardViews()
        LMLogger.log("✅ Layout completed for \(cardViews.count) cards")
        
        // ✅ Handle selection based on scenario
        if isInitialLoad {
            // ✅ 首次加载：默认选中第一个卡片（需求要求）
            if suggestions.count > 0 {
                selectSuggestionSync(at: 0, animated: false)
                
                // 触发 delegate 回调
                let firstSuggestion = suggestions[0]
                delegate?.suggestionsCarouselView(
                    self,
                    didSelectSuggestion: firstSuggestion,
                    at: 0
                )
                
                LMLogger.log("✅ Initial load: Auto-selected first suggestion with enlarged style")
            }
        } else if previousSelectedIndex >= 0 && previousSelectedIndex < suggestions.count {
            // ✅ 恢复之前的选中状态（例如从 Reference Image 返回）
            selectSuggestionSync(at: previousSelectedIndex, animated: false)
            LMLogger.log("✅ Restored selection at index: \(previousSelectedIndex)")
        }
    }
    
    /// 计算数据哈希值，用于检测数据是否真正变化
    /// 只比较关键字段：id, ready, imageUrl
    private func calculateDataHash(_ suggestions: [LMCompositionSuggestion]) -> Int {
        var hasher = Hasher()
        for suggestion in suggestions {
            hasher.combine(suggestion.id)
            hasher.combine(suggestion.ready)
            hasher.combine(suggestion.imageUrl)
        }
        return hasher.finalize()
    }
    
    /// 加载已保存的 Saved Ideas ID 集合（异步版本，避免阻塞主线程）
    private func loadSavedIdeaIdsAsync(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let savedIdeas = LMPhotoStorageManager.shared.fetchAllSavedIdeas()
            let ids = Set(savedIdeas.compactMap { $0.id })
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.favoriteSuggestionIds = ids
                LMLogger.log("💡 Loaded \(ids.count) saved idea IDs (async)")
                completion()
            }
        }
    }
    
    /// 加载已保存的 Saved Ideas ID 集合（同步版本，仅用于非关键路径）
    private func loadSavedIdeaIds() {
        let savedIdeas = LMPhotoStorageManager.shared.fetchAllSavedIdeas()
        favoriteSuggestionIds = Set(savedIdeas.compactMap { $0.id })
        LMLogger.log("💡 Loaded \(favoriteSuggestionIds.count) saved idea IDs")
    }
    
    /// 智能更新卡片视图：复用现有卡片，只更新数据，避免重复创建
    /// ⚠️ CRITICAL: 此方法不会重新添加手势，因为 CardView 只创建一次
    private func smartUpdateCardViews() {
        let newCount = suggestions.count
        let existingCount = cardViews.count
        
        // 情况1：需要添加新卡片
        if newCount > existingCount {
            // ✅ FIX: 同步更新现有卡片的数据，避免异步导致的 tag 不一致
            for (index, cardView) in cardViews.enumerated() {
                let suggestion = suggestions[index]
                let isFavorite = suggestion.id.map { favoriteSuggestionIds.contains($0) } ?? false
                
                // 同步更新 tag，避免点击时找不到正确的索引
                cardView.tag = index
                // 异步加载图片，避免阻塞主线程
                cardView.configure(with: suggestion, isFavorite: isFavorite)
            }
            
            // 创建新卡片（只在数量增加时才创建）
            for index in existingCount..<newCount {
                let suggestion = suggestions[index]
                let cardView = createCardView(for: suggestion, at: index)
                cardViews.append(cardView)
                contentView.addSubview(cardView)
            }
            
            LMLogger.log("➕ Added \(newCount - existingCount) new card views")
        }
        // 情况2：需要移除多余卡片
        else if newCount < existingCount {
            // ✅ CRITICAL: Explicitly remove gesture recognizers before removing card views
            for index in (newCount..<existingCount).reversed() {
                let cardView = cardViews[index]
                // Remove all gesture recognizers to prevent memory leaks
                cardView.gestureRecognizers?.forEach { cardView.removeGestureRecognizer($0) }
                cardView.removeFromSuperview()
                cardViews.remove(at: index)
            }
            
            // ✅ FIX: 同步更新剩余卡片的数据
            for (index, cardView) in cardViews.enumerated() {
                let suggestion = suggestions[index]
                let isFavorite = suggestion.id.map { favoriteSuggestionIds.contains($0) } ?? false
                
                cardView.tag = index
                cardView.configure(with: suggestion, isFavorite: isFavorite)
            }
            
            LMLogger.log("➖ Removed \(existingCount - newCount) card views")
        }
        // 情况3：数量相同，只更新数据
        else {
            // ✅ FIX: 同步更新 tag，异步加载图片
            for (index, cardView) in cardViews.enumerated() {
                let suggestion = suggestions[index]
                let isFavorite = suggestion.id.map { favoriteSuggestionIds.contains($0) } ?? false
                
                cardView.tag = index
                cardView.configure(with: suggestion, isFavorite: isFavorite)
            }
            
            LMLogger.log("🔄 Updated data for \(cardViews.count) existing card views")
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
    
    /// 同步版本的选择方法，避免额外的异步调度
    private func selectSuggestionSync(at index: Int, animated: Bool = true) {
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
        
        // 重新布局所有 cards（只在需要动画时才调用，避免重复布局）
        if animated {
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [.curveEaseInOut, .allowUserInteraction]
            ) {
                self.layoutCardViews()
            } completion: { _ in
                // 动画完成后滚动到中心位置
                self.scrollToCard(at: index, animated: true)
            }
        } else {
            // 非动画模式：不重复调用 layoutCardViews（调用方已经调用过）
            // 只滚动到中心位置
            scrollToCard(at: index, animated: false)
        }
    }
    
    func addGeneratingCard() {
        let generatingSuggestion = LMCompositionSuggestion(
            id: UUID().uuidString,
            sceneType: "",
            source: "aigc",
            ready: false,
            imageUrl: nil,
            width: nil,
            height: nil,
            rank: suggestions.count + 1,
            score: nil
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
    /// ⚠️ 用于轮询时单个卡片的更新，不刷新整个列表
    /// - Parameters:
    ///   - suggestion: 新的构图方案数据
    ///   - index: 要更新的索引位置
    func updateSuggestion(_ suggestion: LMCompositionSuggestion, at index: Int) {
        guard index >= 0 && index < suggestions.count && index < cardViews.count else {
            LMLogger.log("⚠️ Invalid index for updating suggestion: \(index)")
            return
        }
        
        // 更新数据源
        suggestions[index] = suggestion
        
        // ✅ CRITICAL: Update card asynchronously to prevent blocking during scroll
        let cardView = cardViews[index]
        let isFavorite = suggestion.id.map { favoriteSuggestionIds.contains($0) } ?? false
        
        DispatchQueue.main.async {
            cardView.configure(with: suggestion, isFavorite: isFavorite)
        }
        
        // ✅ 更新数据哈希，避免下次 updateSuggestions 误判为数据未变化
        lastDataHash = calculateDataHash(suggestions)
        
        LMLogger.log("✅ Updated single suggestion at index \(index): \(suggestion.id ?? "unknown") (no list refresh)")
    }
    
    /// 批量更新多个构图方案
    /// ⚠️ 用于轮询时多个卡片的更新，不刷新整个列表
    /// - Parameter updates: 字典，key为索引，value为新的构图方案数据
    func updateSuggestions(_ updates: [Int: LMCompositionSuggestion]) {
        for (index, suggestion) in updates {
            guard index >= 0 && index < suggestions.count && index < cardViews.count else {
                LMLogger.log("⚠️ Invalid index for updating suggestion: \(index)")
                continue
            }
            
            // 更新数据源
            suggestions[index] = suggestion
            
            // ✅ CRITICAL: Update card asynchronously
            let cardView = cardViews[index]
            let isFavorite = suggestion.id.map { favoriteSuggestionIds.contains($0) } ?? false
            
            DispatchQueue.main.async {
                cardView.configure(with: suggestion, isFavorite: isFavorite)
            }
        }
        
        // ✅ 更新数据哈希
        lastDataHash = calculateDataHash(suggestions)
        
        LMLogger.log("✅ Batch updated \(updates.count) suggestions (no list refresh)")
    }
    
    // MARK: - Private Methods
    
    private func createCardViews() {
        for (index, suggestion) in suggestions.enumerated() {
            let cardView = createCardView(for: suggestion, at: index)
            cardViews.append(cardView)
            contentView.addSubview(cardView)
        }
    }
    
    private func createCardView(for suggestion: LMCompositionSuggestion, at index: Int) -> LMSuggestionCardView {
        let cardView = LMSuggestionCardView(frame: .zero)
        let isFavorite = suggestion.id.map { favoriteSuggestionIds.contains($0) } ?? false
        cardView.configure(with: suggestion, isFavorite: isFavorite)
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
        let totalWidth = sideInset + CGFloat(cardViews.count) * normalCardSize.width + CGFloat(cardViews.count - 1) * cardSpacing + sideInset * 2
        
        // 设置 contentView 大小（高度要足够容纳放大的卡片）
        let contentHeight = max(bounds.height, selectedCardSize.height)
        
        // ✅ FIX 10: Use tolerance-based comparison for CGSize to avoid floating-point precision issues
        let newContentSize = CGSize(width: totalWidth, height: contentHeight)
        let sizeDifference = abs(contentView.frame.width - newContentSize.width) + abs(contentView.frame.height - newContentSize.height)
        
        // Only update if difference is significant (> 0.5 points)
        if sizeDifference > 0.5 {
            contentView.frame = CGRect(x: 0, y: 0, width: totalWidth, height: contentHeight)
            scrollView.contentSize = newContentSize
            LMLogger.log("📏 Updated contentSize to \(newContentSize)")
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
        
        // ✅ CRITICAL FIX: For first card (index 0), align to left edge instead of center
        // This prevents the card from scrolling off-screen to the left
        if index == 0 {
            // 第一个卡片：滚动到左边缘（考虑左侧边距）
            scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: animated)
            LMLogger.log("📍 Scrolled to first card (left edge)")
            return
        }
        
        // 其他卡片：滚动到中心位置
        let cardCenterX = cardView.frame.midX
        let scrollViewCenterX = scrollView.bounds.width / 2
        let targetOffsetX = cardCenterX - scrollViewCenterX
        
        let maxOffsetX = scrollView.contentSize.width - scrollView.bounds.width
        let clampedOffsetX = max(0, min(targetOffsetX, maxOffsetX))
        
        scrollView.setContentOffset(CGPoint(x: clampedOffsetX, y: 0), animated: animated)
        LMLogger.log("📍 Scrolled to card at index \(index), offset: \(clampedOffsetX)")
    }
    
    @objc private func cardTapped(_ gesture: UITapGestureRecognizer) {
        guard let cardView = gesture.view as? LMSuggestionCardView else { return }
        let index = cardView.tag
        
        // ✅ FIX: 添加索引有效性检查，避免异步更新导致的索引错误
        guard index >= 0 && index < suggestions.count && index < cardViews.count else {
            LMLogger.log("⚠️ Invalid tap index: \(index), suggestions count: \(suggestions.count)")
            return
        }
        
        LMLogger.log("👆 Card tapped at index: \(index)")
        
        if index != selectedIndex {
            // ✅ 更新选中状态
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
            
            // ✅ FIX: 使用更短的动画时间，提升响应速度
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.3,
                options: [.curveEaseInOut, .allowUserInteraction, .beginFromCurrentState]
            ) {
                self.layoutCardViews()
            } completion: { _ in
                // ✅ 动画完成后滚动到中心位置（带动画效果）
                self.scrollToCard(at: index, animated: true)
            }
            
            // 触发 delegate 回调
            let suggestion = suggestions[index]
            delegate?.suggestionsCarouselView(self, didSelectSuggestion: suggestion, at: index)
        }
    }
    
    // MARK: - Swipe Up Gesture Properties
    private let swipeUpThreshold: CGFloat = 150.0 // 生效阈值
    private var isDraggingCard = false
    private var draggedCardOriginalFrame: CGRect = .zero
    private var hasNotifiedSwipeUpOffset = false // 标记是否已通知过偏移量
    private weak var currentDraggedCardView: LMSuggestionCardView? // 当前正在拖动的卡片
    
    @objc private func cardPanned(_ gesture: UIPanGestureRecognizer) {
        guard let cardView = gesture.view as? LMSuggestionCardView else { return }
        let index = cardView.tag
        
        guard index >= 0 && index < suggestions.count else { return }
        
        switch gesture.state {
        case .began:
            // 记录初始状态
            isDraggingCard = true
            currentDraggedCardView = cardView
            draggedCardOriginalFrame = cardView.frame
            hasNotifiedSwipeUpOffset = false // 重置通知标志
            
            LMLogger.log("🎯 Started dragging card at index: \(index)")
            
        case .changed:
            let translation = gesture.translation(in: self)
            
            // 只处理向上的拖动
            if translation.y < 0 {
                // 计算上移距离（限制最大移动距离为阈值的1.5倍）
                let moveDistance = min(abs(translation.y), swipeUpThreshold * 1.5)
                
                // 应用平移变换（向上移动）
                cardView.transform = CGAffineTransform(translationX: 0, y: -moveDistance)
                
                // 根据移动距离调整透明度（提供视觉反馈）
                let progress = min(moveDistance / swipeUpThreshold, 1.0)
                cardView.alpha = 1.0 - (progress * 0.2) // 最多降低20%透明度
                
                // 只在偏移量超过阈值且尚未通知过时，通知代理一次
                if moveDistance > 20 && !hasNotifiedSwipeUpOffset {
                    hasNotifiedSwipeUpOffset = true
                    delegate?.suggestionsCarouselView(self, didSwipeUpWithOffset: moveDistance)
                }
            }
            
        case .ended, .cancelled:
            let translation = gesture.translation(in: self)
            
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
                        self.delegate?.suggestionsCarouselView(
                            self,
                            didSwipeUpSuggestion: suggestion,
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
            currentDraggedCardView = nil
            
        default:
            break
        }
    }
    
    // MARK: - State Reset
    
    /// 重置手势和拖动状态（在视图隐藏或重新显示时调用）
    func resetGestureState() {
        // 如果有正在拖动的卡片，重置其状态
        if let draggedCard = currentDraggedCardView {
            draggedCard.transform = .identity
            draggedCard.alpha = 1.0
        }
        
        // 重置所有卡片的 transform 和 alpha（防止状态残留）
        for cardView in cardViews {
            if cardView.transform != .identity {
                cardView.transform = .identity
            }
            if cardView.alpha != 1.0 {
                cardView.alpha = 1.0
            }
        }
        
        // 重置拖动状态标志
        isDraggingCard = false
        currentDraggedCardView = nil
        draggedCardOriginalFrame = .zero
        hasNotifiedSwipeUpOffset = false
        
        // 重置更新标志（防止异步操作残留）
        isUpdatingSuggestions = false
        
        // ✅ FIX 3: Reset ScrollView gesture recognizers to clear any stuck state
        scrollView.panGestureRecognizer.isEnabled = false
        scrollView.panGestureRecognizer.isEnabled = true
        
        LMLogger.log("🔄 Gesture state reset completed (including ScrollView gestures)")
    }
    
    // MARK: - Layout
    private var lastLayoutBoundsSize: CGSize = .zero
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 只在 bounds 真正改变时才重新布局，避免滚动时频繁触发
        // 使用缓存的 lastLayoutBoundsSize 而不是 scrollView.bounds.size
        // 因为 scrollView.bounds 在滚动时会频繁变化
        if bounds.size != lastLayoutBoundsSize {
            lastLayoutBoundsSize = bounds.size
            layoutCardViews()
        }
    }
    
    // MARK: - Public Methods
    
    /// 获取当前选中的构图方案
    /// - Returns: 当前选中的 LMCompositionSuggestion，如果没有选中则返回 nil
    func getSelectedSuggestion() -> LMCompositionSuggestion? {
        guard selectedIndex >= 0 && selectedIndex < suggestions.count else {
            return nil
        }
        
        return suggestions[selectedIndex]
    }
    
    /// 获取当前选中的卡片视图
    /// - Returns: 当前选中的 LMSuggestionCardView，如果没有选中则返回 nil
    func getSelectedCardView() -> LMSuggestionCardView? {
        guard selectedIndex >= 0 && selectedIndex < cardViews.count else {
            return nil
        }
        
        return cardViews[selectedIndex]
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
        // ✅ FIX: 禁止 Tap 与 ScrollView 同时识别
        // 点击 item 时应该触发选中和滚动效果，而不是同时滚动列表
        
        // 如果是卡片上的 Tap 手势，不允许与 ScrollView 的滚动手势同时识别
        if gestureRecognizer is UITapGestureRecognizer && gestureRecognizer.view is LMSuggestionCardView {
            if otherGestureRecognizer.view is UIScrollView {
                return false
            }
        }
        
        // 如果是卡片上的 Pan 手势，不允许与 ScrollView 的滚动手势同时识别
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
           panGesture.view is LMSuggestionCardView {
            // 检查另一个手势是否是 ScrollView 的滚动手势
            if otherGestureRecognizer.view is UIScrollView {
                return false
            }
        }
        
        // ScrollView 的滚动手势不与卡片手势同时识别
        if gestureRecognizer.view is UIScrollView {
            if otherGestureRecognizer.view is LMSuggestionCardView {
                return false
            }
        }
        
        return false
    }
    
    /// 手势是否应该开始
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Tap 手势：总是允许，优先级最高
        if gestureRecognizer is UITapGestureRecognizer {
            return true
        }
        
        // Pan 手势：只在卡片上生效，且只处理明显的垂直滑动
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            guard gestureRecognizer.view is LMSuggestionCardView else { return false }
            
            let velocity = panGesture.velocity(in: self)
            let translation = panGesture.translation(in: self)
            
            // ✅ FIX: 使用更宽松的判断条件，避免误拦截点击
            // 只有在明确的横向滑动时才阻止 Pan 手势
            if abs(velocity.x) > abs(velocity.y) * 1.5 {
                return false
            }
            
            // ✅ FIX: 只有在明确的向上滑动且移动距离足够时才触发
            // 这样可以避免误判点击为 Pan 手势
            if velocity.y < -50 && abs(translation.y) > 5 {
                return true
            }
            
            // ✅ FIX: 其他情况允许手势开始，但会在 changed 状态中判断
            // 这样可以避免阻塞 Tap 手势
            return false
        }
        
        return true
    }
    
    /// 手势是否应该要求其他手势失败
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // ✅ FIX: 移除 Tap 等待 Pan 的逻辑，让 Tap 手势优先响应
        // 这样可以避免点击延迟和无响应问题
        // 原逻辑会导致：点击时需要等待 Pan 手势判断失败，造成延迟
        return false
    }
}

// MARK: - LMSuggestionCardViewDelegate
extension LMSuggestionsCarouselView: LMSuggestionCardViewDelegate {
    func suggestionCardView(_ cardView: LMSuggestionCardView, didToggleFavorite isFavorite: Bool) {
        // 通过 tag 获取 index
        let index = cardView.tag
        guard index >= 0 && index < suggestions.count else { return }
        let suggestion = suggestions[index]
        
        // 确保 suggestion 有有效的 id
        guard let suggestionId = suggestion.id else {
            LMLogger.log("⚠️ Cannot toggle favorite: suggestion has no ID")
            return
        }
        
        // 更新收藏状态
        if isFavorite {
            favoriteSuggestionIds.insert(suggestionId)
            saveSuggestionAsIdea(suggestion: suggestion, image: cardView.displayedImage)
        } else {
            favoriteSuggestionIds.remove(suggestionId)
            removeSavedIdea(suggestionId: suggestionId)
        }
        
        delegate?.suggestionsCarouselView(self, didToggleFavorite: suggestion, at: index)
    }
    
    /// 保存构图方案为 Saved Idea
    private func saveSuggestionAsIdea(suggestion: LMCompositionSuggestion, image: UIImage? = nil) {
        LMPhotoStorageManager.shared.saveSuggestionAsIdea(suggestion: suggestion, image: image)
        LMLogger.log("💾 Saved idea without image: \(suggestion.id ?? "unknown")")
    }
    
    /// 删除已保存的 Idea
    private func removeSavedIdea(suggestionId: String) {
        LMPhotoStorageManager.shared.deleteSavedIdea(byId: suggestionId)
        LMLogger.log("🗑️ Removed saved idea: \(suggestionId)")
    }

}
