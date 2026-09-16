//
//  LMGalleryPageView.swift
//  processor
//
//  Created by muz on 2025/10/18.
//

import UIKit
import SnapKit

class LMGalleryPageView: UIView {
    
    private lazy var collectionView: UICollectionView = createCollectionView()
    private var galleryImages: [GalleryItem] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUserInterfaceComponents()
        configureLayoutConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUserInterfaceComponents()
        configureLayoutConstraints()
    }
    
    private func createCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }
    
    private func setupUserInterfaceComponents() {
        addSubview(collectionView)
        setupCollectionView()
    }
    
    private func setupCollectionView() {
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(LMGalleryCollectionViewCell.self, forCellWithReuseIdentifier: "GalleryCell")
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceVertical = true
    }
    
    private func configureLayoutConstraints() {
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func loadSampleData() {
        // 从CoreData加载真实的Gallery数据
        loadPhotosFromStorage()
    }
    
    private func loadPhotosFromStorage() {
        let photoEntities = LMPhotoStorageManager.shared.fetchAllPhotos()
        galleryImages = photoEntities.compactMap { $0.toGalleryItem() }
        LMLogger.log("📸 Loaded \(galleryImages.count) photos from storage")
        
        // 如果没有数据，显示空状态
        if galleryImages.isEmpty {
            showEmptyState(message: LMText.profile.noPhotosYet)
        } else {
            hideEmptyState()
        }
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

extension LMGalleryPageView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return galleryImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as! LMGalleryCollectionViewCell
        
        let item = galleryImages[indexPath.item]
        cell.configure(with: item)
        
        return cell
    }
}

extension LMGalleryPageView: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 32 + 8 // 左右边距 + 中间间距
        let availableWidth = collectionView.frame.width - padding
        let itemWidth = availableWidth / 2
        let itemHeight = itemWidth * 1.3 // 设置高宽比为1.3:1
        
        return CGSize(width: itemWidth, height: itemHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = galleryImages[indexPath.item]
        handleItemSelection(item: item)
    }
    
    private func handleItemSelection(item: GalleryItem) {
        // 处理图片选择
        print("Selected item: \(item.title ?? "Unknown") with ID: \(item.id)")
        
        // 这里可以导航到详情页面或执行其他操作
        showItemDetail(item: item)
    }
    
    private func showItemDetail(item: GalleryItem) {
        // 导航到Gallery详情页
        if let parentViewController = findViewController() {
            let detailPage = LMGalleryDetailPage(item: item)
            parentViewController.navigationController?.pushViewController(detailPage, animated: true)
        }
    }
}

// MARK: - Helper Methods
extension LMGalleryPageView {
    
    // 禁用垂直滚动
    func disableVerticalScrolling() {
        collectionView.isScrollEnabled = false
    }
    
    // 计算内容高度
    func calculateContentHeight() -> CGFloat {
        let itemCount = galleryImages.count
        let itemsPerRow = 2
        let rows = ceil(Double(itemCount) / Double(itemsPerRow))
        
        let padding: CGFloat = 32 + 8 // 左右边距 + 中间间距
        let availableWidth = frame.width - padding
        let itemWidth = availableWidth / 2
        let itemHeight = itemWidth * 1.3 // 设置高宽比为1.3:1
        
        let totalHeight = CGFloat(rows) * itemHeight + CGFloat(max(0, rows - 1)) * 8 + 32 // 行高 + 行间距 + 上下边距
        
        // 确保最小高度为 360
        return max(totalHeight, 360)
    }
    
    // MARK: - Public Methods
    
    /// 重新加载数据
    func reloadData() {
        // 从CoreData加载真实的Gallery数据
        loadPhotosFromStorage()
        
        // 刷新集合视图
        collectionView.reloadData()
    }
    
    /// 显示登录提示
    func showSignInPrompt() {
        // 清空数据
        galleryImages = []
        collectionView.reloadData()
        
        // 显示"Please sign in"提示
        showEmptyState(message: LMText.common.pleaseSignIn)
    }
    
    /// 显示空状态提示
    private func showEmptyState(message: String) {
        // 移除之前的空状态视图
        subviews.forEach { view in
            if view.tag == 999 {
                view.removeFromSuperview()
            }
        }
        
        let emptyStateView = UIView()
        emptyStateView.tag = 999
        emptyStateView.backgroundColor = .clear
        
        // 创建占位图片
        let placeholderImageView = UIImageView()
        placeholderImageView.image = UIImage.lmSymbol("photo.on.rectangle.angled", pointSize: 44)
        placeholderImageView.tintColor = .systemGray3
        placeholderImageView.contentMode = .scaleAspectFit
        placeholderImageView.tintColor = UIColor.systemGray3
        
        // 创建提示文本
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        messageLabel.textColor = UIColor.systemGray
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        // 添加到容器
        emptyStateView.addSubview(placeholderImageView)
        emptyStateView.addSubview(messageLabel)
        addSubview(emptyStateView)
        
        // 布局约束
        emptyStateView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        placeholderImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-40)
            make.width.height.equalTo(80)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(placeholderImageView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(40)
            make.centerX.equalToSuperview()
        }

        UIView.performWithoutAnimation {
            self.layoutIfNeeded()
        }
        
        LMLogger.log("📭 Gallery empty state shown: \(message)")
    }
    
    /// 隐藏空状态提示
    private func hideEmptyState() {
        subviews.forEach { view in
            if view.tag == 999 {
                view.removeFromSuperview()
            }
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
    
    func configure(with item: GalleryItem) {
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
