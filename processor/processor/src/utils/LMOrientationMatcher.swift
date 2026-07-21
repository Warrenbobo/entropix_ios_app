//
//  LMOrientationMatcher.swift
//  processor
//

import UIKit
import CoreVideo

/// Portrait vs landscape axis used to compare a reference image with device hold.
enum LMImageOrientation {
    case portrait
    case landscape
}

/// Shared orientation helpers for Inspire Me capture, agent preview frames, and AR Guidance.
enum LMOrientationMatcher {

    // MARK: - Reference vs device axis (AR Guidance)

    /// Returns the aspect axis of an image from its pixel dimensions.
    static func imageAxis(for size: CGSize) -> LMImageOrientation {
        size.width > size.height ? .landscape : .portrait
    }

    /// Returns the aspect axis of the current device hold.
    static func deviceAxis(for orientation: UIDeviceOrientation) -> LMImageOrientation {
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            return .landscape
        default:
            return .portrait
        }
    }

    /// `true` when reference aspect matches device hold (portrait↔portrait or landscape↔landscape).
    static func isOrientationMatched(imageSize: CGSize, deviceOrientation: UIDeviceOrientation) -> Bool {
        imageAxis(for: imageSize) == deviceAxis(for: orientationForCapture(deviceOrientation))
    }

    // MARK: - Capture lock

    /// Physical hold at capture time; face-up/down uses the last definite orientation.
    static func orientationForCapture() -> UIDeviceOrientation {
        orientationForCapture(LMDeviceOrientationManager.shared.currentOrientation)
    }

    static func orientationForCapture(_ orientation: UIDeviceOrientation) -> UIDeviceOrientation {
        switch orientation {
        case .unknown, .faceUp, .faceDown:
            return LMDeviceOrientationManager.shared.lastDefiniteOrientation
        default:
            return orientation
        }
    }

    // MARK: - Preview frame (shared via LMPreviewFramePipeline)

    /// EXIF orientation for a raw sensor buffer displayed in the current device hold.
    /// Prefer `LMPreviewFramePipeline.makeBitmap` / `makeUIImage` at call sites.
    static func previewEXIF(
        deviceOrientation: UIDeviceOrientation,
        isFrontCamera: Bool
    ) -> UIImage.Orientation {
        if isFrontCamera {
            switch deviceOrientation {
            case .portrait: return .leftMirrored
            case .landscapeLeft: return .downMirrored
            case .landscapeRight: return .upMirrored
            case .portraitUpsideDown: return .rightMirrored
            default: return .leftMirrored
            }
        }

        switch deviceOrientation {
        case .portrait: return .right
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right
        }
    }

    /// Converts a preview sensor buffer to a `UIImage` tagged for the current hold.
    /// Prefer `LMPreviewFramePipeline` at new call sites; kept for legacy / test callers.
    static func imageFromPreviewBuffer(
        _ pixelBuffer: CVPixelBuffer,
        deviceOrientation: UIDeviceOrientation,
        isFrontCamera: Bool
    ) -> UIImage? {
        LMPreviewFramePipeline.makeUIImage(
            from: pixelBuffer,
            orientationPolicy: .locked(deviceOrientation),
            isFrontCamera: isFrontCamera
        )
    }
}
