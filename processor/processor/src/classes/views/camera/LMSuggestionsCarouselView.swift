//
//  LMSuggestionsCarouselView.swift
//  processor
//
//  Created by muz on 2025/11/1.
//  Refactored to use UIScrollView for better layout control
//

import UIKit
import SnapKit

// MARK: - Debug ScrollView (with touch event logging)
/// 自定义 ScrollView，用于记录触摸事件，帮助调试手势冲突问题
private class DebugScrollView: UIScrollView {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        LMLogger.log("📜 [SCROLL_TOUCH] ========== SCROLL TOUCH BEGAN ==========")
        LMLogger.log("📜 [SCROLL_TOUCH] Location: \(location)")
        LMLogger.log("📜 [SCROLL_TOUCH] ContentOffset: \(contentOffset)")
        LMLogger.log("📜 [SCROLL_TOUCH] isDragging: \(isDragging)")
        LMLogger.log("📜 [SCROLL_TOUCH] isDecelerating: \(isDecelerating)")
        LMLogger.log("📜 [SCROLL_TOUCH] isScrollEnabled: \(isScrollEnabled)")
        LMLogger.log("📜 [SCROLL_TOUCH] panGestureRecognizer.state: \(panGestureRecognizer.state.rawValue)")
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)
        let delta = CGPoint(x: location.x - previousLocation.x, y: location.y - previousLocation.y)
        
        // 只记录显著的移动
        if abs(delta.x) > 5 || abs(delta.y) > 5 {
            LMLogger.log("📜 [SCROLL_TOUCH] ========== SCROLL TOUCH MOVED ==========")
            LMLogger.log("📜 [SCROLL_TOUCH] Delta: \(delta)")
            LMLogger.log("📜 [SCROLL_TOUCH] isDragging: \(isDragging)")
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        LMLogger.log("📜 [SCROLL_TOUCH] ========== SCROLL TOUCH ENDED ==========")
        LMLogger.log("📜 [SCROLL_TOUCH] ContentOffset: \(contentOffset)")
        LMLogger.log("📜 [SCROLL_TOUCH] isDragging: \(isDragging)")
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        LMLogger.log("📜 [SCROLL_TOUCH] ========== SCROLL TOUCH CANCELLED ==========")
        LMLogger.log("📜 [SCROLL_TOUCH] ⚠️ ScrollView touch was cancelled")
    }
}

protocol LMSuggestionsCarouselViewDelegate: AnyObject {
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didSelectSuggestion suggestion: LMCompositionSuggestion, at index: Int)
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didToggleFavorite suggestion: LMCompositionSuggestion, at index: Int)
    func suggestionsCarouselViewDidRequestMoreSuggestions(_ view: LMSuggestionsCarouselView)
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didSwipeUpSuggestion suggestion: LMCompositionSuggestion, at index: Int)
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didSwipeUpWithOffset offset: CGFloat)
    func suggestionsCarouselViewDidTapPickFromAlbum(_ view: LMSuggestionsCarouselView)
}

class LMSuggestionsCarouselView: UIView {
    
    // MARK: - UI Components
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var cardViews: [LMSuggestionCardView] = []
    private var uploadCardView: LMUploadReferenceCardView?
    private let swipeHintLabel = UILabel()
    
    /// Display index 0 = upload card; suggestion display index = data index + 1.
    private let uploadSlotOffset = 1
    
    // MARK: - Properties
    weak var delegate: LMSuggestionsCarouselViewDelegate?
    private var suggestions: [LMCompositionSuggestion] = []
    private var favoriteSuggestionIds: Set<String> = [] // 收藏的构图方案ID集合
    private var selectedIndex: Int = -1 // -1 表示未选中任何卡片
    private var isUpdatingSuggestions: Bool = false // 防止并发更新
    private var lastDataHash: Int = 0 // 上次数据的哈希值，用于检测数据是否真正变化
    private var placeholderProgressStartDates: [String: Date] = [:]
    
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
        
        // 配置 ScrollView（使用 DebugScrollView 来记录触摸事件）
        scrollView = DebugScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        // ✅ CRITICAL FIX: Set clipsToBounds = false to allow enlarged cards to extend beyond bounds
        // This prevents the top of selected cards from being clipped when they scale up and move up
        scrollView.clipsToBounds = false
        scrollView.decelerationRate = .fast
        scrollView.delegate = self // 设置代理以监听滚动事件
        
        // 性能优化：减少离屏渲染
        scrollView.layer.shouldRasterize = false
        
        // 配置 ContentView
        contentView = UIView()
        contentView.backgroundColor = .clear
        
        scrollView.addSubview(contentView)
        addSubview(scrollView)

