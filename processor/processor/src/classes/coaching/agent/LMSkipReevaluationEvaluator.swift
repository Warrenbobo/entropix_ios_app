//
//  LMSkipReevaluationEvaluator.swift
//  processor
//

import Foundation

/// Client-side satisfaction check after user skips a suggestion category.
enum LMSkipReevaluationResult: Sendable {
    case finish(message: String, cause: LMFinishCause)
    case continuePlanning
}

/// Avoids an LLM round-trip when the current frame is already good enough per user preference.
struct LMSkipReevaluationEvaluator: Sendable {
    let policy: LMCoachingPolicyConfig

    /**
     * - Parameters:
     *   - scores: Latest score from the composition score loop at Skip tap time.
     */
    func evaluate(
        scores: LMCompositionScore,
        skippedCategory: LMSuggestionCategory
    ) -> LMSkipReevaluationResult {
        _ = skippedCategory
        if !policy.skipReevaluationEnabled {
            return .continuePlanning
        }
        if scores.overallScore < policy.skipFinishOverall {
            return .continuePlanning
        }
        if !coreDimsSatisfiedAfterSkip(scores) {
            return .continuePlanning
        }
        return .finish(
            message: "已根据您的偏好锁定当前构图，风格已匹配",
            cause: .skipPreference
        )
    }

    private func coreDimsSatisfiedAfterSkip(_ scores: LMCompositionScore) -> Bool {
        let humanOk = scores.humanScene.map { $0 >= policy.skipFinishCoreDim } ?? true
        let centerOk = scores.subjectCenter.map { $0 >= policy.skipFinishSubjectCenter } ?? true
        return humanOk && centerOk
    }
}
