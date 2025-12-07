//
//  LMReferenceImageDetectionManager.swift
//  processor
//
//  Created by Kiro on 2025-01-XX.
//

import UIKit

/// Reference Image检测管理器 - 专门处理静态图片的人物检测
class LMReferenceImageDetectionManager: LMPersonDetectionManagerDelegate {
    
    // MARK: - Properties
    
    /// 人物检测管理器
    private let personDetectionManager: LMPersonDetectionManager
    
    /// 检测结果缓存 [imageId: bbox]
    private var detectionCache: [String: CGRect] = [:]
    
    /// 检测队列
    private let detectionQueue = DispatchQueue(label: "com.processor.referenceImageDetection", qos: .userInitiated)
    
    /// 当前检测的完成回调
    private var currentCompletion: ((CGRect?) -> Void)?
    
    // MARK: - Initialization
    
    init(personDetectionManager: LMPersonDetectionManager = .shared) {
        self.personDetectionManager = personDetectionManager
        self.personDetectionManager.delegate = self
    }
    
    // MARK: - Public Methods
    
    /// 检测Reference Image中的人物
    /// - Parameters:
    ///   - image: 待检测图片
    ///   - imageId: 图片唯一标识（用于缓存）
    ///   - completion: 完成回调，返回检测到的bbox（归一化坐标）
    func detectPersonInReferenceImage(
        _ image: UIImage,
        imageId: String? = nil,
        completion: @escaping (CGRect?) -> Void
    ) {
        // 检查缓存
        if let imageId = imageId, let cachedBbox = getCachedResult(for: imageId) {
            print("[Reference Detection] 使用缓存结果: \(imageId)")
            DispatchQueue.main.async {
                completion(cachedBbox)
            }
            return
        }
        
        print("[Reference Detection] 开始检测Reference Image中的人物")
        
        // 判断是否为横向图片
        let isLandscape = image.size.width > image.size.height
        if isLandscape {
            print("[Reference Detection] 横向图片，将旋转到竖屏方向后再识别")
        }
        
        // 保存完成回调和imageId
        currentCompletion = { [weak self] bbox in
            // 缓存结果
            if let imageId = imageId, let bbox = bbox {
                self?.cacheDetectionResult(for: imageId, bbox: bbox)
            }
            
            if let bbox = bbox {
                print("[Reference Detection] 检测成功: \(bbox)")
            } else {
                print("[Reference Detection] 未检测到人物")
            }
            completion(bbox)
        }
        
        // 启动检测并处理图片
        // 对于横向图片，先旋转到竖屏方向（home键在右侧）再识别
        personDetectionManager.startDetection()
        personDetectionManager.processImage(image, shouldRotateToPortrait: isLandscape)
    }
    
    /// 缓存检测结果
    /// - Parameters:
    ///   - imageId: 图片唯一标识
    ///   - bbox: 检测结果
    func cacheDetectionResult(for imageId: String, bbox: CGRect) {
        detectionCache[imageId] = bbox
        print("[Reference Detection] 缓存检测结果: \(imageId)")
    }
    
    /// 获取缓存的检测结果
    /// - Parameter imageId: 图片唯一标识
    /// - Returns: 缓存的bbox，如果不存在则返回nil
    func getCachedResult(for imageId: String) -> CGRect? {
        return detectionCache[imageId]
    }
    
    /// 清除缓存
    func clearCache() {
        detectionCache.removeAll()
        print("[Reference Detection] 清除所有缓存")
    }
    
    /// 清除指定图片的缓存
    /// - Parameter imageId: 图片唯一标识
    func clearCache(for imageId: String) {
        detectionCache.removeValue(forKey: imageId)
        print("[Reference Detection] 清除缓存: \(imageId)")
    }
    
    // MARK: - LMPersonDetectionManagerDelegate
    
    func personDetectionManager(_ manager: LMPersonDetectionManager, didDetectPerson result: PersonDetectionResult) {
        // 转换归一化坐标为 CGRect
        let bbox = CGRect(
            x: result.boundingBox.x,
            y: result.boundingBox.y,
            width: result.boundingBox.width,
            height: result.boundingBox.height
        )
        
        // 停止检测
        personDetectionManager.stopDetection()
        
        // 回调结果
        currentCompletion?(bbox)
        currentCompletion = nil
    }
    
    func personDetectionManagerDidNotDetectPerson(_ manager: LMPersonDetectionManager) {
        // 停止检测
        personDetectionManager.stopDetection()
        
        // 未检测到人物
        currentCompletion?(nil)
        currentCompletion = nil
    }
    
    func personDetectionManager(_ manager: LMPersonDetectionManager, didFailWithError error: Error) {
        print("[Reference Detection] 检测失败: \(error.localizedDescription)")
        
        // 停止检测
        personDetectionManager.stopDetection()
        
        // 返回失败
        currentCompletion?(nil)
        currentCompletion = nil
    }
}