        swipeHintLabel.text = LMLaunageManager.shared.camera.swipeUpToSelectHint
        swipeHintLabel.font = .systemFont(ofSize: 11, weight: .regular)
        swipeHintLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        swipeHintLabel.textAlignment = .center
        addSubview(swipeHintLabel)
    }
    
    private func setupConstraints() {
        swipeHintLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-2)
        }

        scrollView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(swipeHintLabel.snp.top).offset(-8)
        }
    }

    /// Total carousel items including upload slot at index 0.
    private var displayItemCount: Int {
        uploadSlotOffset + cardViews.count
    }

    private func suggestionIndex(forDisplayIndex displayIndex: Int) -> Int? {
        guard displayIndex >= uploadSlotOffset else { return nil }
        let idx = displayIndex - uploadSlotOffset
        return idx < suggestions.count ? idx : nil
    }

    private func displayIndex(forSuggestionIndex suggestionIndex: Int) -> Int {
        suggestionIndex + uploadSlotOffset
    }

    private var swipeUpThreshold: CGFloat {
        60.0 * screenScaleFactor
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
        let isInitialLoad = uploadCardView == nil && cardViews.isEmpty
        
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
        cleanupPlaceholderProgressState()
        
        // 同步加载已保存构图 ID 集合（避免异步导致的状态问题）
        // 对于小数据量，同步操作更可靠
        loadSavedIdeaIds()
        
        // ✅ CRITICAL: Only use smartUpdateCardViews for non-initial updates
        // Initial load must create all cards from scratch
        if isInitialLoad {
            createCardViews()
            LMLogger.log("✅ Initial load: Created upload + \(cardViews.count) suggestion cards")
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
            scrollToCard(at: 0, animated: false)
            LMLogger.log("✅ Initial load: Carousel starts at upload card (index 0), no default selection")
        } else if previousSelectedIndex >= uploadSlotOffset {
            let suggestionIdx = previousSelectedIndex - uploadSlotOffset
            if suggestionIdx < suggestions.count {
                selectSuggestionSync(at: previousSelectedIndex, animated: false)
                LMLogger.log("✅ Restored selection at display index: \(previousSelectedIndex)")
            }
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
    
    /// 加载已保存构图 ID 集合（异步版本，避免阻塞主线程）
    private func loadSavedIdeaIdsAsync(completion: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let savedIdeas = LMPhotoStorageManager.shared.fetchAllSavedIdeas()
            let ids = Set(savedIdeas.compactMap { $0.id })
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.favoriteSuggestionIds = ids
                LMLogger.log("💡 Loaded \(ids.count) saved composition IDs (async)")
                completion()
            }
        }
    }
    
    private func placeholderProgressKey(for suggestion: LMCompositionSuggestion, index: Int) -> String {
        if let id = suggestion.id, !id.isEmpty {
            return "id:\(id)"
        }
        if let rank = suggestion.rank {
            return "rank:\(rank)"
        }
        return "index:\(index)"
    }
    
    private func placeholderProgressStartDate(for suggestion: LMCompositionSuggestion, index: Int) -> Date? {
        guard suggestion.ready != true else { return nil }
        let key = placeholderProgressKey(for: suggestion, index: index)
        if let existing = placeholderProgressStartDates[key] {
            return existing
        }
        let startDate = Date()
        placeholderProgressStartDates[key] = startDate
        return startDate
    }
    
    private func cleanupPlaceholderProgressState() {
        let validKeys = Set(suggestions.enumerated().filter { $0.element.ready != true }.map { placeholderProgressKey(for: $0.element, index: $0.offset) })
        placeholderProgressStartDates = placeholderProgressStartDates.filter { validKeys.contains($0.key) }
    }
    
    private func configureCardView(_ cardView: LMSuggestionCardView, with suggestion: LMCompositionSuggestion, index: Int) {
        let isFavorite = suggestion.id.map { favoriteSuggestionIds.contains($0) } ?? false
        cardView.tag = index
        cardView.configure(
            with: suggestion,
            isFavorite: isFavorite,
            placeholderProgressStartDate: placeholderProgressStartDate(for: suggestion, index: index)
        )
    }
    
    /// 加载已保存构图 ID 集合（同步版本，仅用于非关键路径）
    private func loadSavedIdeaIds() {
        let savedIdeas = LMPhotoStorageManager.shared.fetchAllSavedIdeas()
        favoriteSuggestionIds = Set(savedIdeas.compactMap { $0.id })
        LMLogger.log("💡 Loaded \(favoriteSuggestionIds.count) saved composition IDs")
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
                configureCardView(cardView, with: suggestion, index: index)
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
                configureCardView(cardView, with: suggestion, index: index)
            }
            
            LMLogger.log("➖ Removed \(existingCount - newCount) card views")
        }
        // 情况3：数量相同，只更新数据
        else {
            // ✅ FIX: 同步更新 tag，异步加载图片
            for (index, cardView) in cardViews.enumerated() {
                let suggestion = suggestions[index]
                configureCardView(cardView, with: suggestion, index: index)
            }
            
            LMLogger.log("🔄 Updated data for \(cardViews.count) existing card views")
        }
    }
    
    func selectSuggestion(at suggestionIndex: Int, animated: Bool = true) {
        let displayIndex = displayIndex(forSuggestionIndex: suggestionIndex)
        selectSuggestionSync(at: displayIndex, animated: animated)
    }
    
    /// 同步版本的选择方法，避免额外的异步调度
    private func selectSuggestionSync(at displayIndex: Int, animated: Bool = true) {
        guard displayIndex >= 0 && displayIndex < displayItemCount else { return }

        let previousIndex = selectedIndex
        selectedIndex = displayIndex

        if previousIndex > 0 {
            let prevSuggestion = previousIndex - uploadSlotOffset
            if prevSuggestion >= 0 && prevSuggestion < cardViews.count {
                cardViews[prevSuggestion].isSelected = false
            }
        }
        uploadCardView?.applySelectionStyle(isSelected: false, borderWidth: selectedBorderWidth)

        if displayIndex == 0 {
            uploadCardView?.applySelectionStyle(isSelected: true, borderWidth: selectedBorderWidth)
        } else {
            let suggestionIndex = displayIndex - uploadSlotOffset
            if suggestionIndex < cardViews.count {
                cardViews[suggestionIndex].isSelected = true
            }
        }

        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.layoutCardViews()
            } completion: { _ in
                self.scrollToCard(at: displayIndex, animated: true)
            }
        } else {
            scrollToCard(at: displayIndex, animated: false)
        }
    }
    
    func resetPlaceholderProgressState() {
        placeholderProgressStartDates.removeAll()
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
        let progressStartDate = placeholderProgressStartDate(for: suggestion, index: index)
        
        DispatchQueue.main.async {
            cardView.configure(with: suggestion, isFavorite: suggestion.id.map { self.favoriteSuggestionIds.contains($0) } ?? false, placeholderProgressStartDate: progressStartDate)
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
            let progressStartDate = placeholderProgressStartDate(for: suggestion, index: index)
            
            DispatchQueue.main.async {
                cardView.configure(with: suggestion, isFavorite: suggestion.id.map { self.favoriteSuggestionIds.contains($0) } ?? false, placeholderProgressStartDate: progressStartDate)
            }
        }
        
        // ✅ 更新数据哈希
        lastDataHash = calculateDataHash(suggestions)
        
        LMLogger.log("✅ Batch updated \(updates.count) suggestions (no list refresh)")
    }
    
    // MARK: - Private Methods
    
    private func createCardViews() {
        let upload = LMUploadReferenceCardView()
        upload.onTap = { [weak self] in
            guard let self else { return }
            self.delegate?.suggestionsCarouselViewDidTapPickFromAlbum(self)
        }
        uploadCardView = upload
        contentView.addSubview(upload)

        for (index, suggestion) in suggestions.enumerated() {
            let cardView = createCardView(for: suggestion, at: index)
            cardViews.append(cardView)
            contentView.addSubview(cardView)
        }
    }
    
    private func createCardView(for suggestion: LMCompositionSuggestion, at index: Int) -> LMSuggestionCardView {
        let cardView = LMSuggestionCardView(frame: .zero)
        configureCardView(cardView, with: suggestion, index: index)
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
        let itemCount = displayItemCount
        guard itemCount > 0 else { return }

        let totalWidth = sideInset
            + CGFloat(itemCount) * normalCardSize.width
            + CGFloat(max(0, itemCount - 1)) * cardSpacing
            + sideInset

        let contentHeight = max(scrollView.bounds.height, selectedCardSize.height)
        let newContentSize = CGSize(width: totalWidth, height: contentHeight)

        if abs(contentView.frame.width - newContentSize.width) > 0.5
            || abs(contentView.frame.height - newContentSize.height) > 0.5 {
            contentView.frame = CGRect(origin: .zero, size: newContentSize)
            scrollView.contentSize = newContentSize
        }

        var currentX = sideInset

        if let upload = uploadCardView {
            layoutItem(
                upload,
                displayIndex: 0,
                currentX: &currentX,
                contentHeight: contentHeight,
                isUpload: true
            )
        }

        for (suggestionIndex, cardView) in cardViews.enumerated() {
            layoutItem(
                cardView,
                displayIndex: suggestionIndex + uploadSlotOffset,
                currentX: &currentX,
                contentHeight: contentHeight,
                isUpload: false
            )
        }
    }

    private func layoutItem(
        _ view: UIView,
        displayIndex: Int,
        currentX: inout CGFloat,
        contentHeight: CGFloat,
        isUpload: Bool
    ) {
        let isSelected = displayIndex == selectedIndex
        let cardSize = isSelected ? selectedCardSize : normalCardSize
        let y = contentHeight - cardSize.height - (isSelected ? selectedYOffset : 0)

        var xOffset: CGFloat = 0
        if selectedIndex >= 0 && displayIndex > selectedIndex {
            xOffset = selectedCardSize.width - normalCardSize.width
        }

        view.frame = CGRect(
            x: currentX + xOffset,
            y: y,
            width: cardSize.width,
            height: cardSize.height
        )

        if let upload = view as? LMUploadReferenceCardView {
            upload.applySelectionStyle(isSelected: isSelected, borderWidth: selectedBorderWidth)
            upload.transform = isSelected
                ? CGAffineTransform(scaleX: selectedScale, y: selectedScale)
                : .identity
        } else if let card = view as? LMSuggestionCardView {
            card.isSelected = isSelected
            card.layer.borderWidth = isSelected ? selectedBorderWidth : 1
        }

        currentX += normalCardSize.width + cardSpacing
    }

    private func scrollToCard(at displayIndex: Int, animated: Bool) {
        guard displayIndex >= 0 && displayIndex < displayItemCount else { return }

        let targetView: UIView?
        if displayIndex == 0 {
            targetView = uploadCardView
        } else {
            let suggestionIndex = displayIndex - uploadSlotOffset
            targetView = suggestionIndex < cardViews.count ? cardViews[suggestionIndex] : nil
        }
        guard let cardView = targetView else { return }

        if displayIndex == 0 {
            scrollView.setContentOffset(.zero, animated: animated)
            return
        }

        let cardCenterX = cardView.frame.midX
        let scrollViewCenterX = scrollView.bounds.width / 2
        let targetOffsetX = cardCenterX - scrollViewCenterX
        let maxOffsetX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        let clampedOffsetX = max(0, min(targetOffsetX, maxOffsetX))
        scrollView.setContentOffset(CGPoint(x: clampedOffsetX, y: 0), animated: animated)
    }
    
    @objc private func cardTapped(_ gesture: UITapGestureRecognizer) {
        guard let cardView = gesture.view as? LMSuggestionCardView else { return }
        let suggestionIndex = cardView.tag
        let displayIndex = displayIndex(forSuggestionIndex: suggestionIndex)

        guard suggestionIndex >= 0 && suggestionIndex < suggestions.count && suggestionIndex < cardViews.count else {
            LMLogger.log("⚠️ Invalid tap index: \(suggestionIndex), suggestions count: \(suggestions.count)")
            return
        }
        
        // ✅ 状态检查：只在空闲或滚动减速状态下允许点击
        switch gestureState {
        case .idle, .scrollDecelerating:
            break // 允许继续
        default:
            LMLogger.log("👆 [TAP] Tap ignored due to state: \(gestureState.description)")
            return
        }
        
        LMLogger.log("👆 [TAP] Card tapped at suggestion index: \(suggestionIndex), display: \(displayIndex)")

        if displayIndex != selectedIndex {
            guard transitionToState(.cardTapping(index: displayIndex)) else { return }
            selectSuggestionSync(at: displayIndex, animated: true)
            transitionToState(.idle)

            let suggestion = suggestions[suggestionIndex]
            delegate?.suggestionsCarouselView(self, didSelectSuggestion: suggestion, at: suggestionIndex)
        }
    }
    
    // MARK: - Gesture State Machine
    private enum GestureInteractionState {
        case idle                           // 空闲状态
        case scrolling                      // 正在滚动列表
        case scrollDecelerating             // 滚动减速中
        case cardTapping(index: Int)        // 正在点击卡片
        case cardDragging(index: Int)       // 正在拖拽卡片（上滑）
        case cardDragEnding(index: Int)     // 拖拽结束中（动画播放）
        
        func canTransitionTo(_ newState: GestureInteractionState) -> Bool {
            switch (self, newState) {
            // 空闲状态可以转换到任何状态
            case (.idle, _):
                return true
                
            // 滚动状态只能转换到减速或空闲
            case (.scrolling, .scrollDecelerating),
                 (.scrolling, .idle),
                 (.scrolling, .scrolling): // 允许保持滚动状态
                return true
                
            // 减速状态只能转换到空闲或保持减速状态
            case (.scrollDecelerating, .idle),
                 (.scrollDecelerating, .scrollDecelerating): // 允许保持减速状态
                return true
                
            // 点击状态只能转换到空闲
            case (.cardTapping, .idle):
                return true
                
            // 拖拽状态可以转换到拖拽结束或空闲
            case (.cardDragging, .cardDragEnding),
                 (.cardDragging, .idle):
                return true
                
            // 拖拽结束状态只能转换到空闲
            case (.cardDragEnding, .idle):
                return true
                
            // 其他转换不允许
            default:
                return false
            }
        }
        
        var description: String {
            switch self {
            case .idle: return "idle"
            case .scrolling: return "scrolling"
            case .scrollDecelerating: return "scrollDecelerating"
            case .cardTapping(let index): return "cardTapping(\(index))"
            case .cardDragging(let index): return "cardDragging(\(index))"
            case .cardDragEnding(let index): return "cardDragEnding(\(index))"
            }
        }
    }
    
    private var gestureState: GestureInteractionState = .idle {
        didSet {
            LMLogger.log("🔄 [STATE] Gesture state changed: \(oldValue.description) -> \(gestureState.description)")
        }
    }
    
    @discardableResult
    private func transitionToState(_ newState: GestureInteractionState) -> Bool {
        guard gestureState.canTransitionTo(newState) else {
            LMLogger.log("⚠️ [STATE] Invalid transition: \(gestureState.description) -> \(newState.description)")
            return false
        }
        
        gestureState = newState
        return true
    }
    
    // MARK: - Swipe Up Gesture Properties
    private var draggedCardOriginalFrame: CGRect = .zero
    private var hasNotifiedSwipeUpOffset = false // 标记是否已通知过偏移量
    private weak var currentDraggedCardView: LMSuggestionCardView? // 当前正在拖动的卡片
    
    @objc private func cardPanned(_ gesture: UIPanGestureRecognizer) {
        guard let cardView = gesture.view as? LMSuggestionCardView else { return }
        let suggestionIndex = cardView.tag
        let displayIndex = displayIndex(forSuggestionIndex: suggestionIndex)

        guard suggestionIndex >= 0 && suggestionIndex < suggestions.count else { return }
        
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)
        
        switch gesture.state {
        case .began:
            // 状态已在 gestureRecognizerShouldBegin 中转换
            LMLogger.log("🎯 [PAN] Started dragging card at suggestion index: \(suggestionIndex), display: \(displayIndex)")
            LMLogger.log("🎯 [PAN] Initial translation: \(translation)")
            LMLogger.log("🎯 [PAN] Initial velocity: \(velocity)")
            LMLogger.log("🎯 [PAN] Card frame: \(cardView.frame)")
            
            // 记录初始状态
            currentDraggedCardView = cardView
            draggedCardOriginalFrame = cardView.frame
            hasNotifiedSwipeUpOffset = false // 重置通知标志
            
        case .changed:
            // 只在拖拽状态下处理
            guard case .cardDragging = gestureState else {
                LMLogger.log("🎯 [PAN] Changed ignored due to state: \(gestureState.description)")
                return
            }
            
            // 📊 详细日志：拖动中
            LMLogger.log("🎯 [PAN] Dragging changed - translation: \(translation), velocity: \(velocity)")
            
            // 只处理向上的拖动
            if translation.y < 0 {
                // 计算上移距离（限制最大移动距离为阈值的1.5倍）
                let moveDistance = min(abs(translation.y), swipeUpThreshold * 1.5)
                
                LMLogger.log("🎯 [PAN] Move distance: \(moveDistance), threshold: \(swipeUpThreshold)")
                
                // 应用平移变换（向上移动）
                cardView.transform = CGAffineTransform(translationX: 0, y: -moveDistance)
                
                // 根据移动距离调整透明度（提供视觉反馈）
                let progress = min(moveDistance / swipeUpThreshold, 1.0)
                cardView.alpha = 1.0 - (progress * 0.2) // 最多降低20%透明度
                
                LMLogger.log("🎯 [PAN] Progress: \(progress), alpha: \(cardView.alpha)")
                
                // 只在偏移量超过阈值且尚未通知过时，通知代理一次
                if moveDistance > 20 && !hasNotifiedSwipeUpOffset {
                    hasNotifiedSwipeUpOffset = true
                    LMLogger.log("🎯 [PAN] Notifying delegate of swipe up offset: \(moveDistance)")
                    delegate?.suggestionsCarouselView(self, didSwipeUpWithOffset: moveDistance)
                }
            } else {
                LMLogger.log("🎯 [PAN] Translation.y >= 0, ignoring (not upward swipe)")
            }
            
        case .ended, .cancelled:
            // 转换到拖拽结束状态
            guard transitionToState(.cardDragEnding(index: suggestionIndex)) else {
                return
            }
            
            // 📊 详细日志：拖动结束
            LMLogger.log("🏁 [PAN] Drag ended/cancelled - state: \(gesture.state.rawValue)")
            LMLogger.log("🏁 [PAN] Final translation: \(translation)")
            LMLogger.log("🏁 [PAN] Final velocity: \(velocity)")
            
            // 判断是否达到阈值
            let swipeDistance = abs(translation.y)
            let shouldTrigger = swipeDistance >= swipeUpThreshold && translation.y < 0
            
            LMLogger.log("🏁 [PAN] Swipe distance: \(swipeDistance), threshold: \(swipeUpThreshold), trigger: \(shouldTrigger)")
            
            if shouldTrigger {
                // 达到阈值：执行上划动画并触发回调
                LMLogger.log("⬆️ [PAN] Triggering swipe up animation")
                
                // ✅ FIX: 在触发上划动画前，先更新选中状态（display index）
                // 但不立即重新布局，避免与 transform 冲突
                let previousIndex = selectedIndex
                selectedIndex = displayIndex

                // 取消之前选中的卡片
                if previousIndex >= 0 && previousIndex != displayIndex {
                    if previousIndex == 0 {
                        uploadCardView?.applySelectionStyle(isSelected: false, borderWidth: selectedBorderWidth)
                    } else {
                        let prevSuggestionIndex = previousIndex - uploadSlotOffset
                        if prevSuggestionIndex >= 0 && prevSuggestionIndex < cardViews.count {
                            cardViews[prevSuggestionIndex].isSelected = false
                            LMLogger.log("⬆️ [PAN] Deselected previous card at display index: \(previousIndex)")
                        }
                    }
                }

                // 选中当前卡片（在动画前设置，确保状态正确）
                cardView.isSelected = true
                LMLogger.log("⬆️ [PAN] Selected current card at suggestion index: \(suggestionIndex), display: \(displayIndex)")
                
                // ⚠️ 注意：不在这里调用 layoutCardViews()
                // 因为卡片当前有 transform 变换，重新布局会导致位置错误
                // 等动画完成并重置 transform 后再重新布局
                
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    options: .curveEaseOut,
                    animations: {
                        // 继续向上移动并淡出
                        cardView.transform = CGAffineTransform(translationX: 0, y: -self.bounds.height)
                        cardView.alpha = 0
                    },
                    completion: { finished in
                        LMLogger.log("⬆️ [PAN] Swipe up animation completed (finished: \(finished))")
                        LMLogger.log("⬆️ [PAN] Card swiped up at suggestion index: \(suggestionIndex), display: \(displayIndex)")

                        // 触发上划回调（delegate 使用 suggestion data index）
                        let suggestion = self.suggestions[suggestionIndex]
                        self.delegate?.suggestionsCarouselView(
                            self,
                            didSwipeUpSuggestion: suggestion,
                            at: suggestionIndex
                        )

                        // ✅ FIX: 立即重置卡片状态并转换到空闲状态，避免阻塞后续点击
                        // 先重置 transform 和 alpha
                        cardView.transform = .identity
                        cardView.alpha = 1.0

                        // 重新布局，应用选中状态的视觉效果
                        self.layoutCardViews()

                        // 滚动到选中的卡片（居中显示）
                        self.scrollToCard(at: displayIndex, animated: true)
                        
                        // ✅ CRITICAL: 立即转换回空闲状态，允许后续点击
                        self.transitionToState(.idle)
                        
                        LMLogger.log("⬆️ [PAN] Card state reset and layout updated, state: idle")
                    }
                )
            } else {
                // 未达到阈值：回弹动画
                LMLogger.log("↩️ [PAN] Distance not enough, bouncing back")
                UIView.animate(
                    withDuration: 0.3,
                    delay: 0,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 0.5,
                    options: .curveEaseOut,
                    animations: {
                        cardView.transform = .identity
                        cardView.alpha = 1.0
                    },
                    completion: { finished in
                        LMLogger.log("↩️ [PAN] Bounce back completed (finished: \(finished))")
                        // 转换回空闲状态
                        self.transitionToState(.idle)
                    }
                )
            }
            
            // 重置状态
            currentDraggedCardView = nil
            LMLogger.log("🏁 [PAN] Drag state reset")
            
        default:
            LMLogger.log("🎯 [PAN] Gesture state: \(gesture.state.rawValue)")
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
        currentDraggedCardView = nil
        draggedCardOriginalFrame = .zero
        hasNotifiedSwipeUpOffset = false
        
        // 重置更新标志（防止异步操作残留）
        isUpdatingSuggestions = false
        
        // ✅ FIX 3: Reset ScrollView gesture recognizers to clear any stuck state
        scrollView.panGestureRecognizer.isEnabled = false
        scrollView.panGestureRecognizer.isEnabled = true
        
        // 转换回空闲状态
        gestureState = .idle
        
        LMLogger.log("🔄 Gesture state reset completed (including ScrollView and state machine)")
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
        guard let idx = suggestionIndex(forDisplayIndex: selectedIndex) else { return nil }
        return suggestions[idx]
    }

    func getSelectedCardView() -> LMSuggestionCardView? {
        guard let idx = suggestionIndex(forDisplayIndex: selectedIndex),
              idx < cardViews.count else { return nil }
        return cardViews[idx]
    }
    
    /// 获取当前选中的 carousel display index（0 = upload 位，1+ = suggestion）
    /// - Returns: display index，未选中时返回 -1
    func getSelectedIndex() -> Int {
        return selectedIndex
    }

    /// 获取当前选中的 suggestion 数据索引（不含 upload 位）
    /// - Returns: suggestion index，未选中 suggestion 时返回 -1
    func getSelectedSuggestionIndex() -> Int {
        guard let idx = suggestionIndex(forDisplayIndex: selectedIndex) else { return -1 }
        return idx
    }
    
    // MARK: - Gesture Handling
}

