//
//  LMGeometricScorer.swift
//  processor
//
//  Geometric composition similarity via PiDiNet / U2-Netp (neural) or Vision contours (fallback).
//

import UIKit
import Vision

/// Breakdown of geometric sub-scores before fusion.
struct LMGeometricBreakdown: Sendable {
    let lines: Float
    let rule: Float
    let subjectCenter: Float
    let negativeSpace: Float
    let combined: Float
}

/**
 Cached geometric features for the reference image.

 Neural path stores PiDiNet edges, U2-Netp mask, and DepthAnything map; fallback path
 stores Vision-contour / layout heuristics.
 */
struct LMGeometricReferenceFeatures: Sendable {
    let contourDensity: Float
    let orientationHistogram: [Float]
    let subjectCenter: Float
    let negativeSpace: Float
    let combinedRule: Float
    /// PiDiNet edge map (`edgeSize * edgeSize`); empty when using Vision fallback.
    let edges: [Float]
    let edgeSize: Int
    /// U2-Netp saliency mask (`maskSize * maskSize`); empty when using Vision fallback.
    let mask: [Float]
    let maskSize: Int
    let depth: LMDepthMap?
    /// Whether this cache entry was built with neural geometric scorers.
    let isNeural: Bool

    /**
     Builds a Vision-contour / heuristic reference (fallback when neural models unavailable).
     */
    static func fallback(
        contourDensity: Float,
        orientationHistogram: [Float],
        subjectCenter: Float,
        negativeSpace: Float,
        combinedRule: Float
    ) -> LMGeometricReferenceFeatures {
        LMGeometricReferenceFeatures(
            contourDensity: contourDensity,
            orientationHistogram: orientationHistogram,
            subjectCenter: subjectCenter,
            negativeSpace: negativeSpace,
            combinedRule: combinedRule,
            edges: [],
            edgeSize: 0,
            mask: [],
            maskSize: 0,
            depth: nil,
            isNeural: false
        )
    }
}

/**
 Geometric scorer: PiDiNet + LSD math + U2 layout when `useNeuralGeometricScorers`,
 otherwise Vision contours / heuristics.
 */
final class LMGeometricScorer: @unchecked Sendable {
    private static let weightLines: Float = 0.6
    private static let weightRule: Float = 0.4
    private let contourLock = NSLock()
    private let depthService: LMDepthEstimationService
    private let pidinet: LMPidinetModelProvider
    private let u2netp: LMU2NetpModelProvider

    init(
        depthService: LMDepthEstimationService = .shared,
        pidinet: LMPidinetModelProvider = .shared,
        u2netp: LMU2NetpModelProvider = .shared
    ) {
        self.depthService = depthService
        self.pidinet = pidinet
        self.u2netp = u2netp
    }

    /// Whether neural geometric scoring should run (flag on and models present).
    var shouldUseNeuralPath: Bool {
        LMFeatureFlagsManager.useNeuralGeometricScorers
            && pidinet.isModelInBundle
            && u2netp.isModelInBundle
    }

    /// Computes geometric breakdown for ref/cam pair.
    func scoreBreakdown(ref: UIImage, cam: UIImage, tickContext: LMScoreTickContext? = nil) -> LMGeometricBreakdown {
        scoreBreakdown(reference: buildReferenceFeatures(ref), cam: cam, tickContext: tickContext)
    }

    /// Builds cacheable reference-side geometric features.
    func buildReferenceFeatures(_ ref: UIImage) -> LMGeometricReferenceFeatures {
        if shouldUseNeuralPath,
           let edges = pidinet.predictEdgeMap(for: ref),
           let mask = u2netp.predictSaliencyMask(for: ref) {
            let depth = depthService.predictDepthMap(for: ref)
            return LMGeometricReferenceFeatures(
                contourDensity: 0,
                orientationHistogram: [],
                subjectCenter: LMCompositionMath.emptyNeutralScore,
                negativeSpace: LMCompositionMath.emptyNeutralScore,
                combinedRule: LMCompositionMath.emptyNeutralScore,
                edges: edges,
                edgeSize: LMPidinetModelProvider.inputSize,
                mask: mask,
                maskSize: LMU2NetpModelProvider.inputSize,
                depth: depth,
                isNeural: true
            )
        }
        let layout = computeLayoutMetrics(ref)
        let contour = computeContourSignature(ref)
        return .fallback(
            contourDensity: contour.density,
            orientationHistogram: contour.orientationHistogram,
            subjectCenter: layout.subjectCenter,
            negativeSpace: layout.negativeSpace,
            combinedRule: layout.combinedRule
        )
    }

