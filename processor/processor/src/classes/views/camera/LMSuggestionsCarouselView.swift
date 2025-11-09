//
//  LMSuggestionsCarouselView.swift
//  processor
//
//  Created by Kiro on 2025/11/1.
//

import UIKit
import SnapKit

protocol LMSuggestionsCarouselViewDelegate: AnyObject {
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didSelectSuggestion suggestion: LMSuggestion, at index: Int)
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didToggleFavorite suggestion: LMSuggestion, at index: Int)
    func suggestionsCarouselViewDidRequestMoreSuggestions(_ view: LMSuggestionsCarouselView)
}

struct LMSuggestion {
    let id: String
    let title: String?
    let description: String?
    let imageURL: String?
    let image: UIImage?
    let personBoundingBox: BoundingBox?
    let confidence: Double?
    let isFavorite: Bool
    let isGenerating: Bool
    
    init(id: String, 
         title: String? = nil,
         description: String? = nil,
         imageURL: String? = nil, 
         image: UIImage? = nil,
         personBoundingBox: BoundingBox? = nil,
         confidence: Double? = nil,
         isFavorite: Bool = false, 
         isGenerating: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.image = image
        self.personBoundingBox = personBoundingBox
        self.confidence = confidence
        self.isFavorite = isFavorite
        self.isGenerating = isGenerating
    }
    
    /// 从 SuggestionItem 创建（新的 API 模型）
    init(from item: SuggestionItem) {
        self.init(
            id: item.id,
            title: item.sceneType,
            description: "Rank: \(item.rank), Score: \(String(format: "%.2f", item.score ?? 0))",
            imageURL: item.imageUrl,
            personBoundingBox: nil, // SuggestionItem 不包含 personBoundingBox
            confidence: item.score,
            isFavorite: false,
            isGenerating: !item.ready
        )
    }
    
    /// 从 CompositionSuggestion 创建（旧的 API 模型，保留兼容性）
    init(from suggestion: CompositionSuggestion) {
        self.init(
            id: suggestion.id,
            title: suggestion.title,
            description: suggestion.description,
            imageURL: suggestion.referenceImageUrl,
            personBoundingBox: suggestion.personBoundingBox,
            confidence: suggestion.confidence,
            isFavorite: false,
            isGenerating: false
        )
    }
}

class LMSuggestionsCarouselView: UIView {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var suggestionCards: [LMSuggestionCardView] = []
    
    // MARK: - Properties
    weak var delegate: LMSuggestionsCarouselViewDelegate?
    private var suggestions: [LMSuggestion] = []
    private var selectedIndex: Int = 0
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        setupGestureRecognizers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        backgroundColor = UIColor.clear
        
        // 配置滚动视图
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.isPagingEnabled = false
        scrollView.decelerationRate = .fast
        scrollView.delegate = self
        
        // 配置堆栈视图
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .bottom
        stackView.distribution = .fill
        
