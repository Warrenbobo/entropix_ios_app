//
//  LMHumanFrameSnapshot.swift
//  processor
//

import CoreGraphics
import CoreVideo
import ImageIO

/// Single-frame human perception result (Vision normalized, origin bottom-left).
struct LMHumanFrameSnapshot {
    enum Source: String {
        case referenceWarmup
        case livePreview
        case scoreCapture
    }

    let timestamp: CFTimeInterval
    let source: Source
    let segmentationMask: CVPixelBuffer
    let derivedBBox: CGRect
    let maskPixelCount: Int
    let maskConfidence: Float
    let imageSize: CGSize
    let orientation: CGImagePropertyOrientation

    /// Converts derived bbox to app `BoundingBox` model.
    var boundingBox: BoundingBox {
        BoundingBox(
            x: Double(derivedBBox.origin.x),
            y: Double(derivedBBox.origin.y),
            width: Double(derivedBBox.width),
            height: Double(derivedBBox.height)
        )
    }
}
