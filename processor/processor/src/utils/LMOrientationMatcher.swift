//
//  LMOrientationMatcher.swift
//  processor
//
//  Created by Kiro on 2025-01-XX.
//

import UIKit

/// 图片方向类型
enum LMImageOrientation {
    case portrait  // 纵向（高 > 宽）
    case landscape // 横向（宽 > 高）
}

/// 方向匹配工具类
class LMOrientationMatcher {
    
    /// 判断图片方向（横向或纵向）
    /// - Parameter imageSize: 图片尺寸
    /// - Returns: 图片方向
    static func getImageOrientation(imageSize: CGSize) -> LMImageOrientation {
        if imageSize.width > imageSize.height {
            return .landscape  // 横向图片（宽 > 高）
        } else {
            return .portrait   // 纵向图片（高 >= 宽，相等时默认为纵向）
        }
    }
    
    /// 判断设备方向（横向或纵向）
    /// - Parameter orientation: 设备方向
    /// - Returns: 设备方向类型
    static func getDeviceOrientation(_ orientation: UIDeviceOrientation) -> LMImageOrientation {
        switch orientation {
        case .portrait, .portraitUpsideDown:
            return .portrait   // 纵向设备
        case .landscapeLeft, .landscapeRight:
            return .landscape  // 横向设备
        default:
            return .portrait   // 默认纵向
        }
    }
    
    /// 检查方向是否匹配
    /// - Parameters:
    ///   - imageSize: 图片尺寸
    ///   - deviceOrientation: 设备方向
    /// - Returns: 是否匹配
    static func isOrientationMatched(imageSize: CGSize, deviceOrientation: UIDeviceOrientation) -> Bool {
        let imageOrientation = getImageOrientation(imageSize: imageSize)
        let deviceOrient = getDeviceOrientation(deviceOrientation)
        return imageOrientation == deviceOrient
    }
    
    /// 获取当前设备方向（如果无效则返回默认值）
    /// - Returns: 有效的设备方向
    static func getCurrentDeviceOrientation() -> UIDeviceOrientation {
        // 优先使用 LMDeviceOrientationManager 的方向值（更准确）
        let orientation = LMDeviceOrientationManager.shared.currentOrientation
        
        // 如果是无效方向，返回默认的portrait
        switch orientation {
        case .unknown, .faceUp, .faceDown:
            return .portrait
        default:
            return orientation
        }
    }
}
