//
//  LMCoachingSupport.swift
//  processor
//
//  Shared agent coaching types and helpers.
//

import Foundation

/// Runtime state for one agent coaching window (per reference image).
enum LMAgentState: Sendable {
    case idle
    case running
    case finished
    case error
}

/// Why the agent session entered the finished state.
enum LMFinishCause: Sendable {
    case scoreImplied
    case llmFinish
    case oscillation
    case coreDimsMet
    case skipPreference
    case forceStyleMatch
    case userSkippedFallback
}

/// User-facing finish messages mapped from finish cause.
enum LMFinishCopy {
    static func display(_ cause: LMFinishCause) -> String {
        let text = LMText.camera
        switch cause {
        case .oscillation: return text.finishMessageOscillation
        case .scoreImplied: return text.finishMessageScoreImplied
        case .llmFinish: return text.finishMessageLlmFinish
        case .coreDimsMet: return text.finishMessageCoreDimsMet
        case .skipPreference: return text.finishMessageSkipPreference
        case .forceStyleMatch: return text.finishMessageForceStyleMatch
        case .userSkippedFallback: return text.finishMessageUserSkippedFallback
        }
    }
}

/// Maps arbitrated semantic actions to skip categories.
enum LMSuggestionCategory: String, Sendable, Hashable {
    case positioning
    case scalePose
    case exposure
    case scene

    var displayName: String {
        let text = LMText.camera
        switch self {
        case .positioning: return text.skipCategoryPositioning
        case .scalePose: return text.skipCategoryScalePose
        case .exposure: return text.skipCategoryExposure
        case .scene: return text.skipCategoryScene
        }
    }
}

/// One round of agentic coaching for session memory and oscillation detection.
struct LMRoundRecord: Sendable {
    let round: Int
    let action: String
    let scoreBefore: Float
    let scoreAfter: Float
    let timestamp: Int64
    let isSkipped: Bool
}

/// Post-arbitration semantic action with optional finish cause metadata.
struct LMArbitrateResult: Sendable {
    let action: String
    let finishCause: LMFinishCause?
}

/// Execution tool surfaced to the camera UI.
enum LMExecutionTool: Sendable {
    case none
    case box
    case lineArt
}

/// System preconditions for execution tool upgrade.
struct LMExecutionSystemState: Sendable {
    let referenceBbox: CGRect?
    /// `true` when LineArt callout is **eligible** (reference person mask present).
    /// The LineArt UIImage itself is generated lazily on first `.lineArt` callout.
    let lineArtReady: Bool
}

/// Final plan applied by the action executor.
struct LMFinalExecutionPlan: Sendable {
    let displayText: String
    let executionTool: LMExecutionTool
    let toolInstruction: String?
    let semanticAction: String
}

/// In-memory session memory for recent coaching rounds and user skip preferences.
final class LMCoachingSession: @unchecked Sendable {
    private var deque: [LMRoundRecord] = []
    private var skippedCategories = Set<LMSuggestionCategory>()
    private let maxSize: Int
    private let policy: LMCoachingPolicyConfig

    init(maxSize: Int, policy: LMCoachingPolicyConfig) {
        self.maxSize = maxSize
        self.policy = policy
    }

    func reset() {
        deque.removeAll()
        skippedCategories.removeAll()
    }

    func push(_ record: LMRoundRecord) {
        if deque.count >= maxSize {
            deque.removeFirst()
        }
        deque.append(record)
    }

    func getAll() -> [LMRoundRecord] { deque }

    func skipCategory(_ category: LMSuggestionCategory) {
        skippedCategories.insert(category)
    }

    func isSkipped(_ category: LMSuggestionCategory) -> Bool {
        skippedCategories.contains(category)
    }

    func hasSkippedCategories() -> Bool { !skippedCategories.isEmpty }

    func formatSkippedCategories() -> String {
        if skippedCategories.isEmpty { return "（无跳过类别）" }
        return skippedCategories.map { category -> String in
            switch category {
            case .positioning: return "Move_Camera, Rotate_Camera"
            case .scalePose: return "Zoom, Guide_Pose"
            case .exposure: return "Adjust_Exposure"
            case .scene: return "Find_Scene"
            }
        }.joined(separator: "、")
    }

