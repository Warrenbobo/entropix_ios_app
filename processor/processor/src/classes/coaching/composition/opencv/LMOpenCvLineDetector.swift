//
//  LMOpenCvLineDetector.swift
//  processor
//
//  Spatial geometric matching for composition scoring (Android OpenCvLineDetector parity).
//

import Foundation

/**
 OpenCV LSD-based spatial geometric matching for composition scoring — scoring math matches
 Android `OpenCvLineDetector` exactly.

 Line extraction uses a pure-Swift probabilistic Hough / connected-edge line segment
 approximator on the binarized edge map; it replaces OpenCV LSD for pod-light builds
 (no OpenCV framework required).
 */
enum LMOpenCvLineDetector {
    private static let edgeBinarizeThreshold: Float = 0.3
    private static let lineHistogramBins = 18
    private static let lengthHistogramBins = 8
    private static let spatialGrid = 5
    private static let vpTopLines = 25
    private static let vpDistScale: Float = 1.0
    private static let vpParallelAngleEps: Double = 5.0
    private static let weightOrientationSpatial: Float = 0.35
    private static let weightLinePosition: Float = 0.20
    private static let weightLineLength: Float = 0.15
    private static let weightVanishingPoint: Float = 0.20
    private static let weightDepthLayering: Float = 0.10

    private struct LineSegment {
        let x1: Double
        let y1: Double
        let x2: Double
        let y2: Double

        var centerX: Double { (x1 + x2) / 2.0 }
        var centerY: Double { (y1 + y2) / 2.0 }
        var length: Double { hypot(x2 - x1, y2 - y1) }
        var angle: Double {
            var value = atan2(y2 - y1, x2 - x1) * 180.0 / .pi
            value = value.truncatingRemainder(dividingBy: 180.0)
            if value < 0 { value += 180.0 }
            return value
        }
    }

    /**
     Computes spatial S_lines from edge features and depth layering
     (Android `OpenCvLineDetector.scoreLines` parity).
     */
    static func scoreLines(
        refEdges: [Float],
        camEdges: [Float],
        size: Int,
        refDepth: [Float],
        camDepth: [Float],
        refDepthWidth: Int,
        refDepthHeight: Int,
        camDepthWidth: Int,
        camDepthHeight: Int
    ) -> Float {
        let refLines = extractLines(refEdges, width: size, height: size)
        let camLines = extractLines(camEdges, width: size, height: size)
        if refLines.isEmpty && camLines.isEmpty {
            return LMCompositionMath.emptyNeutralScore
        }

        let sOrientation = scoreOrientationSpatial(refLines, camLines, width: size, height: size)
        let sPosition = scoreLinePosition(refLines, camLines, width: size, height: size)
        let sLength = scoreLineLength(refLines, camLines, width: size, height: size)
        let sVanishing = scoreVanishingPoint(refLines, camLines, width: size, height: size)
        let sDepthLayering = LMDepthLayeringScorer.score(
            refDepth: refDepth,
            camDepth: camDepth,
            refWidth: refDepthWidth,
            refHeight: refDepthHeight,
            camWidth: camDepthWidth,
            camHeight: camDepthHeight
        )
        return (
            weightOrientationSpatial * sOrientation +
            weightLinePosition * sPosition +
            weightLineLength * sLength +
            weightVanishingPoint * sVanishing +
            weightDepthLayering * sDepthLayering
        ).clamped(to: 0...1)
    }

    // MARK: - Line extraction (OpenCV LSD substitute)