// MARK: - UIGestureRecognizerDelegate
extension LMSuggestionsCarouselView: UIGestureRecognizerDelegate {
    
    /// 允许多个手势同时识别
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 📊 详细日志：手势冲突判断
        let gesture1Type = type(of: gestureRecognizer)
        let gesture2Type = type(of: otherGestureRecognizer)
        let gesture1View = gestureRecognizer.view.map { type(of: $0) }
        let gesture2View = otherGestureRecognizer.view.map { type(of: $0) }
        
        LMLogger.log("🤝 [GESTURE] shouldRecognizeSimultaneously:")
        LMLogger.log("🤝 [GESTURE]   Gesture 1: \(gesture1Type) on \(gesture1View?.description() ?? "nil")")
        LMLogger.log("🤝 [GESTURE]   Gesture 2: \(gesture2Type) on \(gesture2View?.description() ?? "nil")")
        
        // ✅ FIX: 禁止 Tap 与 ScrollView 同时识别
        // 点击 item 时应该触发选中和滚动效果，而不是同时滚动列表
        
//        // 如果是卡片上的 Tap 手势，不允许与 ScrollView 的滚动手势同时识别
//        if gestureRecognizer is UITapGestureRecognizer && gestureRecognizer.view is LMSuggestionCardView {
//            if otherGestureRecognizer.view is UIScrollView {
//                return false
//            }
//        }
//        
//        // 如果是卡片上的 Pan 手势，不允许与 ScrollView 的滚动手势同时识别
//        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
//           panGesture.view is LMSuggestionCardView {
//            // 检查另一个手势是否是 ScrollView 的滚动手势
//            if otherGestureRecognizer.view is UIScrollView {
//                return false
//            }
//        }
//        
//        // ScrollView 的滚动手势不与卡片手势同时识别
//        if gestureRecognizer.view is UIScrollView {
//            if otherGestureRecognizer.view is LMSuggestionCardView {
//                return false
//            }
//        }
        