    func formatHistory(rounds: Int) -> String {
        let items = Array(deque.suffix(rounds))
        if items.isEmpty {
            return "- 首轮指导，无历史动作。"
        }
        var lines = ["- 【历史动作与有效性趋势】："]
        for record in items {
            if record.round == 1 && record.scoreBefore <= 0 {
                lines.append(
                    "  轮次 \(record.round): \(LMActionClassifier.summarizeAction(record.action)) | " +
                    "基线分 \(fmt(record.scoreAfter))"
                )
                continue
            }
            let delta = record.scoreAfter - record.scoreBefore
            let trend = classifyTrend(delta)
            let skipTag = record.isSkipped ? " [用户已跳过此类]" : ""
            lines.append(
                "  轮次 \(record.round): \(LMActionClassifier.summarizeAction(record.action)) | " +
                "\(fmt(record.scoreBefore)) → \(fmt(record.scoreAfter)) \(trend)\(skipTag)"
            )
        }
        if LMOscillationDetector.isOscillating(Array(deque.suffix(2)), policy: policy) {
            lines.append("- ⚠️ 【震荡预警】：近两轮方向相反且分数无明显提升，请优先考虑 finish。")
        }
        if !skippedCategories.isEmpty {
            let names = skippedCategories.map(\.displayName).joined(separator: "、")
            lines.append("- 【用户偏好约束】：已跳过 \(names)，请勿再次推荐。")
        }
        return lines.joined(separator: "\n")
    }

    private func classifyTrend(_ delta: Float) -> String {
        if delta > policy.historyEffectiveUp {
            return "✅ 有效提升 (+\(fmt(delta)))"
        }
        if delta < policy.historyEffectiveDown {
            return "❌ 分数下降 (\(fmt(delta)))，方向可能错误"
        }
        return "⚠️ 分数停滞"
    }

