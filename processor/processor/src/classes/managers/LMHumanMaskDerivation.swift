//
//  LMHumanMaskDerivation.swift
//  processor
//

import CoreGraphics
import CoreVideo

/// Derives axis-aligned bounding boxes from person segmentation masks.
enum LMHumanMaskDerivation {
    static let personMaskThreshold: UInt8 = 128
    static let minPersonPixels = 400
    static let minBBoxAreaFraction: CGFloat = 0.005

    /// Scans foreground pixels and returns Vision-normalized bbox + pixel count.
    static func derivedBoundingBox(
        from mask: CVPixelBuffer,
        threshold: UInt8 = personMaskThreshold
    ) -> (bbox: CGRect, pixelCount: Int)? {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        guard width > 0, height > 0,
              let base = CVPixelBufferGetBaseAddress(mask) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var pixelCount = 0

        for y in 0..<height {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width where row[x] >= threshold {
                pixelCount += 1
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }

        guard pixelCount >= minPersonPixels, maxX >= minX, maxY >= minY else {
            return nil
        }

        let bboxWidth = CGFloat(maxX - minX + 1) / CGFloat(width)
        let bboxHeight = CGFloat(maxY - minY + 1) / CGFloat(height)
        let area = bboxWidth * bboxHeight
        guard area >= minBBoxAreaFraction else {
            return nil
        }

        // Vision normalized: origin bottom-left.
        let normX = CGFloat(minX) / CGFloat(width)
        let normY = CGFloat(height - maxY - 1) / CGFloat(height)

        return (
            CGRect(x: normX, y: normY, width: bboxWidth, height: bboxHeight),
            pixelCount
        )
    }

    /// Exponential moving average smoothing for live preview bboxes.
    static func smoothBBox(previous: CGRect?, current: CGRect, alpha: CGFloat = 0.35) -> CGRect {
        guard let previous else { return current }
        return CGRect(
            x: previous.origin.x + alpha * (current.origin.x - previous.origin.x),
            y: previous.origin.y + alpha * (current.origin.y - previous.origin.y),
            width: previous.width + alpha * (current.width - previous.width),
            height: previous.height + alpha * (current.height - previous.height)
        )
    }
}
