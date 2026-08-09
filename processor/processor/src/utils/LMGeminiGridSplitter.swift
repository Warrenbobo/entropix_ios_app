//
//  LMGeminiGridSplitter.swift
//  processor
//
//  2×2 contact-sheet crop parity with backend `pkg/gemini.splitGrid`.
//

import UIKit

/**
 Splits a Gemini collage into four equal panels.

 Order matches Go `splitGrid` / `q1…q4`: top-left, top-right, bottom-left, bottom-right.
 Uses integer floor halves (`width/2`, `height/2`) like the backend.
 */
enum LMGeminiGridSplitter {

    /**
     Crops a single collage into four tiles.

     - Parameter image: Final non-thought collage from Gemini.
     - Returns: Up to four `UIImage` tiles in TL, TR, BL, BR order. Empty if CGImage missing.
     */
    static func split2x2(_ image: UIImage) -> [UIImage] {
        guard let cgImage = image.cgImage else {
            LMLogger.log("⚠️ LMGeminiGridSplitter: missing cgImage")
            return []
        }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 1, height > 1 else { return [] }

        let halfW = width / 2
        let halfH = height / 2
        let rects: [CGRect] = [
            CGRect(x: 0, y: 0, width: halfW, height: halfH),
            CGRect(x: halfW, y: 0, width: width - halfW, height: halfH),
            CGRect(x: 0, y: halfH, width: halfW, height: height - halfH),
            CGRect(x: halfW, y: halfH, width: width - halfW, height: height - halfH)
        ]

        var tiles: [UIImage] = []
        tiles.reserveCapacity(4)
        for rect in rects {
            guard let cropped = cgImage.cropping(to: rect) else { continue }
            tiles.append(UIImage(cgImage: cropped, scale: image.scale, orientation: .up))
        }
        return tiles
    }
}
