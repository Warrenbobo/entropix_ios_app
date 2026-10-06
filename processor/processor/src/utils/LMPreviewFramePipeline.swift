//
//  LMPreviewFramePipeline.swift
//  processor
//
//  Single preview / reference framing entry shared by Inspire Me and the score module.
//  Score module MUST use this pipeline; no separate framing implementation.
//

import CoreVideo
import ImageIO
import UIKit

/// Orientation policy for preview framing — caller samples `UIDeviceOrientation` at the right event.
enum LMPreviewOrientationPolicy: Sendable {
    /// Explicit orientation frozen by the caller (Inspire Me tap, score-tick start, Instruct tap).
    case locked(UIDeviceOrientation)
}

/// Maps `UIImage.Orientation` to Core Graphics property orientation.
enum LMBitmapOrientationMapping {
    static func cgImagePropertyOrientation(
        from orientation: UIImage.Orientation
    ) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

/// Single entry point for preview-sensor framing shared by Inspire Me and the score module.
enum LMPreviewFramePipeline {

    private static let ciContext = CIContext(options: nil)

    /**
     Converts a cached preview buffer to a pixel-accurate bitmap for all ML / Vision steps.

     - Parameters:
       - pixelBuffer: Sensor-space buffer from `latestPreviewPixelBuffer`.
       - orientationPolicy: `.locked` with orientation sampled at tap or tick start.
       - isFrontCamera: Affects EXIF mirroring.
     */
    static func makeBitmap(
        from pixelBuffer: CVPixelBuffer,
        orientationPolicy: LMPreviewOrientationPolicy,
        isFrontCamera: Bool
    ) -> LMBitmapDescriptor? {
        let deviceOrientation: UIDeviceOrientation
        switch orientationPolicy {
        case .locked(let orientation):
            deviceOrientation = orientation
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        let uiOrientation = LMOrientationMatcher.previewEXIF(
            deviceOrientation: deviceOrientation,
            isFrontCamera: isFrontCamera
        )
        return LMBitmapDescriptor(
            cgImage: cgImage,
            pixelWidth: cgImage.width,
            pixelHeight: cgImage.height,
            orientation: LMBitmapOrientationMapping.cgImagePropertyOrientation(from: uiOrientation),
            uiImageOrientation: uiOrientation
        )
    }

    /// Convenience: same as `makeBitmap` then `uiImage` (for call sites that still take `UIImage`).
    static func makeUIImage(
        from pixelBuffer: CVPixelBuffer,
        orientationPolicy: LMPreviewOrientationPolicy,
        isFrontCamera: Bool
    ) -> UIImage? {
        makeBitmap(
            from: pixelBuffer,
            orientationPolicy: orientationPolicy,
            isFrontCamera: isFrontCamera
        )?.uiImage
    }

    /**
     Deep-copies a camera `CVPixelBuffer` so AVFoundation can recycle the original.

     Live score ticks and Get Tips must not hold the session’s ring-buffer slot.
     */
    static func copyPixelBuffer(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(source, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(source, .readOnly) }

        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let pixelFormat = CVPixelBufferGetPixelFormatType(source)
        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(source)
        guard let srcBase = CVPixelBufferGetBaseAddress(source) else { return nil }

        var copy: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            kCVPixelBufferBytesPerRowAlignmentKey as String: srcBytesPerRow
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormat,
            attrs as CFDictionary,
            &copy
        )
        guard status == kCVReturnSuccess, let copy else { return nil }

        CVPixelBufferLockBaseAddress(copy, [])
        defer { CVPixelBufferUnlockBaseAddress(copy, []) }
        guard let dstBase = CVPixelBufferGetBaseAddress(copy) else { return nil }

        let dstBytesPerRow = CVPixelBufferGetBytesPerRow(copy)
        let rowBytes = min(srcBytesPerRow, dstBytesPerRow)
        for row in 0..<height {
            memcpy(
                dstBase.advanced(by: row * dstBytesPerRow),
                srcBase.advanced(by: row * srcBytesPerRow),
                rowBytes
            )
        }
        return copy
    }
}

/// Sibling framing path for album / suggestion stills (not live preview).
enum LMReferenceFramePipeline {

    /**
     Builds a pixel-accurate descriptor from a reference `UIImage`.

     Uses the image's existing orientation tag; pixel dimensions come from `cgImage`.
     */
    static func fromUIImage(_ image: UIImage) -> LMBitmapDescriptor? {
        guard let cgImage = image.cgImage else { return nil }
        let uiOrientation = image.imageOrientation
        return LMBitmapDescriptor(
            cgImage: cgImage,
            pixelWidth: cgImage.width,
            pixelHeight: cgImage.height,
            orientation: LMBitmapOrientationMapping.cgImagePropertyOrientation(from: uiOrientation),
            uiImageOrientation: uiOrientation
        )
    }
}
