//
//  LMCameraPage+Guide.swift
//  processor
//
//  Camera page tutorial entry points (Journey + Mode help).
//

import UIKit
import AVFoundation

private var guideViewStorage = NSMapTable<LMCameraPage, LMCameraGuideView>.weakToStrongObjects()

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
}

extension LMCameraPage {

    func setupGuideView() {
        let guide = LMCameraGuideView()
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

    /// Auto-presents the first-time Journey deck when not yet completed.
    func showInspireMeGuideIfNeeded() {
        guard LMCameraGuideManager.shared.shouldShowTutorialAutomatically() else {
            return
        }
        presentTutorial(deck: .journey)
    }

    /**
     Presents a tutorial deck over the camera.

     - Parameter deck: Journey (marks walkthrough complete on finish) or Mode help.
     */
    func presentTutorial(deck: LMCameraTutorialDeck) {
        guard let guide = guideView,
              AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            return
        }

        bringGuideViewToFront()
        guide.showTutorial(deck: deck, onComplete: {
            if deck == .journey {
                LMCameraGuideManager.shared.markTutorialCompleted()
            }
        })
    }

    /// Mode-chip `?`: Mode help deck. Dismisses the mode sheet first when open.
    func showModeHelpTutorial() {
        if let sheet = preShootPlanModeSheet {
            sheet.dismiss()
            preShootPlanModeSheet = nil
        }
        presentTutorial(deck: .modeHelp)
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