        LMLogger.log("🤝 [GESTURE]   Result: false (no simultaneous recognition)")
        return false
    }
    
    /// 手势是否应该开始
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 📊 详细日志：手势开始判断
        let gestureType = type(of: gestureRecognizer)
        let gestureView = gestureRecognizer.view.map { type(of: $0) }
        
        LMLogger.log("🎬 [GESTURE] gestureRecognizerShouldBegin:")
        LMLogger.log("🎬 [GESTURE]   Gesture: \(gestureType) on \(gestureView?.description() ?? "nil")")
        LMLogger.log("🎬 [GESTURE]   Current state: \(gestureState.description)")
        
        // Tap 手势：只在空闲或滚动减速状态下允许
        if gestureRecognizer is UITapGestureRecognizer {
            switch gestureState {
            case .idle, .scrollDecelerating:
                LMLogger.log("🎬 [GESTURE]   Tap allowed in state: \(gestureState.description)")
                return true
            default:
                LMLogger.log("🎬 [GESTURE]   Tap blocked by state: \(gestureState.description)")
                return false
            }
        }
        
        // Pan 手势：只在空闲状态下允许，且判断是否向上滑动
        if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
            guard gestureRecognizer.view is LMSuggestionCardView else {
                LMLogger.log("🎬 [GESTURE]   Pan not on card view, result: false")
                return false
            }
            
            // 检查状态
            guard case .idle = gestureState else {
                LMLogger.log("🎬 [GESTURE]   Pan blocked by state: \(gestureState.description)")
                return false
            }
            
            let translation = panGesture.translation(in: self)
            let velocity = panGesture.velocity(in: self)
            
            LMLogger.log("🎬 [GESTURE]   Pan translation: \(translation)")
            LMLogger.log("🎬 [GESTURE]   Pan velocity: \(velocity)")
            
            // ✅ 上滑手势判断逻辑（修复版 v2）：
            // 关键修复：当垂直速度足够强时（> 200），允许更大的水平分量
            // 这样可以识别快速但略带角度的上滑手势
            let absVerticalVelocity = abs(velocity.y)
            let absHorizontalVelocity = abs(velocity.x)
            let isUpwardSwipe = velocity.y < -50  // 向上速度阈值
            
            // 分两种情况：
            // 1. 强垂直速度（> 200）：允许水平速度达到垂直速度的 1.8 倍
            // 2. 中等垂直速度（150-200）：要求垂直速度 > 水平速度 * 1.5
            let hasVeryStrongVerticalVelocity = absVerticalVelocity > 200
            let isVerticalDominant = absVerticalVelocity > absHorizontalVelocity * 1.5
            
            let shouldBegin: Bool
            if hasVeryStrongVerticalVelocity {
                // 强垂直速度：允许更大的水平分量（最多 1.8 倍）
                shouldBegin = isUpwardSwipe && absHorizontalVelocity < absVerticalVelocity * 1.8
            } else {
                // 中等垂直速度：要求垂直占主导
                shouldBegin = isUpwardSwipe && isVerticalDominant && absVerticalVelocity > 150
            }
            
            LMLogger.log("🎬 [GESTURE]   isUpwardSwipe: \(isUpwardSwipe) (velocity.y < -50)")
            LMLogger.log("🎬 [GESTURE]   absVerticalVelocity: \(absVerticalVelocity), absHorizontalVelocity: \(absHorizontalVelocity)")
            LMLogger.log("🎬 [GESTURE]   hasVeryStrongVerticalVelocity: \(hasVeryStrongVerticalVelocity) (> 200)")
            LMLogger.log("🎬 [GESTURE]   isVerticalDominant: \(isVerticalDominant) (absV > absH * 1.5)")
            LMLogger.log("🎬 [GESTURE]   shouldBegin: \(shouldBegin)")
            
            if shouldBegin {
                // 尝试转换到拖拽状态
                if let cardView = gestureRecognizer.view as? LMSuggestionCardView {
                    let success = transitionToState(.cardDragging(index: cardView.tag))
                    LMLogger.log("🎬 [GESTURE]   Upward swipe detected, state transition: \(success)")
                    return success
                }
            }
            
            LMLogger.log("🎬 [GESTURE]   Not upward swipe, result: false")
            return false
        }
        
        LMLogger.log("🎬 [GESTURE]   Default result: true")
        return true
    }
    
    /// 手势是否应该要求其他手势失败
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 📊 详细日志：手势优先级判断
        let gesture1Type = type(of: gestureRecognizer)
        let gesture2Type = type(of: otherGestureRecognizer)
        
        LMLogger.log("⏳ [GESTURE] shouldRequireFailureOf:")
        LMLogger.log("⏳ [GESTURE]   Gesture 1: \(gesture1Type)")
        LMLogger.log("⏳ [GESTURE]   Gesture 2: \(gesture2Type)")
        LMLogger.log("⏳ [GESTURE]   Result: false (no waiting)")
        
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
    
    /// 保存构图方案为已保存构图
    private func saveSuggestionAsIdea(suggestion: LMCompositionSuggestion, image: UIImage? = nil) {
        LMPhotoStorageManager.shared.saveSuggestionAsIdea(suggestion: suggestion, image: image)
        LMLogger.log("💾 Saved composition without image: \(suggestion.id ?? "unknown")")
    }
    
    /// 删除已保存构图
    private func removeSavedIdea(suggestionId: String) {
        LMPhotoStorageManager.shared.deleteSavedIdea(byId: suggestionId)
        LMLogger.log("🗑️ Removed saved composition: \(suggestionId)")
    }

}

