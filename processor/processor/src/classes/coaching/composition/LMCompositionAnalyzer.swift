//
//  LMCompositionAnalyzer.swift
//  processor
//
//  Facade that runs all composition scorers and fuses results.
//

import UIKit

/// Cached reference-side features for faster live scoring.
private struct LMReferenceFeatures {
    let globalEmbedding: [Float]
    let persons: [LMPersonDetection]
    let depthMap: LMDepthMap?
    /// Includes PiDiNet edges / U2 mask when neural geometric path is active.
    let geometricReference: LMGeometricReferenceFeatures
}

/// Facade that runs all composition scorers and fuses results.
final class LMCompositionAnalyzer: @unchecked Sendable {
    static let shared = LMCompositionAnalyzer()

    private let globalScorer: LMGlobalStructureScorer
    private let geometricScorer = LMGeometricScorer()
    private let humanScorer = LMHumanSceneScorer()
    private let analyzeLock = NSLock()
    private var cachedReference: LMReferenceFeatures?

    private init() {
        let calibration = LMConfigRepository.shared.get().globalStructureCalibration
        globalScorer = LMGlobalStructureScorer(calibration: calibration)
    }

    /// Analyzes ref/cam pair; `elapsedMs` covers the full scoring pipeline.
    func analyze(ref: UIImage, cam: UIImage) -> LMCompositionScore {
        analyze(ref: ref, cam: cam, onModuleDone: nil)
    }

    /**
     Analyzes with optional per-module completion callbacks for Instruct HUD (§5).

     Modules still report done events so the HUD can advance with min dwell;
     GLOBAL / GEOMETRIC / HUMAN callbacks fire as each finishes (then FUSE).
     */
    func analyze(
        ref: UIImage,
        cam: UIImage,
        onModuleDone: ((LMInstructProgressPhase) -> Void)?
    ) -> LMCompositionScore {
        analyzeLock.lock()
        defer { analyzeLock.unlock() }

        return autoreleasepool {
            let tickContext = LMScoreTickContext()
            tickContext.debugLabel = "analyze"
            defer { tickContext.releaseEphemeral() }

            let totalStart = DispatchTime.now()
            let refFeatures = ensureReferenceFeatures(ref)
            let camFrame = cam

            let globalStart = DispatchTime.now()
            let global = globalScorer.score(refEmbedding: refFeatures.globalEmbedding, cam: camFrame)
            let globalMs = milliseconds(since: globalStart)
            onModuleDone?(.global)

            let geometricStart = DispatchTime.now()
            let geometric = geometricScorer.scoreBreakdown(
                reference: refFeatures.geometricReference,
                cam: camFrame,
                tickContext: tickContext
            )
            let geometricMs = milliseconds(since: geometricStart)
            onModuleDone?(.geometric)

            let humanStart = DispatchTime.now()
            let human = humanScorer.scoreBreakdown(
                refPersons: refFeatures.persons,
                refDepth: refFeatures.depthMap,
                cam: camFrame,
                tickContext: tickContext
            )
            let humanMs = milliseconds(since: humanStart)
            onModuleDone?(.human)

            let geometricGated = geometricScorer.applyGlobalGate(breakdown: geometric, globalStructure: global)
            let overall = LMScoreFusionEngine.fuse(
                globalStructure: global,
                geometric: geometricGated.combined,
                humanScene: human?.combined
            )
            onModuleDone?(.fuse)
            let totalMs = milliseconds(since: totalStart)

            LMLogger.log(
                "CompositionAnalyzer global=\(globalMs)ms geometric=\(geometricMs)ms " +
                "human=\(humanMs)ms total=\(totalMs)ms"
            )

            return LMCompositionScore(
                overallScore: overall,
                globalStructure: global,
                geometric: geometricGated.combined,
                humanScene: human?.combined,
                lines: geometricGated.lines,
                rule: geometricGated.rule,
                subjectCenter: geometricGated.subjectCenter,
                negativeSpace: geometricGated.negativeSpace,
                humanPos: human?.pos,
                humanScale: human?.scale,
                humanDepth: human?.depth,
                elapsedMs: totalMs
            )
        }
    }

    /// Clears cached reference features (e.g. when reference image is removed).
    func clearReferenceCache() {
        analyzeLock.lock()
        cachedReference = nil
        analyzeLock.unlock()
    }

    /// Pre-warms reference-side features for live scoring without analyzing the camera frame.
    func warmupReference(_ reference: UIImage) {
        analyzeLock.lock()
        defer { analyzeLock.unlock() }
        _ = ensureReferenceFeatures(reference)
    }

    private func ensureReferenceFeatures(_ ref: UIImage) -> LMReferenceFeatures {
        if let cachedReference { return cachedReference }
        let persons = humanScorer.detectReferencePersons(in: ref)
        let refBest = persons.max(by: { $0.confidence < $1.confidence })
        let depth = refBest != nil
            ? LMDepthEstimationService.shared.predictDepthMap(for: ref)
            : nil
        let features = LMReferenceFeatures(
            globalEmbedding: globalScorer.encodeEmbedding(ref),
            persons: persons,
            depthMap: depth,
            geometricReference: geometricScorer.buildReferenceFeatures(ref)
        )
        cachedReference = features
        return features
    }

    private func milliseconds(since start: DispatchTime) -> Int64 {
        Int64((DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
    }
}
