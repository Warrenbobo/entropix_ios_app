//
//  LMSuggestionBoundBoxManager.swift
//  processor
//
//  Created by muz on 2025/12/3.
//

import Foundation
import UIKit

/// 首先将识别人体和人脸的功能与相机功能分离开，识别功能相对单一隔离，支持多个代理分别处理
/// 其次Suggestion进入Reference Image状态时，要将Suggestion的image进行检测，检测出的bbox值当做AR Guidance白框的位置
/// 校准时需要以白框为参考位置进行校准，不是以屏幕中心点
/// 白色校准框在画布中的位置需要根据画布当前的比例来做调整，bbox转为具体坐标时，需要参考画布的尺寸而不是屏幕的尺寸
/// 相机实际支持竖屏和横屏两种情况，当检测到设备朝向改变时，Reference Image要跟随旋转
/// 检测图片时，相机流输出的图片要跟随当前设备的方向正确处理
///


class LMSuggestionBoundBoxManager {
    
    static let instance = LMSuggestionBoundBoxManager()
    
    static func detectSuggestionBodyImage(_ image: UIImage, finishedHandler: ((BoundingBox?) -> ())? ) {
        LMSuggestionBoundBoxManager.instance.detectionResultHandler = finishedHandler
        
    }
    
    private var detectionResultHandler: ((BoundingBox?) -> ())?
}

extension LMSuggestionBoundBoxManager: LMPersonDetectionManagerDelegate {
    
    func personDetectionManager(_ manager: LMPersonDetectionManager, didDetectPerson result: PersonDetectionResult) {
        // 人脸检测和宽度阈值检查已禁用 - 直接使用人体 bbox
        DispatchQueue.main.async { [weak self] in
            // 不再检查 isBodyWidthExceedingThreshold 和 faceBoundingBox
            // 直接使用人体检测的 boundingBox
            self?.detectionResultHandler?(result.boundingBox)
        }
    }
    
    func personDetectionManagerDidNotDetectPerson(_ manager: LMPersonDetectionManager) {
        // 未检测到人物，隐藏蓝色引导框和连接线
        DispatchQueue.main.async { [weak self] in
            self?.detectionResultHandler?(nil)
        }
    }
    
    func personDetectionManager(_ manager: LMPersonDetectionManager, didFailWithError error: Error) {
        LMLogger.log("❌ Person detection failed: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.detectionResultHandler?(nil)
        }
    }
}

