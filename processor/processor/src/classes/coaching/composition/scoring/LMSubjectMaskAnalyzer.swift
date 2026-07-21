//
//  LMSubjectMaskAnalyzer.swift
//  processor
//
//  U2-Netp saliency mask layout features (S_rule).
//

import Foundation

/**
 Derives composition-layout features from a U2-Netp saliency mask and compares ref/cam pairs
 (Android `SubjectMaskAnalyzer` parity).
 */
enum LMSubjectMaskAnalyzer {
    private static let spatialGrid = 3
    private static let maskThreshold: Float = 0.5
    private static let centerDistScale: Float = 0.3
    private static let thirdsDistScale: Float = 0.35
    private static let axisAngleScale: Float = 45
    private static let weightSubjectCenter: Float = 0.30
    private static let weightSubjectScale: Float = 0.25
    private static let weightNegativeSpace: Float = 0.20
    private static let weightRuleOfThirds: Float = 0.15
    private static let weightHorizonAxis: Float = 0.10
    private static let pcaWeightThreshold: Float = 0.3
    private static let massEps: Float = 1e-6

    private struct SubjectFeatures {
        let centerX: Float
        let centerY: Float
        let areaRatio: Float
        let thirdsDistance: Float
        let mainAxisAngle: Float
        let negativeSpaceGrid: [Double]
        let hasMass: Bool
    }

    /// Per-component layout scores between ref/cam masks.
    struct LayoutComponents: Sendable {
        let subjectCenter: Float
        let negativeSpace: Float
        let combinedRule: Float
    }

    /**
     Computes S_rule and exposes subject-center / negative-space sub-scores.
     */
    static func scoreComponents(
        refMask: [Float],
        camMask: [Float],
        width: Int,
        height: Int
    ) -> LayoutComponents {
        let refFeatures = extractFeatures(refMask, width: width, height: height)
        let camFeatures = extractFeatures(camMask, width: width, height: height)
        if !refFeatures.hasMass && !camFeatures.hasMass {
            return LayoutComponents(
                subjectCenter: LMCompositionMath.emptyNeutralScore,
                negativeSpace: LMCompositionMath.emptyNeutralScore,
                combinedRule: LMCompositionMath.emptyNeutralScore
            )
        }

        let sCenter = compareCenter(refFeatures, camFeatures)
        let sScale = compareScale(refFeatures, camFeatures)
        let sNegative = compareNegativeSpace(refFeatures, camFeatures)
        let sThirds = compareThirds(refFeatures, camFeatures)
        let sAxis = compareMainAxis(refFeatures, camFeatures)
        let combined = (
            weightSubjectCenter * sCenter +
            weightSubjectScale * sScale +
            weightNegativeSpace * sNegative +
            weightRuleOfThirds * sThirds +
            weightHorizonAxis * sAxis
        ).clamped(to: 0...1)
        return LayoutComponents(
            subjectCenter: sCenter,
            negativeSpace: sNegative,
            combinedRule: combined
        )
    }

    /// Computes S_rule from normalized saliency masks of equal width/height.
    static func scoreRule(refMask: [Float], camMask: [Float], width: Int, height: Int) -> Float {
        scoreComponents(refMask: refMask, camMask: camMask, width: width, height: height).combinedRule
    }

    private static func extractFeatures(_ mask: [Float], width: Int, height: Int) -> SubjectFeatures {
        let normalized = minMaxNormalize(mask)
        var totalMass: Double = 0
        var sumX: Double = 0
        var sumY: Double = 0
        var highCount = 0
        for y in 0..<height {
            for x in 0..<width {
                let value = normalized[y * width + x]
                totalMass += Double(value)
                sumX += Double(x) * Double(value)
                sumY += Double(y) * Double(value)
                if value >= maskThreshold { highCount += 1 }
            }
        }
        if totalMass < Double(massEps) {
            return SubjectFeatures(
                centerX: 0.5,
                centerY: 0.5,
                areaRatio: 0,
                thirdsDistance: minDistanceToThirdIntersections(0.5, 0.5),
                mainAxisAngle: 0,
                negativeSpaceGrid: [Double](repeating: 0, count: spatialGrid * spatialGrid),
                hasMass: false
            )
        }

        let centerX = Float(sumX / totalMass / Double(width))
        let centerY = Float(sumY / totalMass / Double(height))
        return SubjectFeatures(
            centerX: centerX,
            centerY: centerY,
            areaRatio: Float(highCount) / Float(normalized.count),
            thirdsDistance: minDistanceToThirdIntersections(centerX, centerY),
            mainAxisAngle: computeMainAxisAngle(normalized, width: width, height: height),
            negativeSpaceGrid: negativeSpaceGrid(normalized, width: width, height: height),
            hasMass: true
        )
    }

    private static func compareCenter(_ ref: SubjectFeatures, _ cam: SubjectFeatures) -> Float {
        if !ref.hasMass && !cam.hasMass { return LMCompositionMath.emptyNeutralScore }
        if !ref.hasMass || !cam.hasMass { return 0 }
        let distance = hypot(ref.centerX - cam.centerX, ref.centerY - cam.centerY)
        return (1 - distance / centerDistScale).clamped(to: 0...1)
    }

