//
//  LMCapturedPhotoData.swift
//  processor
//
//  Created by muz on 2025/01/XX.
//  拍摄照片数据结构 - 支持普通照片和 Live Photo
//

import UIKit
import Foundation

/// 拍摄照片数据结构
struct CapturedPhotoData {
    /// 静态图片（JPEG）
    let image: UIImage
    
    /// 原始照片数据（包含元数据，用于 Live Photo）
    let imageData: Data?
    
    /// Live Photo 视频文件 URL（可选）
    let livePhotoVideoURL: URL?
    
    /// 是否为 Live Photo
    let isLivePhoto: Bool
    
    /// 便捷初始化方法 - 普通照片
    init(image: UIImage) {
        self.image = image
        self.imageData = nil
        self.livePhotoVideoURL = nil
        self.isLivePhoto = false
    }
    
    /// 完整初始化方法
    init(image: UIImage, imageData: Data? = nil, livePhotoVideoURL: URL?, isLivePhoto: Bool) {
        self.image = image
        self.imageData = imageData
        self.livePhotoVideoURL = livePhotoVideoURL
        self.isLivePhoto = isLivePhoto
    }
}
