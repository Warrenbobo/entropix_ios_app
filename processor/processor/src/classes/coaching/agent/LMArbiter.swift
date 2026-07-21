//
//  LMArbiter.swift
//  processor
//
//  Post-LLM decision layer: finish overrides, oscillation detection, skip filtering.
//

import Foundation

/// Post-LLM decision layer: finish overrides, oscillation detection, skip filtering.
final class LMArbiter: @unchecked Sendable {
    private let policy: LMCoachingPolicyConfig

    init(policy: LMCoachingPolicyConfig) {
        self.policy = policy
    }

    /// Post-processes LLM output into a final semantic action with optional finish cause.
    func arbitrate(
        llmOutput: String,
        currentScores: LMCompositionScore,
        history: [LMRoundRecord],
        session: LMCoachingSession? = nil
    ) -> LMArbitrateResult {
        var action = LMActionClassifier.stripShowActions(LMActionExtractor.extractAction(llmOutput))

        if let session, policy.skipEnabled, isSkippedAction(action, session: session) {
            if policy.skipArbiterFallback == "finish" {
                return LMArbitrateResult(
                    action: #"finish(message="用户已跳过此类调整，当前构图可接受")"#,
                    finishCause: .userSkippedFallback
                )
            }
            let fallback = findFallbackAction(scores: currentScores)
            return LMArbitrateResult(action: fallback, finishCause: finishCauseFromAction(fallback))
        }

        if currentScores.geometric >= policy.thresholdCoreDim &&
            (currentScores.humanScene ?? 1) >= policy.thresholdCoreDim &&
            currentScores.globalStructure >= policy.thresholdCoreDim {
            return LMArbitrateResult(
                action: #"finish(message="核心构图维度均已达标")"#,
                finishCause: .coreDimsMet
            )
        }

        if history.count >= 2,
           LMOscillationDetector.isOscillating(Array(history.suffix(2)), policy: policy) {
            return LMArbitrateResult(
                action: #"finish(message="检测到调整震荡，停止微调")"#,
                finishCause: .oscillation
            )
        }

        if history.count >= policy.oscillationWindow {
            let recent = Array(history.suffix(policy.oscillationWindow))
            if hasDirectionOscillation(recent) {
                return LMArbitrateResult(
                    action: #"finish(message="检测到调整震荡，停止微调")"#,
                    finishCause: .oscillation
                )
            }
        }

        if action.contains("Guide_Pose"), currentScores.humanScene == nil {
            return LMArbitrateResult(
                action: #"do(action="Zoom", direction="Out", instruction="拉远镜头，重新确认构图")"#,
                finishCause: nil
            )
        }

        if action.contains("Adjust_Exposure"),
           currentScores.overallScore < policy.deferExposureBelowOverall {
            return LMArbitrateResult(
                action: #"do(action="Zoom", direction="Out", instruction="先调整构图，拉远镜头确认整体")"#,
                finishCause: nil
            )
        }

        if currentScores.overallScore > policy.forceFinishAboveOverall &&
            (action.contains("Guide_Pose") || action.contains("Rotate_Camera")) {
            return LMArbitrateResult(
                action: #"finish(message="整体风格已匹配，无需进一步调整")"#,
                finishCause: .forceStyleMatch
            )
        }

        let resolved = action.isEmpty
            ? #"do(action="Zoom", direction="Out", instruction="拉远镜头，重新确认构图")"#
            : action
        return LMArbitrateResult(action: resolved, finishCause: finishCauseFromAction(resolved))
    }

    private func finishCauseFromAction(_ action: String) -> LMFinishCause? {
        action.contains("finish") ? .llmFinish : nil
    }

    private func isSkippedAction(_ action: String, session: LMCoachingSession) -> Bool {
        session.isSkipped(LMActionClassifier.categoryOf(action))
    }

    private func findFallbackAction(scores: LMCompositionScore) -> String {
        if scores.overallScore >= policy.suggestFinishOverall {
            return #"finish(message="构图已足够接近参考图")"#
        }
        return #"do(action="Zoom", direction="Out", instruction="拉远镜头，重新确认构图")"#
    }

    private func hasDirectionOscillation(_ records: [LMRoundRecord]) -> Bool {
        guard records.count >= 2 else { return false }
        for i in 1..<records.count {
            if LMOscillationDetector.isOpposite(records[i - 1].action, records[i].action) {
                return true
            }
        }
        return false
    }
}
