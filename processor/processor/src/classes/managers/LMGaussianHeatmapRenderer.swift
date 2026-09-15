//
//  LMGaussianHeatmapRenderer.swift
//  processor
//
//  Local Scene Explore heatmap: soft center glow per Spot (no hard bbox edges).
//

import UIKit

/**
 Synthesizes a warm heatmap overlay from Spot bboxes.

 Each Spot is a soft elliptical Gaussian that peaks at the bbox center and fades
 to fully transparent well before a hard rectangular edge. Multiple Spots take
 the per-pixel maximum intensity. The returned image is an **overlay only**
 (transparent where intensity is zero) — callers draw it on top of the freeze frame.
 */
enum LMGaussianHeatmapRenderer {

    /// Hide heatmap when wide scene or Spot bbox union covers too much of the frame.
    static func shouldHideHeatmap(wideScene: Bool, coverage: CGFloat) -> Bool {
        wideScene || coverage > 0.70
    }

    /**
     Estimates union coverage of Spot bboxes over the unit square via a dense grid.

     - Parameter spots: Spots with normalized xywh bboxes.
     - Returns: Covered fraction in 0…1.
     */
    static func bboxUnionCoverage(spots: [LMSceneExploreSpot]) -> CGFloat {
        guard !spots.isEmpty else { return 0 }
        let n = 96
        var covered = 0
        for iy in 0..<n {
            for ix in 0..<n {
                let point = CGPoint(
                    x: (CGFloat(ix) + 0.5) / CGFloat(n),
                    y: (CGFloat(iy) + 0.5) / CGFloat(n)
                )
                for spot in spots {
                    if spot.normalizedRect.contains(point) {
                        covered += 1
                        break
                    }
                }
            }
        }
        return CGFloat(covered) / CGFloat(n * n)
    }

    /**
     Builds a transparent warm heatmap overlay sized to `base` pixels.

     - Parameters:
       - base: Freeze frame (orientation should already be `.up`).
       - spots: VLM spots with normalized bboxes.
       - opacity: Peak alpha multiplier for the glow.
     */
    static func render(
        base: UIImage,
        spots: [LMSceneExploreSpot],
        opacity: CGFloat
    ) -> UIImage? {
        let upright = base.lmNormalizedImage()
        guard let cgBase = upright.cgImage, !spots.isEmpty else { return nil }
        let pixelW = cgBase.width
        let pixelH = cgBase.height
        guard pixelW > 0, pixelH > 0 else { return nil }

        let maxPixels = 2_000_000
        let total = pixelW * pixelH
        let downScale = total > maxPixels ? sqrt(CGFloat(maxPixels) / CGFloat(total)) : 1
        let workW = max(1, Int((CGFloat(pixelW) * downScale).rounded()))
        let workH = max(1, Int((CGFloat(pixelH) * downScale).rounded()))

        var field = [Float](repeating: 0, count: workW * workH)
        for spot in spots {
            accumulateSoftGlow(into: &field, width: workW, height: workH, rect: spot.normalizedRect)
        }

        guard let heat = tintedOverlay(
            field: field,
            width: workW,
            height: workH,
            opacity: Float(max(0, min(1, opacity)))
        ) else {
            return nil
        }

        guard workW != pixelW || workH != pixelH else {
            return heat
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let outSize = CGSize(width: pixelW, height: pixelH)
        let renderer = UIGraphicsImageRenderer(size: outSize, format: format)
        return renderer.image { _ in
            heat.draw(in: CGRect(origin: .zero, size: outSize))
        }
    }

    // MARK: - Private

    /**
     Soft glow from bbox center; rasterized over ~3σ (not clipped to the bbox rect).

     At the bbox edge intensity is already faint; outside it falls to ~0 so no
     rectangular silhouette appears.
     */
    private static func accumulateSoftGlow(
        into field: inout [Float],
        width: Int,
        height: Int,
        rect: CGRect
    ) {
        let clamped = rect.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clamped.isNull, clamped.width > 0.002, clamped.height > 0.002 else { return }

        let cx = clamped.midX * CGFloat(width)
        let cy = clamped.midY * CGFloat(height)
        // Half-extent ≈ 2.8σ → bbox edge ~e^(-4) ≈ 0.018 (near transparent).
        let sigmaX = max(1.5, clamped.width * CGFloat(width) * 0.5 / 2.8)
        let sigmaY = max(1.5, clamped.height * CGFloat(height) * 0.5 / 2.8)
        let invSX2 = 1 / (2 * sigmaX * sigmaX)
        let invSY2 = 1 / (2 * sigmaY * sigmaY)

        let padX = Int(ceil(sigmaX * 3.2))
        let padY = Int(ceil(sigmaY * 3.2))
        let x0 = max(0, Int(floor(cx)) - padX)
        let y0 = max(0, Int(floor(cy)) - padY)
        let x1 = min(width, Int(ceil(cx)) + padX)
        let y1 = min(height, Int(ceil(cy)) + padY)
        guard x1 > x0, y1 > y0 else { return }

        for y in y0..<y1 {
            let dy = CGFloat(y) + 0.5 - cy
            let gy = dy * dy * invSY2
            let row = y * width
            for x in x0..<x1 {
                let dx = CGFloat(x) + 0.5 - cx
                let g = Float(exp(-(dx * dx * invSX2 + gy)))
                if g > field[row + x] {
                    field[row + x] = g
                }
            }
        }
    }

    private static func tintedOverlay(
        field: [Float],
        width: Int,
        height: Int,
        opacity: Float
    ) -> UIImage? {
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        // Drop nearly-invisible fringe so no rectangular halo remains.
        let minT: Float = 0.04
        for i in 0..<(width * height) {
            let t = max(0, min(1, field[i]))
            guard t > minT else { continue }
            // Remap so the visible range starts soft at minT.
            let uVis = (t - minT) / (1 - minT)
            let r: Float
            let g: Float
            let b: Float
            if uVis < 0.5 {
                let u = uVis / 0.5
                r = 0.95 * u + 0.55 * (1 - u)
                g = 0.35 * u + 0.12 * (1 - u)
                b = 0.05 * u
            } else {
                let u = (uVis - 0.5) / 0.5
                r = 0.95 + 0.05 * u
                g = 0.35 + 0.55 * u
                b = 0.05 + 0.35 * u
            }
            let a = uVis * opacity * 0.85
            let o = i * 4
            rgba[o] = UInt8(min(255, Int(r * a * 255)))
            rgba[o + 1] = UInt8(min(255, Int(g * a * 255)))
            rgba[o + 2] = UInt8(min(255, Int(b * a * 255)))
            rgba[o + 3] = UInt8(min(255, Int(a * 255)))
        }

        let data = Data(rgba)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let provider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: 1, orientation: .up)
    }
}
