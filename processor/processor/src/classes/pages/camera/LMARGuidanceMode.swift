//
//  LMARGuidanceMode.swift
//  processor
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
#endif

enum LMARGuidanceButtonState {
    case unavailable
    case off
    case box
    case lineArt

    var buttonAlpha: CGFloat {
        switch self {
        case .unavailable:
            return 0.55
        case .off, .box, .lineArt:
            return 1.0
        }
    }

    var labelAlpha: CGFloat {
        switch self {
        case .unavailable:
            return 0.55
        case .off, .box, .lineArt:
            return 1.0
        }
    }

    var requiresReferenceDetection: Bool {
        switch self {
        case .box, .lineArt:
            return true
        case .unavailable, .off:
            return false
        }
    }

    var isEnabledGuidance: Bool {
        switch self {
        case .box, .lineArt:
            return true
        case .unavailable, .off:
            return false
        }
    }

    var nextState: LMARGuidanceButtonState {
        switch self {
        case .unavailable:
            return .unavailable
        case .off:
            return .box
        case .box:
            return .lineArt
        case .lineArt:
            return .off
        }
    }

    var logName: String {
        switch self {
        case .unavailable:
            return "Unavailable"
        case .off:
            return "Off"
        case .box:
            return "Box"
        case .lineArt:
            return "LineArt"
        }
    }
}

enum LMARGuidancePolicy {
    static func stateForReferenceImageEntry(from preferredState: LMARGuidanceButtonState) -> LMARGuidanceButtonState {
        preferredState == .unavailable ? .box : preferredState
    }

    static func shouldHideReferenceBox(
        displayState: LMARGuidanceButtonState,
        orientationMatched: Bool,
        hideAll: Bool
    ) -> Bool {
        let shouldHide = hideAll || !orientationMatched

        switch displayState {
        case .box:
            return shouldHide
        case .unavailable, .off, .lineArt:
            return true
        }
    }

    static func shouldHideLineArt(
        displayState: LMARGuidanceButtonState,
        orientationMatched: Bool,
        hideAll: Bool,
        hasLineArtImage: Bool,
        hasReferenceGuideReady: Bool
    ) -> Bool {
        let shouldHide = hideAll || !orientationMatched

        switch displayState {
        case .lineArt:
            return shouldHide || !hasLineArtImage || !hasReferenceGuideReady
        case .unavailable, .off, .box:
            return true
        }
    }

    enum DisplayOrientation {
        case portrait
        case portraitUpsideDown
        case landscapeLeft
        case landscapeRight
    }

    enum OrientationAxis {
        case portrait
        case landscape
    }

    static func isOrientationMatched(referenceAxis: OrientationAxis?, deviceAxis: OrientationAxis?) -> Bool {
        guard let referenceAxis, let deviceAxis else {
            return false
        }

        return referenceAxis == deviceAxis
    }

    static func referenceAxis(for imageSize: CGSize) -> OrientationAxis {
        imageSize.width > imageSize.height ? .landscape : .portrait
    }

    static func referenceDisplayOrientation(for imageSize: CGSize) -> DisplayOrientation {
        switch referenceAxis(for: imageSize) {
        case .portrait:
            return .portrait
        case .landscape:
            return .landscapeRight
        }
    }

    static func shouldRotateReferenceImageToPortrait(imageSize: CGSize) -> Bool {
        referenceAxis(for: imageSize) == .landscape
    }

    static func isDisplayOrientationMatched(referenceOrientation: DisplayOrientation?, deviceOrientation: DisplayOrientation?) -> Bool {
        guard let referenceOrientation, let deviceOrientation else {
            return false
        }

        return referenceOrientation == deviceOrientation
    }

    static func shouldShowGuidance(referenceOrientation: DisplayOrientation?, deviceOrientation: DisplayOrientation?) -> Bool {
        isOrientationMatched(
            referenceAxis: axis(for: referenceOrientation),
            deviceAxis: axis(for: deviceOrientation)
        )
    }

