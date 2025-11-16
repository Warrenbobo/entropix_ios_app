//
//  LMSuggestionsCarouselView.swift
//  processor
//
//  Created by Kiro on 2025/11/1.
//  Refactored to use UICollectionView for better performance
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
            isGenerating: !suggestion.ready
        )
    }
}

class LMSuggestionsCarouselView: UIView {
    
    // MARK: - UI Components
    private var collectionView: UICollectionView!
    private var flowLayout: UICollectionViewFlowLayout!
    
    // MARK: - Properties
    weak var delegate: LMSuggestionsCarouselViewDelegate?
    private var suggestions: [SuggestionDisplayModel] = []
    private var selectedIndex: Int = -1 // -1 表示未选中任何卡片
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
    // MARK: - Constants
    private let cardSize = CGSize(width: 120, height: 160) 
    private let cardSpacing: CGFloat = 26 
    private let sideInset: CGFloat = 30 
    
    // MARK: - Cell Reuse Identifier
    private let cellIdentifier = "SuggestionCell"
    
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
        backgroundColor = UIColor.clear
        
        // 配置 FlowLayout
        flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .horizontal
        flowLayout.itemSize = cardSize
        flowLayout.minimumLineSpacing = cardSpacing
        flowLayout.sectionInset = UIEdgeInsets(top: 0,
                                               left: sideInset,
                                               bottom: 0,
                                               right: sideInset)
        
        // 配置 CollectionView
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.decelerationRate = .fast
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.clipsToBounds = false
        
        // 注册 Cell
        collectionView.register(LMSuggestionCardView.self, forCellWithReuseIdentifier: cellIdentifier)
        
        addSubview(collectionView)
        
        // 添加向上滑动手势识别
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGestureRecognizer.delegate = self
        collectionView.addGestureRecognizer(panGestureRecognizer)
    }
    
    private func setupConstraints() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Public Methods
    func updateSuggestions(_ suggestions: [SuggestionDisplayModel]) {
        self.suggestions = suggestions
        collectionView.reloadData()
        if !suggestions.isEmpty {
            selectSuggestion(at: 0)
        }
    }
    
    func selectSuggestion(at index: Int) {
        guard index >= 0 && index < suggestions.count else { return }
        
        selectedIndex = index
        
        // 使用 CollectionView 的选中机制
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
    }
    
    func addGeneratingCard() {
        let generatingSuggestion = SuggestionDisplayModel(
            id: UUID().uuidString,
            isGenerating: true
        )
        suggestions.append(generatingSuggestion)
        
        let indexPath = IndexPath(item: suggestions.count - 1, section: 0)
        collectionView.insertItems(at: [indexPath])
    }
    
    // MARK: - Private Methods
    private func scrollToSelectedCard(animated: Bool) {
        guard selectedIndex >= 0 && selectedIndex < suggestions.count else { return }
        
        let indexPath = IndexPath(item: selectedIndex, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: animated)
    }
    
    private func snapToNearestCard() {
        let centerX = collectionView.contentOffset.x + collectionView.bounds.width / 2
        
        var nearestIndex = 0
        var minDistance = CGFloat.greatestFiniteMagnitude
        
        for index in 0..<suggestions.count {
            let indexPath = IndexPath(item: index, section: 0)
            guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else { continue }
            
            let cellCenterX = attributes.center.x
            let distance = abs(cellCenterX - centerX)
            
            if distance < minDistance {
                minDistance = distance
                nearestIndex = index
            }
        }
        
        if nearestIndex != selectedIndex {
            selectSuggestion(at: nearestIndex)
            
            let suggestion = suggestions[nearestIndex]
            let compositionSuggestion = convertToCompositionSuggestion(suggestion)
            delegate?.suggestionsCarouselView(self, didSelectSuggestion: compositionSuggestion, at: nearestIndex)
        }
    }
    
    // MARK: - Helper Methods
    
    /// 将 SuggestionDisplayModel 转换为 LMCompositionSuggestion
    private func convertToCompositionSuggestion(_ displayModel: SuggestionDisplayModel) -> LMCompositionSuggestion {
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
            personBoundingBox: displayModel.personBoundingBox
        )
    }
    
    // MARK: - Gesture Handling
    
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let velocity = gesture.velocity(in: self)
        
        switch gesture.state {
        case .changed:
            // 只处理向上滑动
            if translation.y < 0 {
                // 可以添加视觉反馈，例如轻微移动cell
                LMLogger.log("📱 Panning up: \(translation.y)")
            }
            
        case .ended:
            // 判断是否为向上滑动手势（向上速度 > 500 或向上移动 > 50）
            let isSwipeUp = velocity.y < -500 || translation.y < -50
            
            if isSwipeUp && selectedIndex >= 0 && selectedIndex < suggestions.count {
                LMLogger.log("⬆️ Swipe up detected - selecting suggestion at index: \(selectedIndex)")
                
                let suggestion = suggestions[selectedIndex]
                let compositionSuggestion = convertToCompositionSuggestion(suggestion)
                delegate?.suggestionsCarouselView(self, didSwipeUpSuggestion: compositionSuggestion, at: selectedIndex)
            }
            
        default:
            break
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension LMSuggestionsCarouselView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 允许pan手势与collectionView的滚动手势同时识别
        return true
    }
}

// MARK: - UICollectionViewDataSource
extension LMSuggestionsCarouselView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return suggestions.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! LMSuggestionCardView
        
        let suggestion = suggestions[indexPath.item]
        
        cell.configure(with: suggestion)
        cell.delegate = self
        
        // 不需要手动设置选中状态，CollectionView 会自动管理
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension LMSuggestionsCarouselView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let index = indexPath.item
        
        if index != selectedIndex {
            selectSuggestion(at: index)
            
            let suggestion = suggestions[index]
            let compositionSuggestion = convertToCompositionSuggestion(suggestion)
            delegate?.suggestionsCarouselView(self, didSelectSuggestion: compositionSuggestion, at: index)
        }
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
        guard let indexPath = collectionView.indexPath(for: cardView) else { return }
        let index = indexPath.item
        
        guard index < suggestions.count else { return }
        
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
        delegate?.suggestionsCarouselView(self, didToggleFavorite: compositionSuggestion, at: index)
    }
}
