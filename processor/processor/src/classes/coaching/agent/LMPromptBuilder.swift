//
//  LMPromptBuilder.swift
//  processor
//
//  Planning-layer prompt construction and overall-score gating.
//

import Foundation

/// Planning-layer prompt construction and overall-score gating.
final class LMPromptBuilder: @unchecked Sendable {
    private let policy: LMCoachingPolicyConfig
    private let toolRouter: LMExecutionToolRouter
    private var consecutiveHighScoreRounds = 0

    init(policy: LMCoachingPolicyConfig, toolRouter: LMExecutionToolRouter? = nil) {
        self.policy = policy
        self.toolRouter = toolRouter ?? LMExecutionToolRouter(policy: policy)
    }

    func resetGate() {
        consecutiveHighScoreRounds = 0
    }

    /// Updates consecutive high-score counter; returns true when planning layer should finish without LLM.
    func shouldSkipLlm(scores: LMCompositionScore) -> Bool {
        if scores.overallScore >= policy.thresholdFinishOverall {
            consecutiveHighScoreRounds += 1
        } else {
            consecutiveHighScoreRounds = 0
        }
        return consecutiveHighScoreRounds >= policy.finishConsecutiveRounds
    }

    func gateFinishMessage() -> String {
        #"finish(message="构图相似度已达标")"#
    }

    func buildUserPrompt(
        scores: LMCompositionScore,
        session: LMCoachingSession,
        forbiddenActions: String
    ) -> String {
        var lines: [String] = []
        lines.append("图1为参考图（风格目标），图2为当前相机实景（Current View）。")
        lines.append("")
        lines.append("【当前客观相似度分数】（ref vs cam 相似度，指导靠拢方向）")
        lines.append("整体相似度: \(fmt(scores.overallScore))")
        lines.append("几何构图: \(fmt(scores.geometric))")
        lines.append("人景关系: \(humanSceneLabel(scores.humanScene))")
        lines.append("全局结构: \(fmt(scores.globalStructure))")
        lines.append("")
        lines.append("【详细子维度分数】（仅用于参考，不强制对应动作）")
        if let linesScore = scores.lines {
            lines.append("- 线条几何相似度: \(fmt(linesScore)) (0~1)")
        }
        if let rule = scores.rule {
            lines.append("- 构图布局相似度: \(fmt(rule)) (0~1)")
        }
        if scores.humanScene != nil {
            if let pos = scores.humanPos { lines.append("- 人物位置相似度: \(fmt(pos))") }
            if let scale = scores.humanScale { lines.append("- 人物尺度相似度: \(fmt(scale))") }
            if let depth = scores.humanDepth { lines.append("- 人物深度相似度: \(fmt(depth))") }
        }
        if let subjectCenter = scores.subjectCenter {
            lines.append("- 视觉重心相似度: \(fmt(subjectCenter))")
        }
        if let negativeSpace = scores.negativeSpace {
            lines.append("- 留白结构相似度: \(fmt(negativeSpace))")
        }
        lines.append("")
        lines.append("【历史动作与有效性趋势】")
        lines.append(session.formatHistory(rounds: policy.historyPromptRounds))
        lines.append("")
        lines.append("【80分神似收敛原则】")
        lines.append("- 目标是帮助用户达到约 80 分的「神似」，而非 100 分像素级复刻。")
        lines.append("- 若【历史动作与有效性趋势】显示分数停滞或下降，请停止在该维度微调，换维度或 finish。")
        lines.append("- 当人景关系、视觉重心等核心维度已达标且微调边际效益递减时，请果断 finish。")
        lines.append("")
        lines.append("【动态优先级映射规则】（请优先关注最低分维度对应的语义动作）")
        lines.append(buildPriorityMapping(scores: scores, session: session))
        lines.append("")
        if session.hasSkippedCategories() {
            lines.append("【用户已跳过的建议类型】")
            lines.append(session.formatSkippedCategories())
            lines.append("")
        }
        lines.append("【本轮禁止动作】")
        lines.append(forbiddenActions)
        lines.append("")
        lines.append(toolRouter.recommendSemanticHint(scores: scores))
        lines.append("端侧可能根据你的语义动作自动显示取景框或线稿，你仍只输出语义动作。")
        lines.append("")
        lines.append(contentsOf: outputLanguageConstraintLines())
        lines.append("")
        lines.append("【篇幅提醒】{think} 务必极简；气泡只显示 instruction 短句，勿输出长段说明。")
        lines.append("")
        lines.append("请简要分析两张图片的差异，输出下一步语义动作。")
        return lines.joined(separator: "\n")
    }

