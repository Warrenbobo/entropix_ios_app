//
//  LMARGuidanceMode.swift
//  processor
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

/// Agent guidance toggle (sidebar): unavailable / agent ON / off.
enum LMARGuidanceButtonState {
    case unavailable
    case agent
    case off

    var buttonAlpha: CGFloat {
        switch self {
        case .unavailable: return 0.55
        case .agent: return 1.0
        case .off: return 0.45
        }
    }

    var labelAlpha: CGFloat {
        buttonAlpha
    }

    var isAgentEnabled: Bool {
        self == .agent
    }

    var nextToggleState: LMARGuidanceButtonState {
        switch self {
        case .unavailable: return .unavailable
        case .agent: return .off
        case .off: return .agent
        }
    }

    var logName: String {
        switch self {
        case .unavailable: return "Unavailable"
        case .agent: return "Agent"
        case .off: return "Off"
        }
    }
}

/// Overlay visibility for white reference box and/or line-art (can both be on).
struct LMARGuidanceOverlayDisplay: Equatable {
    var showBox: Bool
    var showLineArt: Bool

    static let off = LMARGuidanceOverlayDisplay(showBox: false, showLineArt: false)

    /**
     Builds overlay flags from independent Framing / Pose toggles.

     - Parameters:
       - showBox: Framing (white reference box + live blue box) enabled.
       - showLineArt: Pose (line-art) overlay enabled.
       - inCompositionSelected: Overlays only apply in composition-selected.
     */
    init(showBox: Bool, showLineArt: Bool, inCompositionSelected: Bool) {
        guard inCompositionSelected else {
            self.showBox = false
            self.showLineArt = false
            return
        }
        self.showBox = showBox
        self.showLineArt = showLineArt
    }

    init(showBox: Bool = false, showLineArt: Bool = false) {
        self.showBox = showBox
        self.showLineArt = showLineArt
    }
}

/// Shutter button role in composition-selected + agent mode.
enum LMShutterRole {
    case captureDefault
    case instructReady
    case instructRunning
    case captureReady
}

enum LMARGuidancePolicy {
    static func agentStateForReferenceImageEntry() -> LMARGuidanceButtonState {
        .agent
    }

    static func shouldHideReferenceBox(
        overlay: LMARGuidanceOverlayDisplay,
        orientationMatched: Bool,
        hideAll: Bool
    ) -> Bool {
        guard overlay.showBox else { return true }
        return hideAll || !orientationMatched
    }

    static func shouldHideLineArt(
        overlay: LMARGuidanceOverlayDisplay,
        orientationMatched: Bool,
        hideAll: Bool,
        hasLineArtImage: Bool,
        hasReferenceGuideReady: Bool
    ) -> Bool {
        guard overlay.showLineArt else { return true }
        let shouldHide = hideAll || !orientationMatched
        return shouldHide || !hasLineArtImage || !hasReferenceGuideReady
    }

    enum DisplayOrientation {
        case portrait, portraitUpsideDown, landscapeLeft, landscapeRight
    }

    enum OrientationAxis { case portrait, landscape }

    static func isOrientationMatched(referenceAxis: OrientationAxis?, deviceAxis: OrientationAxis?) -> Bool {
        guard let referenceAxis, let deviceAxis else { return false }
        return referenceAxis == deviceAxis
    }

    static func referenceAxis(for imageSize: CGSize) -> OrientationAxis {
        imageSize.width > imageSize.height ? .landscape : .portrait
    }

    static func referenceDisplayOrientation(for imageSize: CGSize) -> DisplayOrientation {
        referenceAxis(for: imageSize) == .portrait ? .portrait : .landscapeRight
    }

    static func shouldRotateReferenceImageToPortrait(imageSize: CGSize) -> Bool {
        referenceAxis(for: imageSize) == .landscape
    }

    static func isDisplayOrientationMatched(
        referenceOrientation: DisplayOrientation?,
        deviceOrientation: DisplayOrientation?
    ) -> Bool {
        guard let referenceOrientation, let deviceOrientation else { return false }
        return referenceOrientation == deviceOrientation
    }

