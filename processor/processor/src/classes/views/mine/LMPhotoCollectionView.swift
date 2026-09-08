//
//  LMPhotoCollectionView.swift
//  processor
//
//  Created by muz on 2025/10/6.
//

import UIKit
import SnapKit

enum TabType {
    case gallery
    case savedIdeas
    case sceneHistory
}

struct GalleryItem {
    let image: UIImage?
    let title: String?
    let id: String
    let isLivePhoto: Bool
    let livePhotoVideoPath: String?
    let imagePath: String? // 原始图片文件路径（包含元数据）
}

class LMPhotoCollectionView: UIView {
    
    // MARK: - UI Components
    private let menuTabsContainer = UIView()
    private let galleryTabButton = UIButton()
    private let savedIdeasTabButton = UIButton()
    private let sceneHistoryTabButton = UIButton()
    private let tabIndicator = UIView()
    
    // 滑动容器
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 页面视图
    private let galleryPageView = LMGalleryPageView()
    private let ideasPageView = LMIdeasPageView()
    private let sceneHistoryPageView = LMSceneHistoryPageView()
    
    private var currentTab: TabType = .gallery
    private var hasLoadedGalleryData = false
    private var hasLoadedIdeasData = false
    private var hasLoadedSceneHistoryData = false
    private var heightConstraint: Constraint?
    
    // 回调，用于通知父视图高度变化
    var onHeightChanged: ((CGFloat) -> Void)?
    // 回调，用于通知父视图tab变化
    var onTabChanged: ((TabType) -> Void)?
    /// Scene History item selection (Mine hosts navigation).
    var onSceneHistorySelected: ((LMSceneHistoryRecord, UIImage?) -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUserInterfaceComponents()
        configureLayoutConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

// MARK: - Setup Methods
extension LMPhotoCollectionView {
    
    private func setupUserInterfaceComponents() {
        addSubview(menuTabsContainer)
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // 添加页面视图到内容视图
        contentView.addSubview(galleryPageView)
        contentView.addSubview(ideasPageView)
        contentView.addSubview(sceneHistoryPageView)
        
        setupMenuTabs()
        setupScrollView()
        sceneHistoryPageView.delegate = self
    }
    
    private func setupMenuTabs() {
        menuTabsContainer.backgroundColor = UIColor.clear
        
        // Gallery Tab Button
        galleryTabButton.setTitle(LMText.profile.gallery, for: .normal)
        galleryTabButton.setTitleColor(UIColor.systemBlue, for: .selected)
        galleryTabButton.setTitleColor(UIColor.systemGray, for: .normal)
        galleryTabButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        galleryTabButton.titleLabel?.adjustsFontSizeToFitWidth = true
        galleryTabButton.isSelected = true
        galleryTabButton.addTarget(self, action: #selector(galleryTabButtonTapped), for: .touchUpInside)
        
        // Liked Suggestion tab
        savedIdeasTabButton.setTitle(LMText.profile.mineTabLikedSuggestion, for: .normal)
        savedIdeasTabButton.setTitleColor(UIColor.systemBlue, for: .selected)
        savedIdeasTabButton.setTitleColor(UIColor.systemGray, for: .normal)
        savedIdeasTabButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        savedIdeasTabButton.titleLabel?.adjustsFontSizeToFitWidth = true
        savedIdeasTabButton.addTarget(self, action: #selector(savedIdeasTabButtonTapped), for: .touchUpInside)

        sceneHistoryTabButton.setTitle(LMText.profile.mineTabSceneHistory, for: .normal)
        sceneHistoryTabButton.setTitleColor(UIColor.systemBlue, for: .selected)
        sceneHistoryTabButton.setTitleColor(UIColor.systemGray, for: .normal)
        sceneHistoryTabButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        sceneHistoryTabButton.titleLabel?.adjustsFontSizeToFitWidth = true
        sceneHistoryTabButton.addTarget(self, action: #selector(sceneHistoryTabButtonTapped), for: .touchUpInside)
        
        // Tab Indicator
        tabIndicator.backgroundColor = UIColor.systemBlue
        tabIndicator.layer.cornerRadius = 2
        
        menuTabsContainer.addSubview(galleryTabButton)
        menuTabsContainer.addSubview(savedIdeasTabButton)
        menuTabsContainer.addSubview(sceneHistoryTabButton)
        menuTabsContainer.addSubview(tabIndicator)
    }
    
    private func setupScrollView() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.backgroundColor = UIColor.clear
        scrollView.isScrollEnabled = true
        
        contentView.backgroundColor = UIColor.clear
        
        galleryPageView.disableVerticalScrolling()
        ideasPageView.disableVerticalScrolling()
        sceneHistoryPageView.disableVerticalScrolling()
    }
}

// MARK: - Layout Configuration
extension LMPhotoCollectionView {
    
    private func configureLayoutConstraints() {
        // Menu Tabs Container
        menuTabsContainer.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(60)
        }
        
        galleryTabButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(64)
        }
        
        savedIdeasTabButton.snp.makeConstraints { make in
            make.leading.equalTo(galleryTabButton.snp.trailing).offset(16)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(90)
        }

        sceneHistoryTabButton.snp.makeConstraints { make in
            make.leading.equalTo(savedIdeasTabButton.snp.trailing).offset(16)
            make.centerY.equalToSuperview()
            make.width.greaterThanOrEqualTo(90)
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }
        
        tabIndicator.snp.makeConstraints { make in
            make.bottom.equalToSuperview().offset(-8)
            make.centerX.equalTo(galleryTabButton)
            make.width.equalTo(50)
            make.height.equalTo(4)
        }
        
        // Scroll View
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(menuTabsContainer.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        // 设置整体高度约束
        self.snp.makeConstraints { make in
            heightConstraint = make.height.equalTo(400).constraint // 初始高度
        }
        
        // Content View
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(scrollView)
            make.width.equalTo(scrollView).multipliedBy(3)
        }
        
        // Gallery Page View
        galleryPageView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        // Ideas Page View
        ideasPageView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(galleryPageView.snp.trailing)
            make.width.equalTo(scrollView)
        }

        sceneHistoryPageView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(ideasPageView.snp.trailing)
            make.trailing.equalToSuperview()
            make.width.equalTo(scrollView)
        }
    }
}

