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
}

struct GalleryItem {
    let image: UIImage?
    let title: String?
    let id: String
}

class LMPhotoCollectionView: UIView {
    
    // MARK: - UI Components
    private let menuTabsContainer = UIView()
    private let galleryTabButton = UIButton()
    private let savedIdeasTabButton = UIButton()
    private let tabIndicator = UIView()
    
    // 滑动容器
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // 页面视图
    private let galleryPageView = LMGalleryPageView()
    private let ideasPageView = LMIdeasPageView()
    
    private var currentTab: TabType = .gallery
    private var heightConstraint: Constraint?
    
    // 回调，用于通知父视图高度变化
    var onHeightChanged: ((CGFloat) -> Void)?
    // 回调，用于通知父视图tab变化
    var onTabChanged: ((TabType) -> Void)?
    
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
        
        setupMenuTabs()
        setupScrollView()
    }
    
    private func setupMenuTabs() {
        menuTabsContainer.backgroundColor = UIColor.clear
        
        // Gallery Tab Button
        galleryTabButton.setTitle("Gallery", for: .normal)
        galleryTabButton.setTitleColor(UIColor.systemBlue, for: .selected)
        galleryTabButton.setTitleColor(UIColor.systemGray, for: .normal)
        galleryTabButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        galleryTabButton.isSelected = true
        galleryTabButton.addTarget(self, action: #selector(galleryTabButtonTapped), for: .touchUpInside)
        
        // Saved Ideas Tab Button
        savedIdeasTabButton.setTitle("Saved Ideas", for: .normal)
        savedIdeasTabButton.setTitleColor(UIColor.systemBlue, for: .selected)
        savedIdeasTabButton.setTitleColor(UIColor.systemGray, for: .normal)
        savedIdeasTabButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        savedIdeasTabButton.addTarget(self, action: #selector(savedIdeasTabButtonTapped), for: .touchUpInside)
        
        // Tab Indicator
        tabIndicator.backgroundColor = UIColor.systemBlue
        tabIndicator.layer.cornerRadius = 2
        
        menuTabsContainer.addSubview(galleryTabButton)
        menuTabsContainer.addSubview(savedIdeasTabButton)
        menuTabsContainer.addSubview(tabIndicator)
    }
    
    private func setupScrollView() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.backgroundColor = UIColor.clear
        scrollView.isScrollEnabled = true // 保持水平滚动
        
        contentView.backgroundColor = UIColor.clear
        
        // 禁用页面视图内部的垂直滚动
        galleryPageView.disableVerticalScrolling()
        ideasPageView.disableVerticalScrolling()
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
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalToSuperview()
            make.width.equalTo(80)
        }
        
        savedIdeasTabButton.snp.makeConstraints { make in
            make.leading.equalTo(galleryTabButton.snp.trailing).offset(40)
            make.centerY.equalToSuperview()
            make.width.equalTo(120)
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
            make.width.equalTo(scrollView).multipliedBy(2) // 两个页面的宽度
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
    
    func switchToTab(_ tab: TabType) {
        guard currentTab != tab else { return }
        
        currentTab = tab
        
        // 更新按钮状态
        galleryTabButton.isSelected = (tab == .gallery)
        savedIdeasTabButton.isSelected = (tab == .savedIdeas)
        
        // 动画移动指示器
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
            if tab == .gallery {
                self.tabIndicator.snp.remakeConstraints { make in
                    make.bottom.equalToSuperview().offset(-8)
                    make.centerX.equalTo(self.galleryTabButton)
                    make.width.equalTo(50)
                    make.height.equalTo(4)
                }
            } else {
                self.tabIndicator.snp.remakeConstraints { make in
                    make.bottom.equalToSuperview().offset(-8)
                    make.centerX.equalTo(self.savedIdeasTabButton)
                    make.width.equalTo(50)
                    make.height.equalTo(4)
                }
            }
            self.layoutIfNeeded()
        }
        
        // 滑动到对应页面
        let targetOffsetX: CGFloat = (tab == .gallery) ? 0 : scrollView.frame.width
        scrollView.setContentOffset(CGPoint(x: targetOffsetX, y: 0), animated: false)
        
        // 更新高度
        updateContentHeight()
        
        // 通知父视图tab变化
        onTabChanged?(tab)
    }
    
    func getCurrentTab() -> TabType {
        return currentTab
    }
    
    private func updateContentHeight() {
        DispatchQueue.main.async {
            var contentHeight: CGFloat = 0
            if self.currentTab == .gallery {
                contentHeight = self.galleryPageView.calculateContentHeight()
            } else {
                contentHeight = self.ideasPageView.calculateContentHeight()
            }
            let totalHeight = 60 + contentHeight // 菜单高度 + 内容高度
            
            self.heightConstraint?.update(offset: totalHeight)
            self.onHeightChanged?(totalHeight)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // 布局完成后更新高度
        updateContentHeight()
    }
}

// MARK: - UIScrollViewDelegate
extension LMPhotoCollectionView: UIScrollViewDelegate {
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageWidth = scrollView.frame.width
        let currentPage = Int(scrollView.contentOffset.x / pageWidth)
        
        let newTab: TabType = (currentPage == 0) ? .gallery : .savedIdeas
        
        if newTab != currentTab {
            currentTab = newTab
            
            // 更新按钮状态
            galleryTabButton.isSelected = (newTab == .gallery)
            savedIdeasTabButton.isSelected = (newTab == .savedIdeas)
            
            // 动画移动指示器
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: .curveEaseInOut) {
                if newTab == .gallery {
                    self.tabIndicator.snp.remakeConstraints { make in
                        make.bottom.equalToSuperview().offset(-8)
                        make.centerX.equalTo(self.galleryTabButton)
                        make.width.equalTo(50)
                        make.height.equalTo(4)
                    }
                } else {
                    self.tabIndicator.snp.remakeConstraints { make in
                        make.bottom.equalToSuperview().offset(-8)
                        make.centerX.equalTo(self.savedIdeasTabButton)
                        make.width.equalTo(50)
                        make.height.equalTo(4)
                    }
                }
                self.layoutIfNeeded()
            }
            
            // 通知父视图tab变化
            onTabChanged?(newTab)
        }
    }
}