// MARK: - UIScrollViewDelegate
extension LMSuggestionsCarouselView: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        LMLogger.log("📜 [SCROLL] Will begin dragging")
        LMLogger.log("📜 [SCROLL] Current offset: \(scrollView.contentOffset)")
        
        // 转换到滚动状态
        transitionToState(.scrolling)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 📊 详细日志：滚动中（频繁触发，可选择性记录）
        // LMLogger.log("📜 [SCROLL] Did scroll - offset: \(scrollView.contentOffset)")
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        LMLogger.log("📜 [SCROLL] Will end dragging")
        LMLogger.log("📜 [SCROLL] Velocity: \(velocity)")
        LMLogger.log("📜 [SCROLL] Target offset: \(targetContentOffset.pointee)")
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        LMLogger.log("📜 [SCROLL] Did end dragging - will decelerate: \(decelerate)")
        LMLogger.log("📜 [SCROLL] Final offset: \(scrollView.contentOffset)")
        
        if decelerate {
            // 转换到减速状态
            transitionToState(.scrollDecelerating)
        } else {
            // 直接转换到空闲状态
            transitionToState(.idle)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        LMLogger.log("📜 [SCROLL] Did end decelerating")
        LMLogger.log("📜 [SCROLL] Final offset: \(scrollView.contentOffset)")
        
        // 转换到空闲状态
        transitionToState(.idle)
    }
    
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        LMLogger.log("� [SCROLL] Did end scrolling animation")
        LMLogger.log("📜 [SCROLL] Final offset: \(scrollView.contentOffset)")
        
        // 转换到空闲状态
        transitionToState(.idle)
    }
    
    /// 重置所有卡片的手势状态（已移除，使用状态机管理）
    /// 在 ScrollView 滚动结束后不再需要手动重置手势
    /// 状态机会自动管理手势的可用性
}


