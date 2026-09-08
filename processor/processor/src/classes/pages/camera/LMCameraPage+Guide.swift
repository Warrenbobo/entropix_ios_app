//
//  LMCameraPage+Guide.swift
//  processor
//
//  相机页面教程功能扩展
//

import UIKit
import AVFoundation

private var guideViewStorage = NSMapTable<LMCameraPage, LMCameraGuideView>.weakToStrongObjects()
private var guideStepStorage = NSMapTable<LMCameraPage, NSNumber>.weakToStrongObjects()

extension LMCameraPage {

    var guideView: LMCameraGuideView? {
        get {
            guideViewStorage.object(forKey: self)
        }
        set {
            if let value = newValue {
                guideViewStorage.setObject(value, forKey: self)
            } else {
                guideViewStorage.removeObject(forKey: self)
            }
        }
    }

    var currentGuideStep: LMCameraGuideStep? {
        get {
            guard let number = guideStepStorage.object(forKey: self) else { return nil }
            return LMCameraGuideStep.allCases.first { $0.rawValue.hashValue == number.intValue }
        }
        set {
            if let value = newValue {
                guideStepStorage.setObject(NSNumber(value: value.rawValue.hashValue), forKey: self)
            } else {
                guideStepStorage.removeObject(forKey: self)
            }
        }
    }
}

extension LMCameraPage {

    func setupGuideView() {
        let guide = LMCameraGuideView()
        guide.delegate = self
        view.addSubview(guide)

        guide.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        guideView = guide
    }

    func bringGuideViewToFront() {
        if let guide = guideView {
            view.bringSubviewToFront(guide)
        }
    }

    func showInspireMeGuideIfNeeded() {
        guard LMCameraGuideManager.shared.shouldShowTutorialAutomatically() else {
            return
        }
        showTutorialFromStartIfPossible(force: false)
    }

    func showTutorialFromStart() {
        showTutorialFromStartIfPossible(force: true)
    }

    private func showTutorialFromStartIfPossible(force: Bool) {
        guard let guide = guideView,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            return
        }

        if !force && !LMCameraGuideManager.shared.shouldShowTutorialAutomatically() {
            return
        }

        bringGuideViewToFront()
        guide.showTutorial(startingFrom: .findScene, targetProvider: { [weak self] step in
            self?.tutorialTargetView(for: step)
        }, onComplete: {
            LMCameraGuideManager.shared.markTutorialCompleted()
        })
    }

    private func tutorialTargetView(for step: LMCameraTutorialStep) -> UIView? {
        switch step {
        case .findScene:
            return previewCanvasView
        case .tapButton:
            return preShootPlanButtonView
        case .viewAndSelect:
            return previewCanvasView
        case .alignGuidance:
            return previewCanvasView
        case .savePhoto:
            return cameraBottomControlsView
        }
    }
}

// MARK: - Legacy no-op guide hooks
extension LMCameraPage {

    func hideInspireMeGuide() {}

    func showSwipeUpGuideIfNeeded() {}

    func hideSwipeUpGuide() {}

    func showARGuidanceGuideIfNeeded() {}

    func hideARGuidanceGuide() {}

    func tryShowAlignBoxesGuideAfterDelay() {}

    func showAlignBoxesGuideIfNeeded() {}

    func hideAlignBoxesGuide() {}

    func hideCurrentGuideIfNeeded() {}

    func hideCompositionSelectedGuides() {}
}

extension LMCameraPage: LMCameraGuideViewDelegate {
    func cameraGuideViewDidComplete(_ guideView: LMCameraGuideView, step: LMCameraGuideStep) {
        currentGuideStep = nil
    }
}