    /// Injects app-language output constraints for agent reasoning and instruction text.
    private func outputLanguageConstraintLines() -> [String] {
        LMLaunageManager.shared.currentLanguage.agentLLMOutputLanguageLines
    }

    func buildPriorityMapping(scores: LMCompositionScore, session: LMCoachingSession) -> String {
        var mapping: [String] = []

        if scores.globalStructure < policy.globalExtremeLow {
            mapping.append(
                "- 场景整体氛围/色调/风格相似度极低(\(fmt(scores.globalStructure)))：提示 Find_Scene，重新寻找匹配场景。"
            )
        }

        if scores.geometric < policy.dimLow {
            let lines = scores.lines ?? 0
            let rule = scores.rule ?? 0
            if lines < policy.subDimLow {
                mapping.append("- 线条走向/透视/几何结构分数过低(\(lines))：优先 Rotate_Camera 或 Move_Camera。")
            } else if rule < policy.subDimLow {
                mapping.append("- 构图布局分数过低(\(rule))：优先 Move_Camera 或 Zoom。")
            } else {
                mapping.append("- 几何构图整体偏低(\(fmt(scores.geometric)))：优先 Rotate_Camera / Move_Camera 或 Zoom。")
            }
        }

        let subjectCenter = scores.subjectCenter ?? 0
        let negativeSpace = scores.negativeSpace ?? 0
        if subjectCenter < policy.subDimLow || negativeSpace < policy.subDimLow {
            var hints: [String] = []
            if subjectCenter < policy.subDimLow {
                hints.append("视觉重心偏移(subjectCenter=\(subjectCenter))")
            }
            if negativeSpace < policy.subDimLow {
                hints.append("留白结构(negativeSpace=\(negativeSpace))")
            }
            mapping.append("- \(hints.joined(separator: "、"))：使用 Move_Camera 向留白缺失的方向平移。")
        }

        if let humanScene = scores.humanScene, humanScene < policy.dimLow {
            let pos = scores.humanPos ?? 0
            let scale = scores.humanScale ?? 0
            if scale < policy.subDimLow {
                mapping.append("- 人物占比相似度过低(\(scale))：**强制**优先 Zoom In/Out 或 Guide_Pose。")
            } else if pos < policy.subDimLow {
                mapping.append("- 人物画面位置相似度过低(\(pos))：优先 Move_Camera 或 Rotate_Camera。")
            } else {
                mapping.append("- 人景关系整体偏低(\(fmt(humanScene)))：优先调整人物位置或尺度。")
            }
        }

        let humanOk = (scores.humanScene ?? 1) >= policy.suggestFinishCoreDim
        if scores.overallScore >= policy.suggestFinishOverall &&
            scores.geometric >= policy.suggestFinishCoreDim &&
            humanOk {
            mapping.append("- 所有核心维度均已达标(≥\(policy.suggestFinishCoreDim))，建议输出 finish。")
        }

        if session.hasSkippedCategories() {
            mapping.append(
                "- 用户已跳过部分调整类型，当前整体相似度已达 \(fmt(scores.overallScore))。" +
                "请仅在未跳过类别中寻找明显短板；若无显著缺陷，应输出 finish。"
            )
        }

        return mapping.isEmpty
            ? "无特别优先级，请根据图片差异合理选择语义动作。"
            : mapping.joined(separator: "\n")
    }

    private func fmt(_ value: Float) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func humanSceneLabel(_ humanScene: Float?) -> String {
        guard let humanScene else { return "null" }
        return fmt(humanScene)
    }
}
