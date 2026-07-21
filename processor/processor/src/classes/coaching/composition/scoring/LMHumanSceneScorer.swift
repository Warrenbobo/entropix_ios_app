//
//  LMHumanSceneScorer.swift
//  processor
//
//  Human-scene similarity via person bbox and depth estimation.
//

import UIKit
import Vision

/// Normalized axis-aligned person detection (top-left origin, [0, 1]).
struct LMPersonDetection: Sendable {
    let x1: Float
    let y1: Float
    let x2: Float
    let y2: Float
    let confidence: Float

    var centerX: Float { (x1 + x2) * 0.5 }
    var centerY: Float { (y1 + y2) * 0.5 }
    var area: Float { max(0, x2 - x1) * max(0, y2 - y1) }

    init(x1: Float, y1: Float, x2: Float, y2: Float, confidence: Float = 1) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
        self.confidence = confidence
    }

    init(boundingBox: BoundingBox, confidence: Float = 1) {
        self.x1 = Float(boundingBox.x)
        self.y1 = Float(boundingBox.y)
        self.x2 = Float(boundingBox.x + boundingBox.width)
        self.y2 = Float(boundingBox.y + boundingBox.height)
        self.confidence = confidence
    }
}

/// Breakdown of human-scene sub-scores.
struct LMHumanSceneBreakdown: Sendable {
    let pos: Float
    let scale: Float
    let depth: Float
    let combined: Float
}

/// Human-scene similarity via Vision person rectangles and depth maps.
final class LMHumanSceneScorer: @unchecked Sendable {
    private let depthService: LMDepthEstimationService
    private static let depthScaleRatio: Float = 0.2
    private static let depthScaleEps: Float = 1e-6
    private let detectionLock = NSLock()

    init(depthService: LMDepthEstimationService = .shared) {
        self.depthService = depthService
    }

    /// Returns S_human_scene or nil when either image lacks a confident person detection.
    func score(ref: UIImage, cam: UIImage) -> Float? {
        scoreBreakdown(ref: ref, cam: cam)?.combined
    }

    func scoreBreakdown(ref: UIImage, cam: UIImage, tickContext: LMScoreTickContext? = nil) -> LMHumanSceneBreakdown? {
        let refPersons = detectPersons(in: ref)
        let refBest = Self.bestPerson(refPersons)
        let refDepth = refBest != nil ? depthService.predictDepthMap(for: ref) : nil
        return scoreBreakdown(
            refPersons: refPersons,
            refDepth: refDepth,
            cam: cam,
            tickContext: tickContext
        )
    }

    func scoreBreakdown(
        refPersons: [LMPersonDetection],
        refDepth: LMDepthMap?,
        cam: UIImage,
        tickContext: LMScoreTickContext? = nil
    ) -> LMHumanSceneBreakdown? {
        let camPersons = detectPersons(in: cam)
        guard let refBest = Self.bestPerson(refPersons),
              let camBest = Self.bestPerson(camPersons) else {
            return nil
        }

        let pos = Self.scoreHumanPos(ref: refBest, cam: camBest)
        let scale = Self.scoreHumanScale(
            refBest: refBest,
            camBest: camBest,
            refAreaRatio: Self.areaRatio(refPersons),
            camAreaRatio: Self.areaRatio(camPersons)
        )
        guard let refDepthMap = refDepth else { return nil }
        guard let camDepth = depthService.predictDepthMap(for: cam) else {
            return nil
        }
        tickContext?.cameraDepth = camDepth
        let sDepth = scoreHumanDepth(
            refDepth: refDepthMap,
            camDepth: camDepth,
            refBest: refBest,
            camBest: camBest
        )
        let combined = (pos + scale + sDepth) / 3
        return LMHumanSceneBreakdown(
            pos: pos,
            scale: scale,
            depth: sDepth,
            combined: LMCompositionMath.clipForDisplay(combined)
        )
    }

    /**
     Detects persons via `VNDetectHumanRectanglesRequest` (full body, then upper-body fallback),
     matching `LMPersonDetectionManager`. Bounding boxes are converted from Vision bottom-left
     origin to top-left origin used by scoring (`y' = 1 - y - height`).
     */
    func detectPersons(in image: UIImage) -> [LMPersonDetection] {
        detectionLock.lock()
        defer { detectionLock.unlock() }

        guard let cgImage = image.cgImage else { return [] }
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        if let fullBody = runHumanRectangleRequest(handler: handler, upperBodyOnly: false) {
            return fullBody
        }
        return runHumanRectangleRequest(handler: handler, upperBodyOnly: true) ?? []
    }

    /// Backward-compatible entry point for reference-side detection.
    func detectReferencePersons(in image: UIImage) -> [LMPersonDetection] {
        detectPersons(in: image)
    }

    /// Detects person boxes in the live camera frame.
    func detectCameraPersons(in image: UIImage) -> [LMPersonDetection] {
        detectPersons(in: image)
    }

    private func runHumanRectangleRequest(
        handler: VNImageRequestHandler,
        upperBodyOnly: Bool
    ) -> [LMPersonDetection]? {
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = upperBodyOnly
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let results = request.results, !results.isEmpty else { return nil }
        return results.map { observation in
            let bb = observation.boundingBox
            // Vision: origin bottom-left → scoring: origin top-left.
            let x1 = Float(bb.origin.x)
            let y1 = Float(1 - bb.origin.y - bb.height)
            let x2 = Float(bb.origin.x + bb.width)
            let y2 = Float(1 - bb.origin.y)
            return LMPersonDetection(
                x1: x1.clamped(to: 0...1),
                y1: y1.clamped(to: 0...1),
                x2: x2.clamped(to: 0...1),
                y2: y2.clamped(to: 0...1),
                confidence: observation.confidence
            )
        }
    }