    /// Scores camera frame against precomputed reference geometric features.
    func scoreBreakdown(
        reference: LMGeometricReferenceFeatures,
        cam: UIImage,
        tickContext: LMScoreTickContext? = nil
    ) -> LMGeometricBreakdown {
        if reference.isNeural, shouldUseNeuralPath {
            return scoreNeuralBreakdown(reference: reference, cam: cam, tickContext: tickContext)
        }
        return scoreFallbackBreakdown(reference: reference, cam: cam)
    }

    /// Computes weighted S_geometric for ref/cam pair.
    func score(ref: UIImage, cam: UIImage) -> Float {
        scoreBreakdown(ref: ref, cam: cam).combined
    }

    /// Applies smooth S_global gate to raw geometric sub-scores before fusion/display.
    func applyGlobalGate(breakdown: LMGeometricBreakdown, globalStructure: Float) -> LMGeometricBreakdown {
        let gate = LMCompositionMath.geometricGlobalGate(globalStructure)
        let gatedLines = LMCompositionMath.applyGeometricGlobalGate(breakdown.lines, gate: gate)
        let gatedRule = LMCompositionMath.applyGeometricGlobalGate(breakdown.rule, gate: gate)
        let combined = LMCompositionMath.clipForDisplay(
            Self.weightLines * gatedLines + Self.weightRule * gatedRule
        )
        return LMGeometricBreakdown(
            lines: gatedLines,
            rule: gatedRule,
            subjectCenter: breakdown.subjectCenter,
            negativeSpace: breakdown.negativeSpace,
            combined: combined
        )
    }

    // MARK: - Neural path

    private func scoreNeuralBreakdown(
        reference: LMGeometricReferenceFeatures,
        cam: UIImage,
        tickContext: LMScoreTickContext?
    ) -> LMGeometricBreakdown {
        guard let camEdges = pidinet.predictEdgeMap(for: cam),
              let camMask = u2netp.predictSaliencyMask(for: cam) else {
            return scoreFallbackBreakdown(reference: reference, cam: cam)
        }
        tickContext?.cameraEdgeMap = camEdges
        tickContext?.cameraSaliencyMask = camMask

        let camDepth = depthService.predictDepthMap(for: cam)
        tickContext?.cameraDepth = camDepth

        let edgeSize = reference.edgeSize > 0 ? reference.edgeSize : LMPidinetModelProvider.inputSize
        let maskSize = reference.maskSize > 0 ? reference.maskSize : LMU2NetpModelProvider.inputSize

        let refDepthValues: [Float]
        let refDepthW: Int
        let refDepthH: Int
        if let refDepth = reference.depth, !refDepth.values.isEmpty {
            refDepthValues = refDepth.values
            refDepthW = refDepth.width
            refDepthH = refDepth.height
        } else {
            // Flat map → DepthLayeringScorer flat-scene path (~0.80).
            refDepthValues = [Float](repeating: 0.5, count: 4)
            refDepthW = 2
            refDepthH = 2
        }

        let camDepthValues: [Float]
        let camDepthW: Int
        let camDepthH: Int
        if let camDepth, !camDepth.values.isEmpty {
            camDepthValues = camDepth.values
            camDepthW = camDepth.width
            camDepthH = camDepth.height
        } else {
            camDepthValues = [Float](repeating: 0.5, count: 4)
            camDepthW = 2
            camDepthH = 2
        }

        let sLines = LMOpenCvLineDetector.scoreLines(
            refEdges: reference.edges,
            camEdges: camEdges,
            size: edgeSize,
            refDepth: refDepthValues,
            camDepth: camDepthValues,
            refDepthWidth: refDepthW,
            refDepthHeight: refDepthH,
            camDepthWidth: camDepthW,
            camDepthHeight: camDepthH
        )
        let layout = LMSubjectMaskAnalyzer.scoreComponents(
            refMask: reference.mask,
            camMask: camMask,
            width: maskSize,
            height: maskSize
        )
        let raw = Self.weightLines * sLines + Self.weightRule * layout.combinedRule
        return LMGeometricBreakdown(
            lines: sLines,
            rule: layout.combinedRule,
            subjectCenter: layout.subjectCenter,
            negativeSpace: layout.negativeSpace,
            combined: LMCompositionMath.clipForDisplay(raw)
        )
    }

    // MARK: - Vision fallback

    private struct ContourSignature {
        let density: Float
        let orientationHistogram: [Float]
    }

    private struct LayoutMetrics {
        let subjectCenter: Float
        let negativeSpace: Float
        let combinedRule: Float
    }