        addSubview(scrollView)
        scrollView.addSubview(stackView)
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }
    }
    
    private func setupGestureRecognizers() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        scrollView.addGestureRecognizer(panGesture)
    }
    
    // MARK: - Public Methods
    func updateSuggestions(_ suggestions: [LMSuggestion]) {
        self.suggestions = suggestions
        rebuildSuggestionCards()
        updateSelectedCard()
    }
    
    func selectSuggestion(at index: Int) {
        guard index >= 0 && index < suggestions.count else { return }
        selectedIndex = index
        updateSelectedCard()
        scrollToSelectedCard()
    }
    
    func addGeneratingCard() {
        let generatingSuggestion = LMSuggestion(
            id: UUID().uuidString,
            isGenerating: true
        )
        suggestions.append(generatingSuggestion)
        
        let cardView = createSuggestionCard(for: generatingSuggestion, at: suggestions.count - 1)
        suggestionCards.append(cardView)
        stackView.addArrangedSubview(cardView)
    }
    
    // MARK: - Private Methods
    private func rebuildSuggestionCards() {
        // 清除现有卡片
        suggestionCards.forEach { $0.removeFromSuperview() }
        suggestionCards.removeAll()
        
        // 创建新卡片
        for (index, suggestion) in suggestions.enumerated() {
            let cardView = createSuggestionCard(for: suggestion, at: index)
            suggestionCards.append(cardView)
            stackView.addArrangedSubview(cardView)
        }
    }
    
    private func createSuggestionCard(for suggestion: LMSuggestion, at index: Int) -> LMSuggestionCardView {
        let cardView = LMSuggestionCardView()
        cardView.configure(with: suggestion)
        cardView.tag = index
        
        // 添加点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleCardTap(_:)))
        cardView.addGestureRecognizer(tapGesture)
        
        // 设置卡片代理
        cardView.delegate = self
        
        return cardView
    }
    
    private func updateSelectedCard() {
        for (index, cardView) in suggestionCards.enumerated() {
            let isSelected = index == selectedIndex
            cardView.setSelected(isSelected, animated: true)
            
            // 更新相邻卡片的边距
            updateAdjacentCardMargins(for: index, isSelected: isSelected)
        }
    }
    
    private func updateAdjacentCardMargins(for index: Int, isSelected: Bool) {
        if isSelected {
            // 为选中卡片的相邻卡片添加额外边距
            if index > 0 {
                suggestionCards[index - 1].addAdjacentMargin(.right)
            }
            if index < suggestionCards.count - 1 {
                suggestionCards[index + 1].addAdjacentMargin(.left)
            }
        } else {
            // 移除边距
            suggestionCards[index].removeAdjacentMargins()
        }
    }
    
    private func scrollToSelectedCard() {
        guard selectedIndex < suggestionCards.count else { return }
        
        let cardView = suggestionCards[selectedIndex]
        let cardFrame = cardView.frame
        let scrollViewBounds = scrollView.bounds
        
        let targetX = cardFrame.midX - scrollViewBounds.width / 2
        let clampedX = max(0, min(targetX, scrollView.contentSize.width - scrollViewBounds.width))
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.scrollView.contentOffset = CGPoint(x: clampedX, y: 0)
        }
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleCardTap(_ gesture: UITapGestureRecognizer) {
        guard let cardView = gesture.view as? LMSuggestionCardView else { return }
        let index = cardView.tag
        
        if index != selectedIndex {
            selectedIndex = index
            updateSelectedCard()
            scrollToSelectedCard()
            
            let suggestion = suggestions[index]
            delegate?.suggestionsCarouselView(self, didSelectSuggestion: suggestion, at: index)
        }
    }
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        // 处理拖拽手势以实现平滑滚动
        switch gesture.state {
        case .ended, .cancelled:
            snapToNearestCard()
        default:
            break
        }
    }
    
    private func snapToNearestCard() {
        let scrollViewCenter = scrollView.contentOffset.x + scrollView.bounds.width / 2
        var nearestIndex = 0
        var minDistance = CGFloat.greatestFiniteMagnitude
        
        for (index, cardView) in suggestionCards.enumerated() {
            let cardCenter = cardView.frame.midX
            let distance = abs(cardCenter - scrollViewCenter)
            
            if distance < minDistance {
                minDistance = distance
                nearestIndex = index
            }
        }
        
        if nearestIndex != selectedIndex {
            selectedIndex = nearestIndex
            updateSelectedCard()
            
            let suggestion = suggestions[selectedIndex]
            delegate?.suggestionsCarouselView(self, didSelectSuggestion: suggestion, at: selectedIndex)
        }
        
        scrollToSelectedCard()
    }
}

// MARK: - UIScrollViewDelegate
extension LMSuggestionsCarouselView: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        snapToNearestCard()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            snapToNearestCard()
        }
    }
}

// MARK: - LMSuggestionCardViewDelegate
extension LMSuggestionsCarouselView: LMSuggestionCardViewDelegate {
    func suggestionCardView(_ cardView: LMSuggestionCardView, didToggleFavorite isFavorite: Bool) {
        let index = cardView.tag
        guard index < suggestions.count else { return }
        
        var suggestion = suggestions[index]
        suggestion = LMSuggestion(
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
        
        delegate?.suggestionsCarouselView(self, didToggleFavorite: suggestion, at: index)
    }
}