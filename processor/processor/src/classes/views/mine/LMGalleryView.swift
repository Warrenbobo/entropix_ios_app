//
//  LMGalleryView.swift
//  processor
//
//  Created by muz on 2025/10/6.
//

import UIKit
import SnapKit

class LMGalleryView: UIView {
    
    // MARK: - UI Components
    private let menuTabsContainer = UIView()
    private let galleryTabButton = UIButton()
    private let savedIdeasTabButton = UIButton()
    private let tabIndicator = UIView()
    private lazy var collectionView: UICollectionView = createCollectionView()
    
    // MARK: - Properties
    private var currentTab: TabType = .gallery
    private var galleryImages: [GalleryItem] = []
    private var savedIdeasImages: [GalleryItem] = []
    
    enum TabType {
        case gallery
        case savedIdeas
    }
    
    struct GalleryItem {
        let image: UIImage?
        let title: String?
        let id: String
    }
    
    // 初始化CollectionView
    private func createCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        loadSampleData()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        loadSampleData()
    }
}

// MARK: - Setup Methods
extension LMGalleryView {
    
    private func setupUserInterfaceComponents() {
        addSubview(menuTabsContainer)
        addSubview(collectionView)
        
        setupMenuTabs()
        setupCollectionView()
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
    
    private func setupCollectionView() {
        collectionView.backgroundColor = UIColor.systemGroupedBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(LMGalleryCollectionViewCell.self, forCellWithReuseIdentifier: "GalleryCell")
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
    }
}

// MARK: - Layout Configuration
extension LMGalleryView {
    
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
        
        // Collection View
        collectionView.snp.makeConstraints { make in
            make.top.equalTo(menuTabsContainer.snp.bottom)
            make.height.equalTo(0)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
}

// MARK: - Style Configuration
extension LMGalleryView {
    
    private func configureDefaultContentAndStyles() {
        backgroundColor = UIColor.systemBackground
    }
}

// MARK: - Action Handlers
extension LMGalleryView {
    

    
    @objc private func galleryTabButtonTapped() {
        switchToTab(.gallery)
    }
    
    @objc private func savedIdeasTabButtonTapped() {
        switchToTab(.savedIdeas)
    }
    
    private func switchToTab(_ tab: TabType) {
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
        
        // 重新加载CollectionView
        collectionView.reloadData()
        
        // 滚动到顶部
        if getCurrentDataSource().count > 0 {
            collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: false)
        }
    }
    
    private func getCurrentDataSource() -> [GalleryItem] {
        switch currentTab {
        case .gallery:
            return galleryImages
        case .savedIdeas:
            return savedIdeasImages
        }
    }
}

extension LMGalleryView {
    
    private func loadSampleData() {
        // 加载Gallery示例数据
        galleryImages = [
            GalleryItem(image: createSampleImage(color: .systemBlue), title: "Nature Scene 1", id: "gallery_1"),
            GalleryItem(image: createSampleImage(color: .systemGreen), title: "Portrait 1", id: "gallery_2"),
            GalleryItem(image: createSampleImage(color: .systemOrange), title: "Landscape 1", id: "gallery_3"),
            GalleryItem(image: createSampleImage(color: .systemPurple), title: "Adventure 1", id: "gallery_4"),
            GalleryItem(image: createSampleImage(color: .systemTeal), title: "Castle View", id: "gallery_5"),
            GalleryItem(image: createSampleImage(color: .systemPink), title: "Garden Scene", id: "gallery_6"),
            GalleryItem(image: createSampleImage(color: .systemIndigo), title: "Mountain View", id: "gallery_7"),
            GalleryItem(image: createSampleImage(color: .systemRed), title: "River Scene", id: "gallery_8")
        ]
        
        // 加载Saved Ideas示例数据
        savedIdeasImages = [
            GalleryItem(image: createSampleImage(color: .systemCyan), title: "Saved Idea 1", id: "saved_1"),
            GalleryItem(image: createSampleImage(color: .systemYellow), title: "Saved Idea 2", id: "saved_2"),
            GalleryItem(image: createSampleImage(color: .systemMint), title: "Saved Idea 3", id: "saved_3"),
            GalleryItem(image: createSampleImage(color: .systemBrown), title: "Saved Idea 4", id: "saved_4")
        ]
    }
    
    private func createSampleImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 200, height: 260)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 添加一些装饰性元素
            UIColor.white.withAlphaComponent(0.3).setFill()
            let rect = CGRect(x: 20, y: 20, width: size.width - 40, height: size.height - 40)
            context.cgContext.fillEllipse(in: rect)
        }
    }
}

// MARK: - UICollectionViewDataSource
extension LMGalleryView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return getCurrentDataSource().count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as! LMGalleryCollectionViewCell
        
        let item = getCurrentDataSource()[indexPath.item]
        cell.configure(with: item)
        
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension LMGalleryView: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 32 + 8 // 左右边距 + 中间间距
        let availableWidth = collectionView.frame.width - padding
        let itemWidth = availableWidth / 2
        let itemHeight = itemWidth * 1.3 // 设置高宽比为1.3:1
        
        return CGSize(width: itemWidth, height: itemHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = getCurrentDataSource()[indexPath.item]
        handleItemSelection(item: item)
    }
    
    private func handleItemSelection(item: GalleryItem) {
        // 处理图片选择
        print("Selected item: \(item.title ?? "Unknown") with ID: \(item.id)")
        
        // 这里可以导航到详情页面或执行其他操作
        showItemDetail(item: item)
    }
    
    private func showItemDetail(item: GalleryItem) {
        let alert = UIAlertController(
            title: item.title ?? "Gallery Item",
            message: "Item ID: \(item.id)\nTab: \(currentTab == .gallery ? "Gallery" : "Saved Ideas")",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // 由于这是UIView，需要通过父视图控制器来present
        if let parentViewController = findViewController() {
            parentViewController.present(alert, animated: true)
        }
    }
}

// MARK: - Custom Collection View Cell
class LMGalleryCollectionViewCell: UICollectionViewCell {
    
    private let imageView = UIImageView()
    private let overlayView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
    private func setupCell() {
        contentView.addSubview(imageView)
        contentView.addSubview(overlayView)
        
        // Image View Setup
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 16
        imageView.backgroundColor = UIColor.systemGray6
        
        // Overlay View Setup (for selection feedback)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        overlayView.layer.cornerRadius = 16
        overlayView.isUserInteractionEnabled = false
        
        // Layout
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Add shadow effect
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        layer.masksToBounds = false
    }
    
    func configure(with item: LMGalleryView.GalleryItem) {
        imageView.image = item.image
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
    }
    
    // 添加选择动画效果
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.2) {
                if self.isHighlighted {
                    self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                    self.overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
                } else {
                    self.transform = CGAffineTransform.identity
                    self.overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
                }
            }
        }
    }
}

// MARK: - Helper Methods
extension LMGalleryView {
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            responder = responder?.next
        }
        return nil
    }
}
