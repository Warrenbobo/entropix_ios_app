//
//  LMDepthLayeringScorer.swift
//  processor
//
//  V5 ref-anchored F/M/B depth layering similarity (DepthAnything / MiDaS inverse depth).
//

import Foundation

/**
 V5 depth-layering scorer (Android `DepthLayeringScorer` parity).

 Uses a simple 3×3 box blur instead of OpenCV `GaussianBlur` for soft masks.
 */
enum LMDepthLayeringScorer {
    private static let spatialGrid = 3
    private static let weightFore: Float = 0.3
    private static let weightMid: Float = 0.5
    private static let weightBack: Float = 0.2
    private static let weightSpatial: Float = 0.75
    private static let weightRatio: Float = 0.25
    private static let flatRelSpanThreshold: Float = 0.05
    private static let flatSceneScore: Float = 0.80
    private static let centroidDistMax: Float = 1.4142135
    private static let trimRatio: Float = 0.02

    private struct LayerThresholds {
        let p33: Float
        let p66: Float
        let p10: Float
        let p90: Float
        let clipMin: Float
        let clipMax: Float
        let relativeSpan: Float
        let isFlatScene: Bool
    }

    private struct LayerSide {
        let distFore: [Double]
        let distMid: [Double]
        let distBack: [Double]
        let centroidFore: (Float, Float)
        let centroidMid: (Float, Float)
        let centroidBack: (Float, Float)
        let af: Float
        let am: Float
        let ab: Float
    }

    /**
     Pairwise S_depth_layering on inverse-depth maps (each side may differ in resolution).
     */
    static func score(
        refDepth: [Float],
        camDepth: [Float],
        refWidth: Int,
        refHeight: Int,
        camWidth: Int,
        camHeight: Int
    ) -> Float {
        precondition(refDepth.count == refWidth * refHeight, "ref depth size mismatch")
        precondition(camDepth.count == camWidth * camHeight, "cam depth size mismatch")

        let (clippedRef, clipMin, clipMax) = clipPercentRange(refDepth)
        let (clippedCam, _, _) = clipPercentRange(camDepth)
        let thresholds = thresholdsFromRef(clippedRef, clipMin: clipMin, clipMax: clipMax)

        let refSide = buildSide(clippedRef, width: refWidth, height: refHeight, thresholds: thresholds)
        let camSide = buildSide(clippedCam, width: camWidth, height: camHeight, thresholds: thresholds)

        let fore = layerMetrics(
            refDist: refSide.distFore,
            camDist: camSide.distFore,
            refCentroid: refSide.centroidFore,
            camCentroid: camSide.centroidFore
        )
        let mid = layerMetrics(
            refDist: refSide.distMid,
            camDist: camSide.distMid,
            refCentroid: refSide.centroidMid,
            camCentroid: camSide.centroidMid
        )
        let back = layerMetrics(
            refDist: refSide.distBack,
            camDist: camSide.distBack,
            refCentroid: refSide.centroidBack,
            camCentroid: camSide.centroidBack
        )

        let sSpatial = weightMid * mid + weightFore * fore + weightBack * back
        let sRatio = (1 - (abs(refSide.af - camSide.af) + abs(refSide.am - camSide.am) + abs(refSide.ab - camSide.ab)) / 2)
            .clamped(to: 0...1)
        let rawScore = (weightSpatial * sSpatial + weightRatio * sRatio).clamped(to: 0...1)

        return thresholds.isFlatScene ? flatSceneScore : rawScore
    }

    private static func clipPercentRange(_ depth: [Float]) -> (clipped: [Float], clipMin: Float, clipMax: Float) {
        guard let minD = depth.min(), let maxD = depth.max() else {
            return (depth, 0, 0)
        }
        if maxD - minD < 1e-12 {
            return (depth, minD, maxD)
        }
        let clipMin = minD + (maxD - minD) * trimRatio
        let clipMax = maxD - (maxD - minD) * trimRatio
        let clipped = depth.map { min(max($0, clipMin), clipMax) }
        return (clipped, clipMin, clipMax)
    }

    private static func thresholdsFromRef(_ clippedRef: [Float], clipMin: Float, clipMax: Float) -> LayerThresholds {
        let p10 = quantile(clippedRef, 0.10)
        let p33 = quantile(clippedRef, 0.33)
        let p66 = quantile(clippedRef, 0.66)
        let p90 = quantile(clippedRef, 0.90)
        let globalSpan = max(p90 - p10, 0)
        let depthRange = max(clipMax - clipMin, 1e-6)
        let relativeSpan = globalSpan / depthRange
        return LayerThresholds(
            p33: p33,
            p66: p66,
            p10: p10,
            p90: p90,
            clipMin: clipMin,
            clipMax: clipMax,
            relativeSpan: relativeSpan,
            isFlatScene: relativeSpan < flatRelSpanThreshold
        )
    }

    private static func quantile(_ values: [Float], _ q: Double) -> Float {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let pos = q * Double(sorted.count - 1)
        let lo = Int(pos)
        let hi = min(lo + 1, sorted.count - 1)
        let frac = Float(pos - Double(lo))
        return sorted[lo] * (1 - frac) + sorted[hi] * frac
    }

