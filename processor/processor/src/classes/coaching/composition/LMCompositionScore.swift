//
//  LMCompositionScore.swift
//  processor
//
//  Fused composition similarity result for one ref/cam pair.
//

import Foundation

/// Fused composition similarity result for one ref/cam pair.
struct LMCompositionScore: Equatable, Sendable {
    let overallScore: Float
    let globalStructure: Float
    let geometric: Float
    let humanScene: Float?
    let lines: Float?
    let rule: Float?
    let subjectCenter: Float?
    let negativeSpace: Float?
    let humanPos: Float?
    let humanScale: Float?
    let humanDepth: Float?
    let elapsedMs: Int64
}

/// Timestamped composition score from the live score loop, eligible for instruct-round reuse.
struct LMCachedCompositionScoreSnapshot: Sendable {
    let score: LMCompositionScore
    let analyzedAtMs: Int64
}
