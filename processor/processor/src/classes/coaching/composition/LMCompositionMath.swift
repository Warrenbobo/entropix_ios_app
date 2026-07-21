//
//  LMCompositionMath.swift
//  processor
//
//  Shared math helpers for composition scorers.
//

import Foundation

/// Shared math helpers for composition scorers.
enum LMCompositionMath {
    private static let eps: Float = 1e-12
    private static let geometricGateFullTrust: Float = 0.55

    /// Neutral score when both sides lack measurable features.
    static let emptyNeutralScore: Float = 0.5

    /// Bhattacharyya coefficient for normalized histograms (Android `MathUtils` parity).
    static func bhattacharyyaCoefficient(_ h1: [Double], _ h2: [Double]) -> Float {
        precondition(h1.count == h2.count, "Histogram size mismatch")
        var sum: Double = 0
        for i in h1.indices {
            sum += sqrt(h1[i] * h2[i])
        }
        return Float(sum)
    }

    /// Cosine similarity for 1-D vectors; result clipped to [-1, 1].
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        precondition(a.count == b.count, "Vector size mismatch")
        var dot: Double = 0
        var normA: Double = 0
        var normB: Double = 0
        for i in a.indices {
            dot += Double(a[i] * b[i])
            normA += Double(a[i] * a[i])
            normB += Double(b[i] * b[i])
        }
        let denom = sqrt(normA) * sqrt(normB)
        if denom < Double(eps) { return 0 }
        return Float(dot / denom).clamped(to: -1...1)
    }

    /// L2-normalizes `vector` in place; no-op when norm is near zero.
    static func l2Normalize(_ vector: inout [Float]) {
        var norm: Double = 0
        for v in vector { norm += Double(v * v) }
        norm = sqrt(norm)
        if norm < Double(eps) { return }
        for i in vector.indices {
            vector[i] = Float(Double(vector[i]) / norm)
        }
    }

    /// Maps EVA02 raw cosine to displayed S_global using piecewise anchors from calibration.
    static func calibrateGlobalStructure(
        _ cosine: Float,
        calibration: LMGlobalStructureCalibration
    ) -> Float {
        let c = cosine.clamped(to: 0...1)
        let score: Float
        if c <= calibration.tNeg {
            score = (calibration.sNeg / calibration.tNeg) * c
        } else if c < calibration.tLo {
            let t = (c - calibration.tNeg) / (calibration.tLo - calibration.tNeg)
            score = lerp(calibration.sNeg, calibration.sLo, t)
        } else if c <= calibration.tHi {
            let t = ((c - calibration.tLo) / (calibration.tHi - calibration.tLo)).clamped(to: 0...1)
            let stretched = calibration.sameSceneGamma == 1
                ? t
                : pow(t, calibration.sameSceneGamma)
            score = lerp(calibration.sLo, calibration.sHi, stretched)
        } else {
            let rise = 1 - exp(-(c - calibration.tHi) / calibration.aboveHiTau)
            score = calibration.sHi + (1 - calibration.sHi) * rise
        }
        return score.clamped(to: 0...1)
    }

    /// Clips a raw similarity score to [0, 1] for UI display.
    static func clipForDisplay(_ score: Float) -> Float {
        score.clamped(to: 0...1)
    }

    /// Smooth gate in [0, 1] from global structure score.
    static func geometricGlobalGate(_ globalStructure: Float) -> Float {
        let g = globalStructure.clamped(to: 0...1)
        if g >= geometricGateFullTrust { return 1 }
        let t = (g / geometricGateFullTrust).clamped(to: 0...1)
        let smooth = smoothstep(t)
        return (smooth * smooth).clamped(to: 0...1)
    }

    /// Applies gate to a raw geometric sub-score.
    static func applyGeometricGlobalGate(_ score: Float, gate: Float) -> Float {
        (score * gate.clamped(to: 0...1)).clamped(to: 0...1)
    }

    private static func smoothstep(_ t: Float) -> Float {
        let x = t.clamped(to: 0...1)
        return x * x * (3 - 2 * x)
    }

    private static func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t.clamped(to: 0...1)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