// MARK: - Action Handlers
extension LMPhotoCollectionView {
    

    
    @objc private func galleryTabButtonTapped() {
        switchToTab(.gallery)
    }
    
    @objc private func savedIdeasTabButtonTapped() {
        switchToTab(.savedIdeas)
    }

    @objc private func sceneHistoryTabButtonTapped() {
        switchToTab(.sceneHistory)
    }
    
    func switchToTab(_ tab: TabType) {
        guard currentTab != tab else { return }
        
        currentTab = tab
        loadData(for: tab)
        
        galleryTabButton.isSelected = (tab == .gallery)
        savedIdeasTabButton.isSelected = (tab == .savedIdeas)
        sceneHistoryTabButton.isSelected = (tab == .sceneHistory)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
            let anchor: UIView
            switch tab {
            case .gallery: anchor = self.galleryTabButton
            case .savedIdeas: anchor = self.savedIdeasTabButton
            case .sceneHistory: anchor = self.sceneHistoryTabButton
            }
            self.tabIndicator.snp.remakeConstraints { make in
                make.bottom.equalToSuperview().offset(-8)
                make.centerX.equalTo(anchor)
                make.width.equalTo(50)
                make.height.equalTo(4)
            }
            self.layoutIfNeeded()
        }
        
        let pageIndex: CGFloat
        switch tab {
        case .gallery: pageIndex = 0
        case .savedIdeas: pageIndex = 1
        case .sceneHistory: pageIndex = 2
        }
        scrollView.setContentOffset(CGPoint(x: pageIndex * scrollView.frame.width, y: 0), animated: false)
        
        updateContentHeight()
        onTabChanged?(tab)
    }
    
    func getCurrentTab() -> TabType {
        return currentTab
    }
    
    // MARK: - Public Methods
    
    /// 重新加载数据
    func reloadData() {
        hasLoadedGalleryData = false
        hasLoadedIdeasData = false
        hasLoadedSceneHistoryData = false

        guard LMUserManager.shared.isLoggedIn else {
            galleryPageView.showSignInPrompt()
            ideasPageView.showSignInPrompt()
            sceneHistoryPageView.showSignInPrompt()
            updateContentHeight()
            return
        }

        loadData(for: currentTab, force: true)
        updateContentHeight()
    }

    private func loadData(for tab: TabType, force: Bool = false) {
        switch tab {
        case .gallery:
            guard LMUserManager.shared.isLoggedIn else { return }
            guard force || !hasLoadedGalleryData else { return }
            galleryPageView.reloadData()
            hasLoadedGalleryData = true
        case .savedIdeas:
            guard LMUserManager.shared.isLoggedIn else { return }
            guard force || !hasLoadedIdeasData else { return }
            ideasPageView.reloadData()
            hasLoadedIdeasData = true
        case .sceneHistory:
            guard force || !hasLoadedSceneHistoryData else { return }
            sceneHistoryPageView.reloadData()
            hasLoadedSceneHistoryData = true
        }
    }
    
    private func updateContentHeight() {
        DispatchQueue.main.async {
            let contentHeight: CGFloat
            switch self.currentTab {
            case .gallery:
                contentHeight = self.galleryPageView.calculateContentHeight()
            case .savedIdeas:
                contentHeight = self.ideasPageView.calculateContentHeight()
            case .sceneHistory:
                contentHeight = self.sceneHistoryPageView.calculateContentHeight()
            }
            let totalHeight = 60 + contentHeight
            
            self.heightConstraint?.update(offset: totalHeight)
            self.onHeightChanged?(totalHeight)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateContentHeight()
    }
}

// MARK: - UIScrollViewDelegate
extension LMPhotoCollectionView: UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageWidth = max(scrollView.frame.width, 1)
        let currentPage = Int(scrollView.contentOffset.x / pageWidth)
        
        let newTab: TabType
        switch currentPage {
        case 1: newTab = .savedIdeas
        case 2: newTab = .sceneHistory
        default: newTab = .gallery
        }
        
        if newTab != currentTab {
            currentTab = newTab
            loadData(for: newTab)
            
            galleryTabButton.isSelected = (newTab == .gallery)
            savedIdeasTabButton.isSelected = (newTab == .savedIdeas)
            sceneHistoryTabButton.isSelected = (newTab == .sceneHistory)
            
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
                let anchor: UIView
                switch newTab {
                case .gallery: anchor = self.galleryTabButton
                case .savedIdeas: anchor = self.savedIdeasTabButton
                case .sceneHistory: anchor = self.sceneHistoryTabButton
                }
                self.tabIndicator.snp.remakeConstraints { make in
                    make.bottom.equalToSuperview().offset(-8)
                    make.centerX.equalTo(anchor)
                    make.width.equalTo(50)
                    make.height.equalTo(4)
                }
                self.layoutIfNeeded()
            }
            
            updateContentHeight()
            onTabChanged?(newTab)
        }
    }
}

extension LMPhotoCollectionView: LMSceneHistoryPageViewDelegate {
    func sceneHistoryPageViewDidSelect(_ record: LMSceneHistoryRecord, cover: UIImage?) {
        onSceneHistorySelected?(record, cover)
    }
}