    private func fmt(_ value: Float) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

/// Extracts user-facing instruction text from LLM `<answer>` output.
enum LMActionExtractor {
    private static let answerRegex = try! NSRegularExpression(
        pattern: "<answer>(.*?)</answer>",
        options: [.dotMatchesLineSeparators]
    )
    private static let doActionRegex = try! NSRegularExpression(
        pattern: #"do\(action="([^"]+)"([^)]*)\)"#
    )
    private static let instructionRegex = try? NSRegularExpression(pattern: #"instruction="([^"]*)""#)
    private static let finishMessageRegex = try? NSRegularExpression(pattern: #"finish\(message="([^"]*)"\)"#)

    static func extractAction(_ llmOutput: String) -> String {
        if let block = extractAnswerBlock(llmOutput) {
            let text = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return text }
        }
        return llmOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Final user-facing bubble text after stream completes.
    static func extractDisplayText(_ llmOutput: String) -> String {
        formatDisplayText(llmOutput) ?? ""
    }

    /// Best-effort partial format while answer is still streaming (Android `formatPartial` parity).
    static func extractDisplayTextPartial(_ rawAnswer: String) -> String? {
        let trimmed = rawAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let formatted = formatDisplayText(trimmed) {
            return formatted
        }
        return trimmed
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private static func formatDisplayText(_ rawAnswer: String) -> String? {
        let answer = extractAnswerBlock(rawAnswer)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            ?? rawAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { return nil }

        if let message = extractFinishMessage(from: answer) {
            return message
        }

        let range = NSRange(answer.startIndex..., in: answer)
        if let match = doActionRegex.firstMatch(in: answer, range: range),
           let actionRange = Range(match.range(at: 1), in: answer),
           let paramsRange = Range(match.range(at: 2), in: answer) {
            let actionName = String(answer[actionRange])
            let params = String(answer[paramsRange])
            if let instruction = extractInstruction(from: params), !instruction.isEmpty {
                return instruction
            }
            let direction = extractParam(params, key: "direction")
            let value = extractParam(params, key: "value")
            var actionLine = actionName
            if let direction, !direction.isEmpty {
                actionLine += ": \(direction)"
            } else if let value, !value.isEmpty {
                actionLine += ": \(value)"
            }
            return actionLine
        }

        if let instruction = extractInstruction(from: answer), !instruction.isEmpty {
            return instruction
        }

        return answer
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private static func extractAnswerBlock(_ text: String) -> String? {
        let open = "<answer>"
        let close = "</answer>"
        guard let start = text.range(of: open) else { return nil }
        let contentStart = start.upperBound
        if let end = text.range(of: close, range: contentStart..<text.endIndex) {
            return String(text[contentStart..<end.lowerBound])
        }
        return String(text[contentStart...])
    }

    private static func extractInstruction(from text: String) -> String? {
        guard let instructionRegex,
              let match = instructionRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        let value = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func extractFinishMessage(from action: String) -> String? {
        guard let finishMessageRegex,
              let match = finishMessageRegex.firstMatch(in: action, range: NSRange(action.startIndex..., in: action)),
              let range = Range(match.range(at: 1), in: action) else {
            return nil
        }
        let value = String(action[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func extractParam(_ params: String, key: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"\#(key)="([^"]*)""#),
              let match = regex.firstMatch(in: params, range: NSRange(params.startIndex..., in: params)),
              let range = Range(match.range(at: 1), in: params) else {
            return nil
        }
        let value = String(params[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

/// Limits streaming coaching UI updates (Android `StreamingUiThrottler` parity).
final class LMStreamingUiThrottler: @unchecked Sendable {
    private let lock = NSLock()
    private let minInterval: TimeInterval = 0.05
    private var lastReasoningEmit = Date.distantPast
    private var lastActionEmit = Date.distantPast
    private var lastEmittedReasoning = ""
    private var lastEmittedAction: String?
    private var pendingReasoning: String?
    private var pendingAction: String?

    func onDelta(
        reasoningText: String,
        actionPreview: String?,
        onReasoning: (String) -> Void,
        onAction: (String) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        if !reasoningText.isEmpty, reasoningText != lastEmittedReasoning {
            if lastReasoningEmit == .distantPast || now.timeIntervalSince(lastReasoningEmit) >= minInterval {
                emitReasoning(reasoningText, at: now, onReasoning: onReasoning)
            } else {
                pendingReasoning = reasoningText
            }
        }
        if let actionPreview, actionPreview != lastEmittedAction {
            if lastActionEmit == .distantPast || now.timeIntervalSince(lastActionEmit) >= minInterval {
                emitAction(actionPreview, at: now, onAction: onAction)
            } else {
                pendingAction = actionPreview
            }
        }
    }

    func flush(
        reasoningText: String,
        actionPreview: String?,
        onReasoning: (String) -> Void,
        onAction: (String) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        let reasoning = pendingReasoning ?? reasoningText
        if !reasoning.isEmpty, reasoning != lastEmittedReasoning {
            emitReasoning(reasoning, at: Date(), onReasoning: onReasoning)
        }
        let action = pendingAction ?? actionPreview
        if let action, action != lastEmittedAction {
            emitAction(action, at: Date(), onAction: onAction)
        }
    }

    private func emitReasoning(_ text: String, at now: Date, onReasoning: (String) -> Void) {
        lastReasoningEmit = now
        lastEmittedReasoning = text
        pendingReasoning = nil
        onReasoning(text)
    }

    private func emitAction(_ text: String, at now: Date, onAction: (String) -> Void) {
        lastActionEmit = now
        lastEmittedAction = text
        pendingAction = nil
        onAction(text)
    }
}

/// Maps semantic actions to skip categories and summarizes history.
enum LMActionClassifier {
    static func categoryOf(_ action: String) -> LMSuggestionCategory {
        if action.contains("Show_Box_Guidance") || action.contains("Move_Camera") || action.contains("Rotate_Camera") {
            return .positioning
        }
        if action.contains("Show_LineArt_Guidance") || action.contains("Zoom") || action.contains("Guide_Pose") {
            return .scalePose
        }
        if action.contains("Adjust_Exposure") { return .exposure }
        if action.contains("Find_Scene") { return .scene }
        return .positioning
    }

    static func summarizeAction(_ action: String) -> String {
        let normalized = stripShowActions(action)
        if let regex = try? NSRegularExpression(pattern: #"do\(action="([^"]+)"([^)]*)\)"#),
           let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
           let nameRange = Range(match.range(at: 1), in: normalized) {
            let name = String(normalized[nameRange])
            return name
        }
        if normalized.contains("finish") { return "finish" }
        return normalized.split(separator: "\n").first.map(String.init) ?? action
    }

    static func stripShowActions(_ action: String) -> String {
        if action.contains("Show_Box_Guidance") {
            return action.replacingOccurrences(of: "Show_Box_Guidance", with: "Move_Camera")
        }
        if action.contains("Show_LineArt_Guidance") {
            return action.replacingOccurrences(of: "Show_LineArt_Guidance", with: "Zoom")
        }
        return action
    }
}

/// Detects oscillating coaching actions with stagnant scores.
enum LMOscillationDetector {
    static func isOscillating(_ recent: [LMRoundRecord], policy: LMCoachingPolicyConfig) -> Bool {
        guard recent.count >= 2 else { return false }
        let last = recent[recent.count - 1]
        let prev = recent[recent.count - 2]
        return isOpposite(prev.action, last.action) &&
            abs(last.scoreAfter - prev.scoreAfter) < policy.oscillationStagnationEps
    }

    static func isOpposite(_ a: String, _ b: String) -> Bool {
        directionOpposite(a, b, "Left", "Right") ||
            directionOpposite(a, b, "Up", "Down") ||
            zoomOpposite(a, b)
    }

    private static func directionOpposite(_ a: String, _ b: String, _ first: String, _ second: String) -> Bool {
        (a.contains(first) && b.contains(second)) || (a.contains(second) && b.contains(first))
    }

    private static func zoomOpposite(_ a: String, _ b: String) -> Bool {
        (a.contains("Zoom") && a.contains("In") && b.contains("Zoom") && b.contains("Out")) ||
            (a.contains("Zoom") && a.contains("Out") && b.contains("Zoom") && b.contains("In"))
    }
}

/// Builds the forbidden-actions block for the dynamic user prompt.
enum LMForbiddenActionsBuilder {
    static func build(
        scores: LMCompositionScore,
        policy: LMCoachingPolicyConfig,
        session: LMCoachingSession
    ) -> String {
        var lines: [String] = []
        if scores.humanScene == nil {
            lines.append("- Guide_Pose（当前或参考图无人，禁止引导姿势）")
        }
        if scores.overallScore < policy.deferExposureBelowOverall {
            lines.append("- Adjust_Exposure（整体分偏低，优先调整构图而非曝光）")
        }
        if session.isSkipped(.positioning) {
            lines.append("- Move_Camera, Rotate_Camera（用户已跳过机位/旋转建议）")
        }
        if session.isSkipped(.scalePose) {
            lines.append("- Zoom, Guide_Pose（用户已跳过变焦/姿势建议）")
        }
        if session.isSkipped(.exposure) {
            lines.append("- Adjust_Exposure（用户已跳过曝光调整）")
        }
        if session.isSkipped(.scene) {
            lines.append("- Find_Scene（用户已跳过换场景建议）")
        }
        return lines.isEmpty ? "无" : lines.joined(separator: "\n")
    }
}

/// Builds effective system prompt with session skip constraints appended.
func buildEffectiveSystemPrompt(base: String, session: LMCoachingSession) -> String {
    var result = base.trimmingCharacters(in: .whitespacesAndNewlines)
    if session.hasSkippedCategories() {
        result += "\n\n【本轮会话动态约束】\n"
        result += session.formatSkippedCategories()
        result += "\n以上类型的语义动作不得出现在 <answer> 中。"
    }
    return result
}
