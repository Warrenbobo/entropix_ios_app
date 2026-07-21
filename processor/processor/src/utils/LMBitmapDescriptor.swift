//
//  LMBitmapDescriptor.swift
//  processor
//
//  Pixel-accurate bitmap metadata shared by preview framing and score / Inspire Me ML.
//

import CoreGraphics
import ImageIO
import UIKit

/// Pixel-accurate bitmap for ML / Vision — use instead of `UIImage.size` (points).
struct LMBitmapDescriptor: Sendable {
    let cgImage: CGImage
    let pixelWidth: Int
    let pixelHeight: Int
    let orientation: CGImagePropertyOrientation
    let uiImageOrientation: UIImage.Orientation

    /// Builds a `UIImage` tagged with the framing orientation (no pixel bake).
    var uiImage: UIImage {
        UIImage(cgImage: cgImage, scale: 1.0, orientation: uiImageOrientation)
    }

    /// Orientation-applied pixel size (width/height after EXIF rotation).
    var displayPixelSize: CGSize {
        switch uiImageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            return CGSize(width: pixelHeight, height: pixelWidth)
        default:
            return CGSize(width: pixelWidth, height: pixelHeight)
        }
    }
}
