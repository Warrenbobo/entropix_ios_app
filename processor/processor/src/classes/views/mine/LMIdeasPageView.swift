//
//  LMIdeasPageView.swift
//  processor
//
//  Created by muz on 2025/10/18.
//

import UIKit
import SnapKit

class LMIdeasPageView: UIView {
    
    private lazy var collectionView: UICollectionView = createCollectionView()
    private var savedIdeasImages: [GalleryItem] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        loadSampleData()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        loadSampleData()
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
        // 加载Saved Ideas示例数据
        savedIdeasImages = [
            GalleryItem(image: createSampleImage(color: .systemCyan), title: "Saved Idea 1", id: "saved_1"),
            GalleryItem(image: createSampleImage(color: .systemYellow), title: "Saved Idea 2", id: "saved_2"),
            GalleryItem(image: createSampleImage(color: .systemMint), title: "Saved Idea 3", id: "saved_3"),
            GalleryItem(image: createSampleImage(color: .systemBrown), title: "Saved Idea 4", id: "saved_4"),
            GalleryItem(image: createSampleImage(color: .systemPink), title: "Saved Idea 5", id: "saved_5"),
            GalleryItem(image: createSampleImage(color: .systemIndigo), title: "Saved Idea 6", id: "saved_6")
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
extension LMIdeasPageView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return savedIdeasImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GalleryCell", for: indexPath) as! LMGalleryCollectionViewCell
        
        let item = savedIdeasImages[indexPath.item]
        cell.configure(with: item)
        
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension LMIdeasPageView: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 32 + 8 // 左右边距 + 中间间距
        let availableWidth = collectionView.frame.width - padding
        let itemWidth = availableWidth / 2
        let itemHeight = itemWidth * 1.3 // 设置高宽比为1.3:1
        
        return CGSize(width: itemWidth, height: itemHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = savedIdeasImages[indexPath.item]
        handleItemSelection(item: item)
    }
    
    private func handleItemSelection(item: GalleryItem) {
        // 处理图片选择
        print("Selected saved idea: \(item.title ?? "Unknown") with ID: \(item.id)")
        
        // 这里可以导航到详情页面或执行其他操作
        showItemDetail(item: item)
    }
    
    private func showItemDetail(item: GalleryItem) {
        // 导航到Saved Idea详情页
        if let parentViewController = findViewController() {
            let detailPage = LMSavedIdeaDetailPage(item: item)
            parentViewController.navigationController?.pushViewController(detailPage, animated: true)
        }
    }
}

// MARK: - Helper Methods
extension LMIdeasPageView {
    
    // 禁用垂直滚动
    func disableVerticalScrolling() {
        collectionView.isScrollEnabled = false
    }
    
    // 计算内容高度
    func calculateContentHeight() -> CGFloat {
        let itemCount = savedIdeasImages.count
        let itemsPerRow = 2
        let rows = ceil(Double(itemCount) / Double(itemsPerRow))
        
        let padding: CGFloat = 32 + 8 // 左右边距 + 中间间距
        let availableWidth = frame.width - padding
        let itemWidth = availableWidth / 2
        let itemHeight = itemWidth * 1.3 // 设置高宽比为1.3:1
        
        let totalHeight = CGFloat(rows) * itemHeight + CGFloat(max(0, rows - 1)) * 8 + 32 // 行高 + 行间距 + 上下边距
        
        return totalHeight
    }
}
