//
//  LMCameraGuideManager.swift
//  processor
//
//  相机教程与旧引导状态管理器
//

import Foundation

/// 旧版相机引导步骤（已废弃，保留仅用于兼容旧调用点）
enum LMCameraGuideStep: String, CaseIterable {
    case inspirMe = "hasShownInspireMeGuide"
    case swipeUp = "hasShownSwipeUpGuide"
    case arGuidance = "hasShownARGuidanceGuide"
    case alignBoxes = "hasShownAlignBoxesGuide"

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

    var needsLottieAnimation: Bool {
        false
    }

    var lottieFileName: String? {
        nil
    }
}

enum LMCameraTutorialStep: Int, CaseIterable {
    case findScene = 1
    case tapButton
    case viewAndSelect
    case alignGuidance
    case savePhoto

    var index: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .findScene:
            return LMText.camera.tutorialFindSceneTitle
        case .tapButton:
            return LMText.camera.tutorialTapButtonTitle
        case .viewAndSelect:
            return LMText.camera.tutorialViewAndSelectTitle
        case .alignGuidance:
            return LMText.camera.tutorialAlignGuidanceTitle
        case .savePhoto:
            return LMText.camera.tutorialSavePhotoTitle
        }
    }

    var description: String {
        switch self {
        case .findScene:
            return LMText.camera.tutorialFindSceneDescription
        case .tapButton:
            return LMText.camera.tutorialTapButtonDescription
        case .viewAndSelect:
            return LMText.camera.tutorialViewAndSelectDescription
        case .alignGuidance:
            return LMText.camera.tutorialAlignGuidanceDescription
        case .savePhoto:
            return LMText.camera.tutorialSavePhotoDescription
        }
    }

    var symbolName: String {
        switch self {
        case .findScene:
            return "photo.on.rectangle.angled"
        case .tapButton:
            return "sparkles"
        case .viewAndSelect:
            return "rectangle.stack.badge.play"
        case .alignGuidance:
            return "viewfinder"
        case .savePhoto:
            return "square.and.arrow.down"
        }
    }

    var accentAssetName: String? {
        switch self {
        case .tapButton:
            return "star_fill"
        case .alignGuidance:
            return "users_viewfinder_white"
        case .savePhoto:
            return "download_white"
        default:
            return nil
        }
    }

    var primaryButtonTitle: String {
        self == .savePhoto ? LMText.camera.tutorialGotIt : LMText.camera.tutorialNext
    }

    var secondaryButtonTitle: String {
        self == .savePhoto ? LMText.camera.tutorialReplay : LMText.camera.tutorialSkip
    }

    var nextStep: LMCameraTutorialStep? {
        LMCameraTutorialStep(rawValue: rawValue + 1)
    }
}

class LMCameraGuideManager {

    static let shared = LMCameraGuideManager()

    private let userDefaults = UserDefaults.standard
    private let tutorialCompletedKey = "hasCompletedCameraWalkthrough"

    private init() {}

    // MARK: - New Tutorial

    func hasCompletedTutorial() -> Bool {
        userDefaults.bool(forKey: tutorialCompletedKey)
    }

    func shouldShowTutorialAutomatically() -> Bool {
        !hasCompletedTutorial()
    }

    func markTutorialCompleted() {
        userDefaults.set(true, forKey: tutorialCompletedKey)
        userDefaults.synchronize()
        LMLogger.log("✅ [Tutorial] Marked tutorial as completed")
    }

    func resetTutorial() {
        userDefaults.removeObject(forKey: tutorialCompletedKey)
        userDefaults.synchronize()
        LMLogger.log("🔄 [Tutorial] Tutorial reset")
    }

    // MARK: - Legacy Guide Compatibility

    func hasShownGuide(for step: LMCameraGuideStep) -> Bool {
        userDefaults.bool(forKey: step.rawValue)
    }

    func markGuideAsShown(for step: LMCameraGuideStep) {
        userDefaults.set(true, forKey: step.rawValue)
        userDefaults.synchronize()
    }

    func shouldShowGuide(for step: LMCameraGuideStep) -> Bool {
        !hasCompletedTutorial() && !hasShownGuide(for: step)
    }

    func resetAllGuides() {
        for step in LMCameraGuideStep.allCases {
            userDefaults.removeObject(forKey: step.rawValue)
        }
        resetTutorial()
        userDefaults.synchronize()
        LMLogger.log("🔄 [Guide] All legacy guides reset")
    }

    func resetGuide(for step: LMCameraGuideStep) {
        userDefaults.removeObject(forKey: step.rawValue)
        userDefaults.synchronize()
        LMLogger.log("🔄 [Guide] Reset guide for \(step.rawValue)")
    }
}