    static func guidanceRotationAngle(referenceAxis: OrientationAxis?, deviceOrientation: DisplayOrientation?) -> CGFloat {
        guard let deviceOrientation else {
            return 0
        }

        switch referenceAxis {
        case .landscape:
            switch deviceOrientation {
            case .portrait:
                return .pi / 2
            case .landscapeLeft:
                return 0
            case .portraitUpsideDown:
                return -.pi / 2
            case .landscapeRight:
                return -.pi
            }
        case .portrait, .none:
            switch deviceOrientation {
            case .portrait:
                return 0
            case .landscapeLeft:
                return .pi / 2
            case .portraitUpsideDown:
                return .pi
            case .landscapeRight:
                return -.pi / 2
            }
        }
    }

    private static func axis(for orientation: DisplayOrientation?) -> OrientationAxis? {
        guard let orientation else { return nil }

        switch orientation {
        case .portrait, .portraitUpsideDown:
            return .portrait
        case .landscapeLeft, .landscapeRight:
            return .landscape
        }
    }

    static func makePortraitCanvasImage(from cgImage: CGImage, shouldRotateToPortrait: Bool) -> CGImage? {
        guard shouldRotateToPortrait else {
            return cgImage
        }

        let width = cgImage.width
        let height = cgImage.height
        let rotatedWidth = height
        let rotatedHeight = width
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = cgImage.bitmapInfo.rawValue

        guard let context = CGContext(
            data: nil,
            width: rotatedWidth,
            height: rotatedHeight,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.translateBy(x: CGFloat(rotatedWidth) / 2, y: CGFloat(rotatedHeight) / 2)
        context.rotate(by: -.pi / 2)
        context.draw(
            cgImage,
            in: CGRect(
                x: -CGFloat(width) / 2,
                y: -CGFloat(height) / 2,
                width: CGFloat(width),
                height: CGFloat(height)
            )
        )

        return context.makeImage()
    }

#if canImport(UIKit)
    static func referenceOrientation(for imageSize: CGSize) -> UIDeviceOrientation {
        switch referenceDisplayOrientation(for: imageSize) {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        }
    }

    static func isDisplayOrientationMatched(referenceOrientation: UIDeviceOrientation?, deviceOrientation: UIDeviceOrientation) -> Bool {
        isDisplayOrientationMatched(
            referenceOrientation: displayOrientation(for: referenceOrientation),
            deviceOrientation: displayOrientation(for: deviceOrientation)
        )
    }

    static func isOrientationMatched(referenceOrientation: UIDeviceOrientation?, deviceOrientation: UIDeviceOrientation) -> Bool {
        isOrientationMatched(
            referenceAxis: axis(for: referenceOrientation),
            deviceAxis: axis(for: deviceOrientation)
        )
    }

    static func shouldShowGuidance(referenceOrientation: UIDeviceOrientation?, deviceOrientation: UIDeviceOrientation) -> Bool {
        shouldShowGuidance(
            referenceOrientation: displayOrientation(for: referenceOrientation),
            deviceOrientation: displayOrientation(for: deviceOrientation)
        )
    }

    static func guidanceRotationAngle(referenceAxis: OrientationAxis?, deviceOrientation: UIDeviceOrientation) -> CGFloat {
        guidanceRotationAngle(
            referenceAxis: referenceAxis,
            deviceOrientation: displayOrientation(for: deviceOrientation)
        )
    }

    private static func displayOrientation(for orientation: UIDeviceOrientation?) -> DisplayOrientation? {
        guard let orientation else { return nil }

        switch orientation {
        case .portrait:
            return .portrait
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return nil
        }
    }

    private static func axis(for orientation: UIDeviceOrientation?) -> OrientationAxis? {
        guard let orientation else { return nil }

        switch orientation {
        case .portrait, .portraitUpsideDown:
            return .portrait
        case .landscapeLeft, .landscapeRight:
            return .landscape
        default:
            return nil
        }
    }
#endif
}