    private func scoreFallbackBreakdown(
        reference: LMGeometricReferenceFeatures,
        cam: UIImage
    ) -> LMGeometricBreakdown {
        let refContour = ContourSignature(
            density: reference.contourDensity,
            orientationHistogram: reference.orientationHistogram.isEmpty
                ? [Float](repeating: 0, count: 8)
                : reference.orientationHistogram
        )
        let refLayout = LayoutMetrics(
            subjectCenter: reference.subjectCenter,
            negativeSpace: reference.negativeSpace,
            combinedRule: reference.combinedRule
        )
        let camEdges = computeContourSignature(cam)
        let camLayout = computeLayoutMetrics(cam)

        let sLines = contourSimilarity(refContour, camEdges)
        let layout = layoutSimilarity(refLayout, camLayout)
        let raw = Self.weightLines * sLines + Self.weightRule * layout.combinedRule
        return LMGeometricBreakdown(
            lines: sLines,
            rule: layout.combinedRule,
            subjectCenter: layout.subjectCenter,
            negativeSpace: layout.negativeSpace,
            combined: LMCompositionMath.clipForDisplay(raw)
        )
    }

    private func computeContourSignature(_ image: UIImage) -> ContourSignature {
        contourLock.lock()
        defer { contourLock.unlock() }

        guard let cgImage = image.cgImage else {
            return ContourSignature(density: 0, orientationHistogram: [Float](repeating: 0, count: 8))
        }

        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.5
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 256

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])

        guard let observation = request.results?.first as? VNContoursObservation else {
            return ContourSignature(density: 0, orientationHistogram: [Float](repeating: 0, count: 8))
        }

        let contourCount = observation.contourCount
        let density = Float(min(contourCount, 200)) / 200.0
        var histogram = [Float](repeating: 0, count: 8)
        for i in 0..<contourCount {
            guard let contour = try? observation.contour(at: i) else { continue }
            let points = contour.normalizedPoints
            guard points.count >= 2 else { continue }
            let p0 = points[0]
            let p1 = points[1]
            let angle = atan2(Float(p1.y - p0.y), Float(p1.x - p0.x))
            let bucket = Int(((angle + .pi) / (2 * .pi)) * 8) % 8
            histogram[bucket] += 1
        }
        let total = histogram.reduce(0, +)
        if total > 0 {
            for i in histogram.indices { histogram[i] /= total }
        }
        return ContourSignature(density: density, orientationHistogram: histogram)
    }

    private func contourSimilarity(_ a: ContourSignature, _ b: ContourSignature) -> Float {
        let densitySim = 1 - abs(a.density - b.density)
        var histDot: Float = 0
        let count = min(a.orientationHistogram.count, b.orientationHistogram.count)
        for i in 0..<count {
            histDot += a.orientationHistogram[i] * b.orientationHistogram[i]
        }
        return LMCompositionMath.clipForDisplay(0.4 * densitySim + 0.6 * histDot)
    }

    private func computeLayoutMetrics(_ image: UIImage) -> LayoutMetrics {
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            return LayoutMetrics(subjectCenter: 0.5, negativeSpace: 0.5, combinedRule: 0.5)
        }
        let centerX: Float = 0.5
        let centerY: Float = 0.5
        let thirdsX: Float = 1.0 / 3.0
        let thirdsScore = 1 - min(abs(centerX - thirdsX), abs(centerX - 2 * thirdsX)) / 0.5
        let centerScore = 1 - hypot(centerX - 0.5, centerY - 0.5)
        let negativeSpace = estimateNegativeSpace(image)
        let combinedRule = (thirdsScore * 0.5 + centerScore * 0.5)
        return LayoutMetrics(
            subjectCenter: LMCompositionMath.clipForDisplay(centerScore),
            negativeSpace: negativeSpace,
            combinedRule: LMCompositionMath.clipForDisplay(combinedRule)
        )
    }

    private func layoutSimilarity(_ ref: LayoutMetrics, _ cam: LayoutMetrics) -> LayoutMetrics {
        let subjectCenter = 1 - abs(ref.subjectCenter - cam.subjectCenter)
        let negativeSpace = 1 - abs(ref.negativeSpace - cam.negativeSpace)
        let combinedRule = 1 - abs(ref.combinedRule - cam.combinedRule)
        return LayoutMetrics(
            subjectCenter: LMCompositionMath.clipForDisplay(subjectCenter),
            negativeSpace: LMCompositionMath.clipForDisplay(negativeSpace),
            combinedRule: LMCompositionMath.clipForDisplay(combinedRule)
        )
    }

    private func estimateNegativeSpace(_ image: UIImage) -> Float {
        guard let cgImage = image.cgImage else { return 0.5 }
        let width = min(cgImage.width, 64)
        let height = min(cgImage.height, 64)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0.5 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return 0.5 }
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        var brightCount = 0
        let total = width * height
        for i in 0..<total {
            let offset = i * 4
            let r = Float(buffer[offset])
            let g = Float(buffer[offset + 1])
            let b = Float(buffer[offset + 2])
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            if luminance > 200 { brightCount += 1 }
        }
        return Float(brightCount) / Float(total)
    }
}
