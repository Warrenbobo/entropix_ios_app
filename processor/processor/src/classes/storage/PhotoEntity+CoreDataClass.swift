//
//  PhotoEntity+CoreDataClass.swift
//  processor
//
//  Created by muz on 2025/01/XX.
//  PhotoEntity Core Data class extensions
//

import Foundation
import CoreData
import UIKit

@objc(PhotoEntity)
public class PhotoEntity: NSManagedObject {
    
    /// 加载图片
    func loadImage() -> UIImage? {
        if let imagePath = imagePath,
           let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)) {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    /// 加载参考图
    func loadReferenceImage() -> UIImage? {
        if let refPath = referenceImagePath,
           let imageData = try? Data(contentsOf: URL(fileURLWithPath: refPath)) {
            return UIImage(data: imageData)
        }
        return nil
    }
    
    /// 转换为 GalleryItem
    func toGalleryItem() -> GalleryItem? {
        guard let id = id else { return nil }
        
        // 优先使用缩略图，如果没有则加载完整图片
        var image: UIImage?
        if let thumbnailData = thumbnailData {
            image = UIImage(data: thumbnailData)
        } else {
            image = loadImage()
        }
        
        return GalleryItem(
            image: image,
            title: title,
            id: id,
            isLivePhoto: isLivePhoto,
            livePhotoVideoPath: livePhotoVideoPath
        )
    }
}