    static func shouldShowGuidance(
        referenceOrientation: DisplayOrientation?,
        deviceOrientation: DisplayOrientation?
    ) -> Bool {
        isOrientationMatched(
            referenceAxis: axis(for: referenceOrientation),
            deviceAxis: axis(for: deviceOrientation)
        )
    }

    static func guidanceRotationAngle(
        referenceAxis: OrientationAxis?,
        deviceOrientation: DisplayOrientation?
    ) -> CGFloat {
        guard let deviceOrientation else { return 0 }
        switch referenceAxis {
        case .landscape:
            switch deviceOrientation {
            case .portrait: return .pi / 2
            case .landscapeLeft: return 0
            case .portraitUpsideDown: return -.pi / 2
            case .landscapeRight: return -.pi
            }
        case .portrait, .none:
            switch deviceOrientation {
            case .portrait: return 0
            case .landscapeLeft: return .pi / 2
            case .portraitUpsideDown: return .pi
            case .landscapeRight: return -.pi / 2
            }
        }
    }

    private static func axis(for orientation: DisplayOrientation?) -> OrientationAxis? {
        guard let orientation else { return nil }
        switch orientation {
        case .portrait, .portraitUpsideDown: return .portrait
        case .landscapeLeft, .landscapeRight: return .landscape
        }
    }

    static func makePortraitCanvasImage(from cgImage: CGImage, shouldRotateToPortrait: Bool) -> CGImage? {
        guard shouldRotateToPortrait else { return cgImage }

        let width = cgImage.width
        let height = cgImage.height
        let rotatedWidth = height
        let rotatedHeight = width
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: nil,
            width: rotatedWidth,
            height: rotatedHeight,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        ) else { return nil }

        context.translateBy(x: CGFloat(rotatedWidth) / 2, y: CGFloat(rotatedHeight) / 2)
        context.rotate(by: -.pi / 2)
        context.draw(
            cgImage,
            in: CGRect(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2, width: CGFloat(width), height: CGFloat(height))
        )
        return context.makeImage()
    }

#if canImport(UIKit)
    static func referenceOrientation(for imageSize: CGSize) -> UIDeviceOrientation {
        switch referenceDisplayOrientation(for: imageSize) {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        }
    }

    static func isDisplayOrientationMatched(
        referenceOrientation: UIDeviceOrientation?,
        deviceOrientation: UIDeviceOrientation
    ) -> Bool {
        isDisplayOrientationMatched(
            referenceOrientation: displayOrientation(for: referenceOrientation),
            deviceOrientation: displayOrientation(for: deviceOrientation)
        )
    }

    static func isOrientationMatched(
        referenceOrientation: UIDeviceOrientation?,
        deviceOrientation: UIDeviceOrientation
    ) -> Bool {
        isOrientationMatched(
            referenceAxis: axis(for: referenceOrientation),
            deviceAxis: axis(for: deviceOrientation)
        )
    }

    static func shouldShowGuidance(
        referenceOrientation: UIDeviceOrientation?,
        deviceOrientation: UIDeviceOrientation
    ) -> Bool {
        shouldShowGuidance(
            referenceOrientation: displayOrientation(for: referenceOrientation),
            deviceOrientation: displayOrientation(for: deviceOrientation)
        )
    }

    static func guidanceRotationAngle(
        referenceAxis: OrientationAxis?,
        deviceOrientation: UIDeviceOrientation
    ) -> CGFloat {
        guidanceRotationAngle(
            referenceAxis: referenceAxis,
            deviceOrientation: displayOrientation(for: deviceOrientation)
        )
    }

    private static func displayOrientation(for orientation: UIDeviceOrientation?) -> DisplayOrientation? {
        guard let orientation else { return nil }
        switch orientation {
        case .portrait: return .portrait
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return nil
        }
    }

    private static func axis(for orientation: UIDeviceOrientation?) -> OrientationAxis? {
        guard let orientation else { return nil }
        switch orientation {
        case .portrait, .portraitUpsideDown: return .portrait
        case .landscapeLeft, .landscapeRight: return .landscape
        default: return nil
        }
    }
#endif
}
