//
//  LMExecutionToolRouter.swift
//  processor
//
//  Maps arbitrated semantic LLM action + scores to final UI execution plan.
//

import CoreGraphics
import Foundation

/// Maps arbitrated semantic LLM action + scores + system preconditions to final UI execution plan.
final class LMExecutionToolRouter: @unchecked Sendable {
    private let policy: LMCoachingPolicyConfig

    init(policy: LMCoachingPolicyConfig) {
        self.policy = policy
    }

    /// For prompt builder: suggest semantic actions only (no Show_* in prompt).
    func recommendSemanticHint(scores: LMCompositionScore) -> String {
        var hints: [String] = []
        if scores.globalStructure < policy.globalExtremeLow {
            hints.append("场景氛围极低，建议 Find_Scene。")
        }
        if let lines = scores.lines, lines < policy.executionToolsPreferBoxWhenLinesBelow {
            hints.append("线条/透视偏低，语义动作优先 Rotate_Camera / Move_Camera（端侧可能升级为取景框）。")
        }
        if let scale = scores.humanScale, scale < policy.executionToolsPreferLineArtWhenScaleBelow {
            hints.append("人物尺度偏低，语义动作优先 Zoom / Guide_Pose（端侧可能升级为线稿）。")
        }
        return hints.isEmpty
            ? "根据最低分维度选择语义动作；端侧可能自动显示取景框或线稿。"
            : hints.joined(separator: "\n")
    }

    /// Post-arbiter: resolve final UI + tool from semantic action.
    func resolveExecution(
        semanticAction: String,
        scores: LMCompositionScore,
        session: LMCoachingSession,
        systemState: LMExecutionSystemState
    ) -> LMFinalExecutionPlan {
        let normalized = LMActionClassifier.stripShowActions(semanticAction)
        let instruction = formatInstruction(normalized)
        let baseText = instruction ?? LMActionExtractor.extractDisplayText(normalized)

        if normalized.contains("finish") {
            return LMFinalExecutionPlan(
                displayText: baseText,
                executionTool: .none,
                toolInstruction: nil,
                semanticAction: normalized
            )
        }

        let category = LMActionClassifier.categoryOf(normalized)
        if session.isSkipped(category) {
            return LMFinalExecutionPlan(
                displayText: baseText,
                executionTool: .none,
                toolInstruction: nil,
                semanticAction: normalized
            )
        }

        let tool = resolveTool(action: normalized, scores: scores, session: session, systemState: systemState)
        let cameraText = LMText.camera
        let displayText: String
        switch tool {
        case .box:
            displayText = cameraText.agentBoxGuidancePrefix + baseText
        case .lineArt:
            displayText = cameraText.agentLineArtGuidancePrefix + baseText
        case .none:
            displayText = baseText
        }
        return LMFinalExecutionPlan(
            displayText: displayText,
            executionTool: tool,
            toolInstruction: extractInstruction(normalized),
            semanticAction: normalized
        )
    }

    private func resolveTool(
        action: String,
        scores: LMCompositionScore,
        session: LMCoachingSession,
        systemState: LMExecutionSystemState
    ) -> LMExecutionTool {
        if action.contains("finish") || action.contains("Find_Scene") || action.contains("Adjust_Exposure") {
            return .none
        }

        let positioning = action.contains("Move_Camera") || action.contains("Rotate_Camera")
        let scalePose = action.contains("Zoom") || action.contains("Guide_Pose")

        if positioning, !session.isSkipped(.positioning),
           systemState.referenceBbox != nil, scoresSupportBox(scores) {
            return .box
        }

        if scalePose, !session.isSkipped(.scalePose),
           systemState.lineArtReady, scoresSupportLineArt(action: action, scores: scores) {
            return .lineArt
        }

        return .none
    }

    private func scoresSupportBox(_ scores: LMCompositionScore) -> Bool {
        if scores.globalStructure < policy.globalExtremeLow { return false }
        let lines = scores.lines ?? 1
        let humanPos = scores.humanPos ?? 1
        let subjectCenter = scores.subjectCenter ?? 1
        let negativeSpace = scores.negativeSpace ?? 1
        return scores.geometric < policy.dimLow ||
            lines < policy.subDimLow ||
            humanPos < policy.subDimLow ||
            subjectCenter < policy.subDimLow ||
            negativeSpace < policy.subDimLow
    }

    private func scoresSupportLineArt(action: String, scores: LMCompositionScore) -> Bool {
        if action.contains("Guide_Pose"), scores.humanScene == nil { return false }
        let humanScale = scores.humanScale ?? 1
        let humanDepth = scores.humanDepth ?? 1
        let rule = scores.rule ?? 1
        return action.contains("Guide_Pose") ||
            humanScale < policy.subDimLow ||
            humanDepth < policy.subDimLow ||
            (rule < policy.subDimLow && humanScale < policy.subDimLow)
    }

    private func extractInstruction(_ action: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"instruction="([^"]*)""#),
              let match = regex.firstMatch(in: action, range: NSRange(action.startIndex..., in: action)),
              let range = Range(match.range(at: 1), in: action) else {
            return nil
        }
        let text = String(action[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func formatInstruction(_ action: String) -> String? {
        extractInstruction(action)
    }
}