// MARK: - Touch Event Logging (Debug)
extension LMSuggestionsCarouselView {
    
    /// 记录触摸开始事件
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let timestamp = Date().timeIntervalSince1970
        
        LMLogger.log("👆 [TOUCH] ========== TOUCH BEGAN ==========")
        LMLogger.log("👆 [TOUCH] Timestamp: \(String(format: "%.3f", timestamp))")
        LMLogger.log("👆 [TOUCH] Location: \(location)")
        LMLogger.log("👆 [TOUCH] Touch count: \(touches.count)")
        LMLogger.log("👆 [TOUCH] View: \(self.description)")
        LMLogger.log("👆 [TOUCH] View frame: \(self.frame)")
        LMLogger.log("👆 [TOUCH] View bounds: \(self.bounds)")
        LMLogger.log("👆 [TOUCH] View isHidden: \(self.isHidden)")
        LMLogger.log("👆 [TOUCH] View isUserInteractionEnabled: \(self.isUserInteractionEnabled)")
        LMLogger.log("👆 [TOUCH] View alpha: \(self.alpha)")
        LMLogger.log("👆 [TOUCH] Current gesture state: \(gestureState.description)")
        LMLogger.log("👆 [TOUCH] Selected index: \(selectedIndex)")
        LMLogger.log("👆 [TOUCH] Card views count: \(cardViews.count)")
        
