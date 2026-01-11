//
//  LMCameraGuideManager.swift
//  processor
//
//  相机功能引导管理器
//  管理四个引导步骤的显示状态和存储
//

import Foundation

/// 相机引导步骤
enum LMCameraGuideStep: String, CaseIterable {
    case inspirMe = "hasShownInspireMeGuide"           // Step 1: Tap to Inspire
    case swipeUp = "hasShownSwipeUpGuide"              // Step 2: Swipe Up to Select Template
    case arGuidance = "hasShownARGuidanceGuide"        // Step 3: Tap to Turn AR Guidance On/Off
    case alignBoxes = "hasShownAlignBoxesGuide"        // Step 4: Align the Boxes
    
    /// 引导标题
    var title: String {
        switch self {
        case .inspirMe:
            return "Step 1:\nTap to Inspire"
        case .swipeUp:
            return "Step 2:\nSwipe Up to Select Template"
        case .arGuidance:
            return "Step 3:\nTap to Turn AR Guidance On/Off"
        case .alignBoxes:
            return "Step 4:\nAlign the Boxes"
        }
    }
    
    /// 是否需要 Lottie 动画
    var needsLottieAnimation: Bool {
        switch self {
        case .inspirMe, .swipeUp, .arGuidance:
            return true
        case .alignBoxes:
            return false
        }
    }
    
    /// Lottie 动画文件名
    var lottieFileName: String? {
        switch self {
        case .inspirMe, .arGuidance:
            return "single_tap"
        case .swipeUp:
            return "swipe_up_animation"
        case .alignBoxes:
            return nil
        }
    }
}

/// 相机引导管理器
class LMCameraGuideManager {
    
    static let shared = LMCameraGuideManager()
    
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 检查指定步骤的引导是否已显示过
    /// - Parameter step: 引导步骤
    /// - Returns: 是否已显示过
    func hasShownGuide(for step: LMCameraGuideStep) -> Bool {
        return userDefaults.bool(forKey: step.rawValue)
    }
    
    /// 标记指定步骤的引导已完成
    /// - Parameter step: 引导步骤
    func markGuideAsShown(for step: LMCameraGuideStep) {
        userDefaults.set(true, forKey: step.rawValue)
        userDefaults.synchronize()
        LMLogger.log("✅ [Guide] Marked \(step.rawValue) as shown")
    }
    
    /// 检查是否应该显示指定步骤的引导
    /// - Parameter step: 引导步骤
    /// - Returns: 是否应该显示
    func shouldShowGuide(for step: LMCameraGuideStep) -> Bool {
        return !hasShownGuide(for: step)
    }
    
    /// 重置所有引导状态（用于测试）
    func resetAllGuides() {
        for step in LMCameraGuideStep.allCases {
            userDefaults.removeObject(forKey: step.rawValue)
        }
        userDefaults.synchronize()
        LMLogger.log("🔄 [Guide] All guides reset")
    }
    
    /// 重置指定步骤的引导状态（用于测试）
    /// - Parameter step: 引导步骤
    func resetGuide(for step: LMCameraGuideStep) {
        userDefaults.removeObject(forKey: step.rawValue)
        userDefaults.synchronize()
        LMLogger.log("🔄 [Guide] Reset guide for \(step.rawValue)")
    }
}