    private static func compareScale(_ ref: SubjectFeatures, _ cam: SubjectFeatures) -> Float {
        if !ref.hasMass && !cam.hasMass { return LMCompositionMath.emptyNeutralScore }
        if !ref.hasMass || !cam.hasMass { return 0 }
        return (1 - abs(ref.areaRatio - cam.areaRatio)).clamped(to: 0...1)
    }

    private static func compareNegativeSpace(_ ref: SubjectFeatures, _ cam: SubjectFeatures) -> Float {
        if !ref.hasMass && !cam.hasMass { return LMCompositionMath.emptyNeutralScore }
        if !ref.hasMass || !cam.hasMass { return 0 }
        return LMCompositionMath.bhattacharyyaCoefficient(ref.negativeSpaceGrid, cam.negativeSpaceGrid)
            .clamped(to: 0...1)
    }

    /**
     Compares normalized subject-center distance (replaces delta-of-thirds-distance
     which inflated scores for unrelated scenes).
     */
    private static func compareThirds(_ ref: SubjectFeatures, _ cam: SubjectFeatures) -> Float {
        if !ref.hasMass && !cam.hasMass { return LMCompositionMath.emptyNeutralScore }
        if !ref.hasMass || !cam.hasMass { return 0 }
        let distance = hypot(ref.centerX - cam.centerX, ref.centerY - cam.centerY)
        return (1 - distance / thirdsDistScale).clamped(to: 0...1)
    }

    private static func compareMainAxis(_ ref: SubjectFeatures, _ cam: SubjectFeatures) -> Float {
        if !ref.hasMass && !cam.hasMass { return LMCompositionMath.emptyNeutralScore }
        if !ref.hasMass || !cam.hasMass { return 0 }
        let delta = angleDifference(ref.mainAxisAngle, cam.mainAxisAngle)
        return (1 - delta / axisAngleScale).clamped(to: 0...1)
    }

    private static func minMaxNormalize(_ mask: [Float]) -> [Float] {
        guard let minValue = mask.min(), let maxValue = mask.max() else {
            return [Float](repeating: 0, count: mask.count)
        }
        if maxValue - minValue < massEps {
            return [Float](repeating: 0, count: mask.count)
        }
        let range = maxValue - minValue
        return mask.map { ($0 - minValue) / range }
    }

    private static func negativeSpaceGrid(_ normalized: [Float], width: Int, height: Int) -> [Double] {
        var grid = [Double](repeating: 0, count: spatialGrid * spatialGrid)
        var counts = [Int](repeating: 0, count: spatialGrid * spatialGrid)
        for y in 0..<height {
            for x in 0..<width {
                let cell = cellIndex(Float(x), Float(y), width: width, height: height)
                grid[cell] += Double(1 - normalized[y * width + x])
                counts[cell] += 1
            }
        }
        for cell in grid.indices where counts[cell] > 0 {
            grid[cell] /= Double(counts[cell])
        }
        let total = grid.reduce(0, +)
        if total > 0 {
            for i in grid.indices { grid[i] /= total }
        }
        return grid
    }

    private static func computeMainAxisAngle(_ normalized: [Float], width: Int, height: Int) -> Float {
        var totalWeight: Double = 0
        var meanX: Double = 0
        var meanY: Double = 0
        for y in 0..<height {
            for x in 0..<width {
                let weight = Double(normalized[y * width + x])
                if weight < Double(pcaWeightThreshold) { continue }
                totalWeight += weight
                meanX += Double(x) * weight
                meanY += Double(y) * weight
            }
        }
        if totalWeight < Double(massEps) { return 0 }
        meanX /= totalWeight
        meanY /= totalWeight

        var covXx: Double = 0
        var covYy: Double = 0
        var covXy: Double = 0
        for y in 0..<height {
            for x in 0..<width {
                let weight = Double(normalized[y * width + x])
                if weight < Double(pcaWeightThreshold) { continue }
                let dx = Double(x) - meanX
                let dy = Double(y) - meanY
                covXx += weight * dx * dx
                covYy += weight * dy * dy
                covXy += weight * dx * dy
            }
        }
        let angleRad = 0.5 * atan2(2.0 * covXy, covXx - covYy)
        var angleDeg = (angleRad * 180.0 / .pi).truncatingRemainder(dividingBy: 180.0)
        if angleDeg < 0 { angleDeg += 180.0 }
        return Float(angleDeg)
    }

    private static func minDistanceToThirdIntersections(_ centerX: Float, _ centerY: Float) -> Float {
        let intersections: [(Float, Float)] = [
            (1.0 / 3.0, 1.0 / 3.0),
            (2.0 / 3.0, 1.0 / 3.0),
            (1.0 / 3.0, 2.0 / 3.0),
            (2.0 / 3.0, 2.0 / 3.0)
        ]
        return intersections.map { hypot(centerX - $0.0, centerY - $0.1) }.min() ?? 0
    }

    private static func cellIndex(_ x: Float, _ y: Float, width: Int, height: Int) -> Int {
        let col = max(0, min(Int((x / Float(width)) * Float(spatialGrid)), spatialGrid - 1))
        let row = max(0, min(Int((y / Float(height)) * Float(spatialGrid)), spatialGrid - 1))
        return row * spatialGrid + col
    }

    private static func angleDifference(_ angleA: Float, _ angleB: Float) -> Float {
        let diff = abs(angleA - angleB).truncatingRemainder(dividingBy: 180)
        return min(diff, 180 - diff)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