    /// Scores depth using **model-resolution** maps; person boxes are normalized [0,1].
    private func scoreHumanDepth(
        refDepth: LMDepthMap,
        camDepth: LMDepthMap,
        refBest: LMPersonDetection,
        camBest: LMPersonDetection
    ) -> Float {
        let deltaRef = depthDelta(depth: refDepth, person: refBest)
        let deltaCam = depthDelta(depth: camDepth, person: camBest)
        let scaleRef = depthScale(refDepth.values)
        let scaleCam = depthScale(camDepth.values)
        let scale = max((scaleRef + scaleCam) * 0.5, Self.depthScaleEps)
        return 1 - min(abs(deltaRef - deltaCam) / scale, 1)
    }

    private func depthScale(_ depth: [Float]) -> Float {
        guard let minV = depth.min(), let maxV = depth.max() else { return Self.depthScaleEps }
        return Self.depthScaleRatio * (maxV - minV)
    }

    private func depthDelta(
        depth: LMDepthMap,
        person: LMPersonDetection
    ) -> Float {
        let width = depth.width
        let height = depth.height
        var x1 = Int(person.x1 * Float(width))
        var y1 = Int(person.y1 * Float(height))
        var x2 = max(x1 + 1, Int(person.x2 * Float(width)))
        var y2 = max(y1 + 1, Int(person.y2 * Float(height)))
        x1 = min(max(x1, 0), width)
        y1 = min(max(y1, 0), height)
        x2 = min(max(x2, 0), width)
        y2 = min(max(y2, 0), height)
        guard x2 > x1, y2 > y1 else { return 0 }
        var regionSum: Double = 0
        var count = 0
        for y in y1..<y2 {
            for x in x1..<x2 {
                regionSum += Double(depth.values[y * width + x])
                count += 1
            }
        }
        guard count > 0 else { return 0 }
        let totalSum = depth.values.reduce(0, +)
        let avg = totalSum / Float(depth.values.count)
        return Float(regionSum / Double(count)) - avg
    }

    /// Selects the highest-confidence person (Android `YoloOutputParser.bestPerson` parity).
    private static func bestPerson(_ persons: [LMPersonDetection]) -> LMPersonDetection? {
        persons.max(by: { $0.confidence < $1.confidence })
    }

    private static func areaRatio(_ persons: [LMPersonDetection]) -> Float {
        min(persons.reduce(0) { $0 + $1.area }, 1)
    }

    private static func scoreHumanPos(ref: LMPersonDetection, cam: LMPersonDetection) -> Float {
        let dTop = hypot(ref.centerX - cam.centerX, ref.y1 - cam.y1)
        let dCenter = hypot(ref.centerX - cam.centerX, ref.centerY - cam.centerY)
        let dBottom = hypot(ref.centerX - cam.centerX, ref.y2 - cam.y2)
        let dMean = (dTop + dCenter + dBottom) / 3
        let sB1 = linearDistanceScore(dMean, dMax: 0.38)
        let sTop = linearDistanceScore(dTop, dMax: 0.15)
        let sCenter = linearDistanceScore(dCenter, dMax: 0.12)
        let sBottom = linearDistanceScore(dBottom, dMax: 0.10)
        let sB2 = 0.25 * sTop + 0.35 * sCenter + 0.40 * sBottom
        return (0.4 * sB1 + 0.6 * sB2).clamped(to: 0...1)
    }

    private static func scoreHumanScale(
        refBest: LMPersonDetection,
        camBest: LMPersonDetection,
        refAreaRatio: Float,
        camAreaRatio: Float
    ) -> Float {
        let sArea = 1 - min(abs(refAreaRatio - camAreaRatio), 1)
        let refAR = aspectRatio(refBest)
        let camAR = aspectRatio(camBest)
        let sAR = 1 - min(abs(refAR - camAR) / 1.2, 1)
        let sHeight = 1 - min(abs(heightRatio(refBest) - heightRatio(camBest)), 1)
        let sIoU = boxIoU(refBest, camBest)
        let combined = 0.2 * sArea + 0.25 * sAR + 0.3 * sHeight + 0.25 * sIoU
        return combined.clamped(to: 0...1)
    }

    private static func linearDistanceScore(_ distance: Float, dMax: Float) -> Float {
        guard dMax > 0 else { return 0 }
        return (1 - distance / dMax).clamped(to: 0...1)
    }

    private static func aspectRatio(_ person: LMPersonDetection) -> Float {
        let width = max(person.x2 - person.x1, 1e-6)
        return max(person.y2 - person.y1, 0) / width
    }

    private static func heightRatio(_ person: LMPersonDetection) -> Float {
        max(person.y2 - person.y1, 0).clamped(to: 0...1)
    }

    private static func boxIoU(_ a: LMPersonDetection, _ b: LMPersonDetection) -> Float {
        let interX1 = max(a.x1, b.x1)
        let interY1 = max(a.y1, b.y1)
        let interX2 = min(a.x2, b.x2)
        let interY2 = min(a.y2, b.y2)
        let interW = max(interX2 - interX1, 0)
        let interH = max(interY2 - interY1, 0)
        let intersection = interW * interH
        let union = a.area + b.area - intersection
        guard union > 0 else { return 0 }
        return (intersection / union).clamped(to: 0...1)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