    /**
     Binarizes the edge map and extracts line segments via a pure-Swift probabilistic Hough
     plus connected-edge PCA approximator (replaces OpenCV LSD for pod-light builds).
     */
    private static func extractLines(_ edgeMap: [Float], width: Int, height: Int) -> [LineSegment] {
        guard edgeMap.count == width * height, width > 0, height > 0 else { return [] }
        var binary = [UInt8](repeating: 0, count: width * height)
        var edgePoints: [(Int, Int)] = []
        edgePoints.reserveCapacity(width * height / 8)
        for y in 0..<height {
            for x in 0..<width {
                if edgeMap[y * width + x] >= edgeBinarizeThreshold {
                    binary[y * width + x] = 255
                    edgePoints.append((x, y))
                }
            }
        }
        if edgePoints.isEmpty { return [] }

        var segments = extractConnectedEdgeLines(binary: binary, width: width, height: height)
        if segments.count < 4 {
            segments.append(contentsOf: probabilisticHoughLines(
                edgePoints: edgePoints,
                binary: binary,
                width: width,
                height: height
            ))
        }
        return deduplicateSegments(segments, minLength: 8)
    }

    /**
     Connected-component scan of edge pixels; fits a major-axis segment when the component
     is sufficiently linear.
     */
    private static func extractConnectedEdgeLines(
        binary: [UInt8],
        width: Int,
        height: Int
    ) -> [LineSegment] {
        var visited = [Bool](repeating: false, count: width * height)
        var segments: [LineSegment] = []
        let minComponentSize = 12
        let neighbors = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]