    private static func buildSide(
        _ clipped: [Float],
        width: Int,
        height: Int,
        thresholds: LayerThresholds
    ) -> LayerSide {
        var maskFore = [Float](repeating: 0, count: clipped.count)
        var maskMid = [Float](repeating: 0, count: clipped.count)
        var maskBack = [Float](repeating: 0, count: clipped.count)
        for i in clipped.indices {
            let d = clipped[i]
            maskFore[i] = d >= thresholds.p66 ? 1 : 0
            maskMid[i] = (d >= thresholds.p33 && d < thresholds.p66) ? 1 : 0
            maskBack[i] = d < thresholds.p33 ? 1 : 0
        }
        let softFore = boxBlur3x3(maskFore, width: width, height: height)
        let softMid = boxBlur3x3(maskMid, width: width, height: height)
        let softBack = boxBlur3x3(maskBack, width: width, height: height)
        let distFore = nineBinDistribution(softFore, width: width, height: height)
        let distMid = nineBinDistribution(softMid, width: width, height: height)
        let distBack = nineBinDistribution(softBack, width: width, height: height)
        let total = Float(clipped.count)
        var af: Float = 0
        var am: Float = 0
        var ab: Float = 0
        for i in clipped.indices {
            af += maskFore[i]
            am += maskMid[i]
            ab += maskBack[i]
        }
        return LayerSide(
            distFore: distFore,
            distMid: distMid,
            distBack: distBack,
            centroidFore: distributionCentroid(distFore),
            centroidMid: distributionCentroid(distMid),
            centroidBack: distributionCentroid(distBack),
            af: af / total,
            am: am / total,
            ab: ab / total
        )
    }

    /// Separable 3×3 box blur (OpenCV GaussianBlur substitute for pod-light builds).
    private static func boxBlur3x3(_ mask: [Float], width: Int, height: Int) -> [Float] {
        var temp = [Float](repeating: 0, count: mask.count)
        var output = [Float](repeating: 0, count: mask.count)
        for y in 0..<height {
            for x in 0..<width {
                var sum: Float = 0
                var count: Float = 0
                for dx in -1...1 {
                    let xx = x + dx
                    if xx < 0 || xx >= width { continue }
                    sum += mask[y * width + xx]
                    count += 1
                }
                temp[y * width + x] = count > 0 ? sum / count : 0
            }
        }
        for y in 0..<height {
            for x in 0..<width {
                var sum: Float = 0
                var count: Float = 0
                for dy in -1...1 {
                    let yy = y + dy
                    if yy < 0 || yy >= height { continue }
                    sum += temp[yy * width + x]
                    count += 1
                }
                output[y * width + x] = count > 0 ? sum / count : 0
            }
        }
        return output
    }

    private static func nineBinDistribution(_ softMask: [Float], width: Int, height: Int) -> [Double] {
        let cellH = max(height / spatialGrid, 1)
        let cellW = max(width / spatialGrid, 1)
        var dist = [Double](repeating: 0, count: spatialGrid * spatialGrid)
        for row in 0..<spatialGrid {
            for col in 0..<spatialGrid {
                let y1 = row * cellH
                let y2 = row == spatialGrid - 1 ? height : (row + 1) * cellH
                let x1 = col * cellW
                let x2 = col == spatialGrid - 1 ? width : (col + 1) * cellW
                var sum: Double = 0
                var count = 0
                for y in y1..<y2 {
                    for x in x1..<x2 {
                        sum += Double(softMask[y * width + x])
                        count += 1
                    }
                }
                dist[row * spatialGrid + col] = count > 0 ? sum / Double(count) : 0
            }
        }
        let total = dist.reduce(0, +)
        if total > 1e-6 {
            for i in dist.indices { dist[i] /= total }
        }
        return dist
    }

    private static func distributionCentroid(_ dist: [Double]) -> (Float, Float) {
        var cx: Double = 0
        var cy: Double = 0
        var total: Double = 0
        for row in 0..<spatialGrid {
            for col in 0..<spatialGrid {
                let mass = dist[row * spatialGrid + col]
                cx += (Double(col) + 0.5) / Double(spatialGrid) * mass
                cy += (Double(row) + 0.5) / Double(spatialGrid) * mass
                total += mass
            }
        }
        if total < 1e-6 { return (0.5, 0.5) }
        return (Float(cx / total), Float(cy / total))
    }

    private static func layerMetrics(
        refDist: [Double],
        camDist: [Double],
        refCentroid: (Float, Float),
        camCentroid: (Float, Float)
    ) -> Float {
        let bc = LMCompositionMath.bhattacharyyaCoefficient(refDist, camDist)
        var l1: Double = 0
        for i in refDist.indices {
            l1 += abs(refDist[i] - camDist[i])
        }
        let centroidDist = hypot(refCentroid.0 - camCentroid.0, refCentroid.1 - camCentroid.1)
        let l1Gate = (1 - Float(l1 / 2.0)).clamped(to: 0...1)
        let centroidGate = (1 - centroidDist / centroidDistMax).clamped(to: 0...1)
        return (bc * l1Gate * centroidGate).clamped(to: 0...1)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
