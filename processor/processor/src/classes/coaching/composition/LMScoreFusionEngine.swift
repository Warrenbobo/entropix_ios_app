//
//  LMScoreFusionEngine.swift
//  processor
//
//  Weighted fusion aligned with docs/ai-coaching-agent-demo-imgAnalyze.md §3.
//

import Foundation

/// Weighted fusion of composition sub-dimension scores.
enum LMScoreFusionEngine {
    private static let weightGlobal: Float = 0.175
    private static let weightGeometric: Float = 0.525
    private static let weightHumanScene: Float = 0.30

    /// Fuses sub-dimension scores; redistributes human weight when `humanScene` is nil.
    static func fuse(
        globalStructure: Float,
        geometric: Float,
        humanScene: Float?
    ) -> Float {
        let overall: Float
        if humanScene == nil {
            let factor = 1.0 / (1.0 - weightHumanScene)
            let wGlobal = weightGlobal * factor
            let wGeometric = weightGeometric * factor
            overall = wGlobal * globalStructure + wGeometric * geometric
        } else {
            overall = weightGlobal * globalStructure
                + weightGeometric * geometric
                + weightHumanScene * (humanScene ?? 0)
        }
        return min(max(overall, 0), 1)
    }
}