        for y in 0..<height {
            for x in 0..<width {
                let start = y * width + x
                if binary[start] == 0 || visited[start] { continue }

                var stack = [(x, y)]
                visited[start] = true
                var points: [(Int, Int)] = []
                points.reserveCapacity(64)

                while let (cx, cy) = stack.popLast() {
                    points.append((cx, cy))
                    for (dx, dy) in neighbors {
                        let nx = cx + dx
                        let ny = cy + dy
                        if nx < 0 || ny < 0 || nx >= width || ny >= height { continue }
                        let ni = ny * width + nx
                        if binary[ni] == 0 || visited[ni] { continue }
                        visited[ni] = true
                        stack.append((nx, ny))
                    }
                }

                guard points.count >= minComponentSize else { continue }
                if let segment = fitLineSegment(to: points) {
                    segments.append(segment)
                }
            }
        }
        return segments
    }

    /// PCA / endpoint projection of a point cloud into a single line segment.
    private static func fitLineSegment(to points: [(Int, Int)]) -> LineSegment? {
        guard points.count >= 2 else { return nil }
        var meanX = 0.0
        var meanY = 0.0
        for (x, y) in points {
            meanX += Double(x)
            meanY += Double(y)
        }
        meanX /= Double(points.count)
        meanY /= Double(points.count)

        var covXx = 0.0
        var covYy = 0.0
        var covXy = 0.0
        for (x, y) in points {
            let dx = Double(x) - meanX
            let dy = Double(y) - meanY
            covXx += dx * dx
            covYy += dy * dy
            covXy += dx * dy
        }
        let angle = 0.5 * atan2(2.0 * covXy, covXx - covYy)
        let dirX = cos(angle)
        let dirY = sin(angle)

        var minT = Double.greatestFiniteMagnitude
        var maxT = -Double.greatestFiniteMagnitude
        for (x, y) in points {
            let t = (Double(x) - meanX) * dirX + (Double(y) - meanY) * dirY
            minT = min(minT, t)
            maxT = max(maxT, t)
        }
        let length = maxT - minT
        guard length >= 8 else { return nil }

        // Reject highly isotropic blobs (prefer edge-like components).
        let eig1 = 0.5 * (covXx + covYy + hypot(covXx - covYy, 2 * covXy))
        let eig2 = 0.5 * (covXx + covYy - hypot(covXx - covYy, 2 * covXy))
        if eig1 > 1e-6, eig2 / eig1 > 0.45 { return nil }

        return LineSegment(
            x1: meanX + minT * dirX,
            y1: meanY + minT * dirY,
            x2: meanX + maxT * dirX,
            y2: meanY + maxT * dirY
        )
    }

    /**
     Probabilistic Hough line extraction over edge points (OpenCV `HoughLinesP` style).
     Used as a supplement when connected components yield few segments.
     */
    private static func probabilisticHoughLines(
        edgePoints: [(Int, Int)],
        binary: [UInt8],
        width: Int,
        height: Int
    ) -> [LineSegment] {
        guard edgePoints.count >= 20 else { return [] }
        let numAngles = 180
        let maxRho = Int(ceil(hypot(Double(width), Double(height))))
        let rhoBins = maxRho * 2 + 1
        var accumulator = [Int](repeating: 0, count: numAngles * rhoBins)
        let sampleCount = min(edgePoints.count, 2500)
        var generator = SeededGenerator(seed: UInt64(edgePoints.count * width + height))

        for _ in 0..<sampleCount {
            let point = edgePoints[Int.random(in: 0..<edgePoints.count, using: &generator)]
            for thetaIdx in 0..<numAngles {
                let theta = Double(thetaIdx) * .pi / 180.0
                let rho = Double(point.0) * cos(theta) + Double(point.1) * sin(theta)
                let rhoIdx = Int(rho.rounded()) + maxRho
                if rhoIdx < 0 || rhoIdx >= rhoBins { continue }
                accumulator[thetaIdx * rhoBins + rhoIdx] += 1
            }
        }

        let voteThreshold = max(18, edgePoints.count / 120)
        var candidates: [(theta: Double, rho: Double, votes: Int)] = []
        for thetaIdx in 0..<numAngles {
            for rhoIdx in 0..<rhoBins {
                let votes = accumulator[thetaIdx * rhoBins + rhoIdx]
                if votes < voteThreshold { continue }
                // Local peak check.
                var isPeak = true
                for dTheta in -1...1 where isPeak {
                    for dRho in -1...1 {
                        if dTheta == 0 && dRho == 0 { continue }
                        let nt = thetaIdx + dTheta
                        let nr = rhoIdx + dRho
                        if nt < 0 || nt >= numAngles || nr < 0 || nr >= rhoBins { continue }
                        if accumulator[nt * rhoBins + nr] > votes {
                            isPeak = false
                            break
                        }
                    }
                }
                if isPeak {
                    candidates.append((
                        theta: Double(thetaIdx) * .pi / 180.0,
                        rho: Double(rhoIdx - maxRho),
                        votes: votes
                    ))
                }
            }
        }
        candidates.sort { $0.votes > $1.votes }

        var segments: [LineSegment] = []
        let maxCandidates = min(candidates.count, 40)
        for i in 0..<maxCandidates {
            let c = candidates[i]
            if let segment = growSegmentAlongLine(
                theta: c.theta,
                rho: c.rho,
                binary: binary,
                width: width,
                height: height
            ) {
                segments.append(segment)
            }
        }
        return segments
    }

    /// Walks the binary edge map along a Hough line and returns the longest contiguous span.
    private static func growSegmentAlongLine(
        theta: Double,
        rho: Double,
        binary: [UInt8],
        width: Int,
        height: Int
    ) -> LineSegment? {
        let cosT = cos(theta)
        let sinT = sin(theta)
        let nx = -sinT
        let ny = cosT
        // Point on the line closest to origin.
        let px = rho * cosT
        let py = rho * sinT
        let span = hypot(Double(width), Double(height))
        var hits: [(Double, Double)] = []
        hits.reserveCapacity(Int(span))
        var t = -span
        while t <= span {
            let x = px + t * nx
            let y = py + t * ny
            let xi = Int(x.rounded())
            let yi = Int(y.rounded())
            if xi >= 0, yi >= 0, xi < width, yi < height, binary[yi * width + xi] != 0 {
                hits.append((x, y))
            }
            t += 1.0
        }
        guard hits.count >= 8 else { return nil }

        // Find longest nearly-contiguous run (allow small gaps).
        var bestStart = 0
        var bestEnd = 0
        var runStart = 0
        for i in 1..<hits.count {
            let gap = hypot(hits[i].0 - hits[i - 1].0, hits[i].1 - hits[i - 1].1)
            if gap > 6 {
                if i - 1 - runStart > bestEnd - bestStart {
                    bestStart = runStart
                    bestEnd = i - 1
                }
                runStart = i
            }
        }
        if hits.count - 1 - runStart > bestEnd - bestStart {
            bestStart = runStart
            bestEnd = hits.count - 1
        }
        let a = hits[bestStart]
        let b = hits[bestEnd]
        let length = hypot(b.0 - a.0, b.1 - a.1)
        guard length >= 8 else { return nil }
        return LineSegment(x1: a.0, y1: a.1, x2: b.0, y2: b.1)
    }

    private static func deduplicateSegments(_ segments: [LineSegment], minLength: Double) -> [LineSegment] {
        var result: [LineSegment] = []
        for segment in segments where segment.length >= minLength {
            let duplicate = result.contains { existing in
                abs(existing.angle - segment.angle) < 8 &&
                hypot(existing.centerX - segment.centerX, existing.centerY - segment.centerY) < 10 &&
                abs(existing.length - segment.length) < 12
            }
            if !duplicate {
                result.append(segment)
            }
        }
        return result
    }

    // MARK: - Scoring helpers (Android parity)

    private static func scoreOrientationSpatial(
        _ refLines: [LineSegment],
        _ camLines: [LineSegment],
        width: Int,
        height: Int
    ) -> Float {
        var weightedSum = 0.0
        var totalWeight = 0.0
        for cell in 0..<(spatialGrid * spatialGrid) {
            let refHist = orientationHistogramInCell(refLines, cell: cell, width: width, height: height)
            let camHist = orientationHistogramInCell(camLines, cell: cell, width: width, height: height)
            let refCount = refHist.reduce(0, +)
            let camCount = camHist.reduce(0, +)
            if refCount <= 0 && camCount <= 0 { continue }
            let weight = max(refCount, max(camCount, 1e-6))
            weightedSum += weight * Double(LMCompositionMath.bhattacharyyaCoefficient(refHist, camHist))
            totalWeight += weight
        }
        if totalWeight <= 0 {
            return (refLines.isEmpty && camLines.isEmpty) ? LMCompositionMath.emptyNeutralScore : 0
        }
        return Float(weightedSum / totalWeight).clamped(to: 0...1)
    }

    private static func scoreLinePosition(
        _ refLines: [LineSegment],
        _ camLines: [LineSegment],
        width: Int,
        height: Int
    ) -> Float {
        let refHist = centerHistogram(refLines, width: width, height: height)
        let camHist = centerHistogram(camLines, width: width, height: height)
        return histogramSimilarity(refHist, camHist, refEmpty: refLines.isEmpty, camEmpty: camLines.isEmpty)
    }

    private static func scoreLineLength(
        _ refLines: [LineSegment],
        _ camLines: [LineSegment],
        width: Int,
        height: Int
    ) -> Float {
        let diagonal = max(hypot(Double(width), Double(height)), 1)
        let refHist = lengthHistogram(refLines, diagonal: diagonal)
        let camHist = lengthHistogram(camLines, diagonal: diagonal)
        return histogramSimilarity(refHist, camHist, refEmpty: refLines.isEmpty, camEmpty: camLines.isEmpty)
    }

    private static func scoreVanishingPoint(
        _ refLines: [LineSegment],
        _ camLines: [LineSegment],
        width: Int,
        height: Int
    ) -> Float {
        let refVp = estimateVanishingPoint(refLines)
        let camVp = estimateVanishingPoint(camLines)
        if refVp == nil && camVp == nil {
            return LMCompositionMath.emptyNeutralScore
        }
        guard let ref = refVp, let cam = camVp else { return 0 }
        let refNormX = ref.0 / Float(width)
        let refNormY = ref.1 / Float(height)
        let camNormX = cam.0 / Float(width)
        let camNormY = cam.1 / Float(height)
        let distance = hypot(refNormX - camNormX, refNormY - camNormY)
        return (1 - distance / vpDistScale).clamped(to: 0...1)
    }

    private static func estimateVanishingPoint(_ lines: [LineSegment]) -> (Float, Float)? {
        let topLines = lines.sorted { $0.length > $1.length }.prefix(vpTopLines)
        guard topLines.count >= 2 else { return nil }

        var sumX = 0.0
        var sumY = 0.0
        var totalWeight = 0.0
        let list = Array(topLines)
        for i in 0..<list.count {
            for j in (i + 1)..<list.count {
                let lineA = list[i]
                let lineB = list[j]
                if angleDifference(lineA.angle, lineB.angle) < vpParallelAngleEps { continue }
                guard let intersection = lineIntersection(lineA, lineB) else { continue }
                let weight = lineA.length * lineB.length
                sumX += intersection.0 * weight
                sumY += intersection.1 * weight
                totalWeight += weight
            }
        }
        guard totalWeight > 0 else { return nil }
        return (Float(sumX / totalWeight), Float(sumY / totalWeight))
    }

    private static func lineIntersection(_ lineA: LineSegment, _ lineB: LineSegment) -> (Double, Double)? {
        let denominator = (lineA.x1 - lineA.x2) * (lineB.y1 - lineB.y2) -
            (lineA.y1 - lineA.y2) * (lineB.x1 - lineB.x2)
        if abs(denominator) < 1e-6 { return nil }
        let t = (
            (lineA.x1 - lineB.x1) * (lineB.y1 - lineB.y2) -
            (lineA.y1 - lineB.y1) * (lineB.x1 - lineB.x2)
        ) / denominator
        let x = lineA.x1 + t * (lineA.x2 - lineA.x1)
        let y = lineA.y1 + t * (lineA.y2 - lineA.y1)
        return (x, y)
    }

    private static func orientationHistogramInCell(
        _ lines: [LineSegment],
        cell: Int,
        width: Int,
        height: Int
    ) -> [Double] {
        var hist = [Double](repeating: 0, count: lineHistogramBins)
        for line in lines {
            if cellIndex(line.centerX, line.centerY, width: width, height: height) != cell { continue }
            let binIdx = min(
                Int(line.angle / (180.0 / Double(lineHistogramBins))),
                lineHistogramBins - 1
            )
            hist[binIdx] += 1
        }
        normalizeHistogram(&hist)
        return hist
    }

    private static func centerHistogram(_ lines: [LineSegment], width: Int, height: Int) -> [Double] {
        var hist = [Double](repeating: 0, count: spatialGrid * spatialGrid)
        for line in lines {
            hist[cellIndex(line.centerX, line.centerY, width: width, height: height)] += 1
        }
        normalizeHistogram(&hist)
        return hist
    }

    private static func lengthHistogram(_ lines: [LineSegment], diagonal: Double) -> [Double] {
        var hist = [Double](repeating: 0, count: lengthHistogramBins)
        for line in lines {
            let normalized = min(max(line.length / diagonal, 0), 1)
            let binIdx = min(Int(normalized * Double(lengthHistogramBins)), lengthHistogramBins - 1)
            hist[binIdx] += 1
        }
        normalizeHistogram(&hist)
        return hist
    }

    private static func cellIndex(_ centerX: Double, _ centerY: Double, width: Int, height: Int) -> Int {
        let col = max(0, min(Int((centerX / Double(width)) * Double(spatialGrid)), spatialGrid - 1))
        let row = max(0, min(Int((centerY / Double(height)) * Double(spatialGrid)), spatialGrid - 1))
        return row * spatialGrid + col
    }

    private static func normalizeHistogram(_ hist: inout [Double]) {
        let total = hist.reduce(0, +)
        if total > 0 {
            for i in hist.indices { hist[i] /= total }
        }
    }

    private static func histogramSimilarity(
        _ refHist: [Double],
        _ camHist: [Double],
        refEmpty: Bool,
        camEmpty: Bool
    ) -> Float {
        if refEmpty && camEmpty { return LMCompositionMath.emptyNeutralScore }
        if refEmpty || camEmpty { return 0 }
        return LMCompositionMath.bhattacharyyaCoefficient(refHist, camHist).clamped(to: 0...1)
    }

    private static func angleDifference(_ angleA: Double, _ angleB: Double) -> Double {
        let diff = abs(angleA - angleB).truncatingRemainder(dividingBy: 180.0)
        return min(diff, 180.0 - diff)
    }
}

/// Deterministic PRNG for Hough sampling (reproducible across runs).
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
