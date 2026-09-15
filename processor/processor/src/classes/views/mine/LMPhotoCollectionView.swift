//
//  LMPhotoCollectionView.swift
//  processor
//
//  Created by muz on 2025/10/6.
//

import UIKit
import SnapKit

enum TabType {
    /// Kept for API compatibility; Gallery tab is hidden from Mine UI.
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
    private let savedIdeasTabButton = UIButton()
    private let sceneHistoryTabButton = UIButton()
    private let tabIndicator = UIView()
    
    // 滑动容器
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 页面视图
    private let ideasPageView = LMIdeasPageView()
    private let sceneHistoryPageView = LMSceneHistoryPageView()
    
    private var currentTab: TabType = .savedIdeas
    private var hasLoadedIdeasData = false
    private var hasLoadedSceneHistoryData = false
    private var heightConstraint: Constraint?
    private var didApplyInitialTab = false
    
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
        
        contentView.addSubview(ideasPageView)
        contentView.addSubview(sceneHistoryPageView)
        
        setupMenuTabs()
        setupScrollView()
        sceneHistoryPageView.delegate = self
    }
    
    private func setupMenuTabs() {
        menuTabsContainer.backgroundColor = UIColor.clear
        
        savedIdeasTabButton.setTitle(LMText.profile.mineTabLikedSuggestion, for: .normal)
        savedIdeasTabButton.setTitleColor(UIColor.systemBlue, for: .selected)
        savedIdeasTabButton.setTitleColor(UIColor.systemGray, for: .normal)
        savedIdeasTabButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        savedIdeasTabButton.titleLabel?.adjustsFontSizeToFitWidth = true
        savedIdeasTabButton.isSelected = true
        savedIdeasTabButton.addTarget(self, action: #selector(savedIdeasTabButtonTapped), for: .touchUpInside)

        sceneHistoryTabButton.setTitle(LMText.profile.mineTabSceneHistory, for: .normal)
        sceneHistoryTabButton.setTitleColor(UIColor.systemBlue, for: .selected)
        sceneHistoryTabButton.setTitleColor(UIColor.systemGray, for: .normal)
        sceneHistoryTabButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        sceneHistoryTabButton.titleLabel?.adjustsFontSizeToFitWidth = true
        sceneHistoryTabButton.addTarget(self, action: #selector(sceneHistoryTabButtonTapped), for: .touchUpInside)
        
        tabIndicator.backgroundColor = UIColor.systemBlue
        tabIndicator.layer.cornerRadius = 2
        
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
        
        ideasPageView.disableVerticalScrolling()
        sceneHistoryPageView.disableVerticalScrolling()
    }
}

// MARK: - Layout Configuration
extension LMPhotoCollectionView {
    
    private func configureLayoutConstraints() {
        menuTabsContainer.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(60)
        }
        
        savedIdeasTabButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
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
            make.centerX.equalTo(savedIdeasTabButton)
            make.width.equalTo(50)
            make.height.equalTo(4)
        }
        
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(menuTabsContainer.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        self.snp.makeConstraints { make in
            heightConstraint = make.height.equalTo(400).constraint
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(scrollView)
            make.width.equalTo(scrollView).multipliedBy(2)
        }
        
        ideasPageView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview()
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
    
    @objc private func savedIdeasTabButtonTapped() {
        switchToTab(.savedIdeas)
    }

    @objc private func sceneHistoryTabButtonTapped() {
        switchToTab(.sceneHistory)
    }
    
    /**
     Switches the visible Mine content tab.

     Gallery is no longer offered in the UI; `.gallery` maps to Liked.
     */
    func switchToTab(_ tab: TabType) {
        let resolved = (tab == .gallery) ? .savedIdeas : tab
        guard currentTab != resolved || !didApplyInitialTab else { return }
        
        currentTab = resolved
        didApplyInitialTab = true
        loadData(for: resolved)
        
        savedIdeasTabButton.isSelected = (resolved == .savedIdeas)
        sceneHistoryTabButton.isSelected = (resolved == .sceneHistory)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
            let anchor: UIView = (resolved == .savedIdeas)
                ? self.savedIdeasTabButton
                : self.sceneHistoryTabButton
            self.tabIndicator.snp.remakeConstraints { make in
                make.bottom.equalToSuperview().offset(-8)
                make.centerX.equalTo(anchor)
                make.width.equalTo(50)
                make.height.equalTo(4)
            }
            self.layoutIfNeeded()
        }
        
        let pageIndex: CGFloat = (resolved == .savedIdeas) ? 0 : 1
        scrollView.setContentOffset(CGPoint(x: pageIndex * scrollView.frame.width, y: 0), animated: false)
        
        updateContentHeight()
        onTabChanged?(resolved)
    }
    
    func getCurrentTab() -> TabType {
        return currentTab
    }
    
    // MARK: - Public Methods
    
    /// 重新加载数据
    func reloadData() {
        hasLoadedIdeasData = false
        hasLoadedSceneHistoryData = false

        guard LMUserManager.shared.isLoggedIn else {
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
        case .gallery, .savedIdeas:
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
            case .gallery, .savedIdeas:
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
        if !didApplyInitialTab {
            didApplyInitialTab = true
            loadData(for: .savedIdeas)
            onTabChanged?(.savedIdeas)
        }
        updateContentHeight()
    }
}

// MARK: - UIScrollViewDelegate
extension LMPhotoCollectionView: UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageWidth = max(scrollView.frame.width, 1)
        let currentPage = Int(scrollView.contentOffset.x / pageWidth)
        
        let newTab: TabType = (currentPage >= 1) ? .sceneHistory : .savedIdeas
        
        if newTab != currentTab {
            currentTab = newTab
            loadData(for: newTab)
            
            savedIdeasTabButton.isSelected = (newTab == .savedIdeas)
            sceneHistoryTabButton.isSelected = (newTab == .sceneHistory)
            
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
                let anchor: UIView = (newTab == .savedIdeas)
                    ? self.savedIdeasTabButton
                    : self.sceneHistoryTabButton
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