        // 检查触摸点是否在某个卡片上
        for (index, cardView) in cardViews.enumerated() {
            let cardLocation = touch.location(in: cardView)
            if cardView.bounds.contains(cardLocation) {
                LMLogger.log("👆 [TOUCH] Touch is on card at index: \(index)")
                LMLogger.log("👆 [TOUCH] Card frame: \(cardView.frame)")
                LMLogger.log("👆 [TOUCH] Card isUserInteractionEnabled: \(cardView.isUserInteractionEnabled)")
                break
            }
        }
        
        // 检查 ScrollView 的状态
        LMLogger.log("👆 [TOUCH] ScrollView isScrollEnabled: \(scrollView.isScrollEnabled)")
        LMLogger.log("👆 [TOUCH] ScrollView isUserInteractionEnabled: \(scrollView.isUserInteractionEnabled)")
        LMLogger.log("👆 [TOUCH] ScrollView contentOffset: \(scrollView.contentOffset)")
        LMLogger.log("👆 [TOUCH] ScrollView isDragging: \(scrollView.isDragging)")
        LMLogger.log("👆 [TOUCH] ScrollView isDecelerating: \(scrollView.isDecelerating)")
    }
    
    /// 记录触摸移动事件
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)
        let delta = CGPoint(x: location.x - previousLocation.x, y: location.y - previousLocation.y)
        
        // 只记录关键的移动事件（避免日志过多）
        if abs(delta.x) > 5 || abs(delta.y) > 5 {
            LMLogger.log("👆 [TOUCH] ========== TOUCH MOVED ==========")
            LMLogger.log("👆 [TOUCH] Location: \(location)")
            LMLogger.log("👆 [TOUCH] Delta: \(delta)")
            LMLogger.log("👆 [TOUCH] Current gesture state: \(gestureState.description)")
        }
    }
    
    /// 记录触摸结束事件
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let timestamp = Date().timeIntervalSince1970
        
        LMLogger.log("👆 [TOUCH] ========== TOUCH ENDED ==========")
        LMLogger.log("👆 [TOUCH] Timestamp: \(String(format: "%.3f", timestamp))")
        LMLogger.log("👆 [TOUCH] Location: \(location)")
        LMLogger.log("👆 [TOUCH] Touch count: \(touches.count)")
        LMLogger.log("👆 [TOUCH] Current gesture state: \(gestureState.description)")
    }
    
    /// 记录触摸取消事件
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let timestamp = Date().timeIntervalSince1970
        
        LMLogger.log("👆 [TOUCH] ========== TOUCH CANCELLED ==========")
        LMLogger.log("👆 [TOUCH] Timestamp: \(String(format: "%.3f", timestamp))")
        LMLogger.log("👆 [TOUCH] Location: \(location)")
        LMLogger.log("👆 [TOUCH] Touch count: \(touches.count)")
        LMLogger.log("👆 [TOUCH] Current gesture state: \(gestureState.description)")
        LMLogger.log("👆 [TOUCH] ⚠️ Touch was cancelled - possible gesture conflict or view hierarchy issue")
    }
    
    /// 检查点击测试（用于调试视图层级问题）
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        
        // 只在触摸开始时记录 hitTest 结果
        if event?.type == .touches {
            LMLogger.log("👆 [HIT_TEST] Point: \(point)")
            LMLogger.log("👆 [HIT_TEST] Result: \(result?.description ?? "nil")")
            LMLogger.log("👆 [HIT_TEST] Self: \(self.description)")
            LMLogger.log("👆 [HIT_TEST] Self isHidden: \(self.isHidden)")
            LMLogger.log("👆 [HIT_TEST] Self isUserInteractionEnabled: \(self.isUserInteractionEnabled)")
            LMLogger.log("👆 [HIT_TEST] Self alpha: \(self.alpha)")
            
            // 如果 hitTest 返回 nil，说明触摸被拦截或视图不可交互
            if result == nil {
                LMLogger.log("👆 [HIT_TEST] ⚠️ hitTest returned nil - touch will be ignored!")
                LMLogger.log("👆 [HIT_TEST] Possible reasons:")
                LMLogger.log("👆 [HIT_TEST]   1. View is hidden (isHidden = true)")
                LMLogger.log("👆 [HIT_TEST]   2. View interaction is disabled (isUserInteractionEnabled = false)")
                LMLogger.log("👆 [HIT_TEST]   3. View alpha is too low (alpha < 0.01)")
                LMLogger.log("👆 [HIT_TEST]   4. Point is outside view bounds")
                LMLogger.log("👆 [HIT_TEST]   5. Another view is blocking this view")
            }
        }
        
        return result
    }
}
