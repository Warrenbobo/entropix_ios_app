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
        if suggestions.count > 0 && selectedIndex < 0 {
            selectSuggestion(at: 0)
        }
    }
    
    func selectSuggestion(at index: Int, animated: Bool = true) {
        guard index >= 0 && index < suggestions.count else { return }
        selectedIndex = index
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.selectItem(at: indexPath, animated: animated, scrollPosition: .centeredHorizontally)
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
    
    func suggestionCardView(_ cardView: LMSuggestionCardView, didSwipeUp suggestion: SuggestionDisplayModel) {
        guard let indexPath = collectionView.indexPath(for: cardView) else { return }
        let index = indexPath.item
        
        LMLogger.log("⬆️ Card swiped up at index: \(index)")
        
        // 转换为 LMCompositionSuggestion 用于 delegate 回调
        let compositionSuggestion = convertToCompositionSuggestion(suggestion)
        delegate?.suggestionsCarouselView(self, didSwipeUpSuggestion: compositionSuggestion, at: index)
    }
}
