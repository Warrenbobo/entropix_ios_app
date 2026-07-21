//
//  LMActionExecutor.swift
//  processor
//
//  Applies final execution plan to camera UI delegate.
//

import Foundation

/// Delegate for applying coaching actions to the camera UI.
protocol LMAgentCoachingUIDelegate: AnyObject {
    func agentCoaching(didUpdateAction displayText: String, isFinal: Bool)
    func agentCoaching(didUpdateReasoning reasoning: String)
    func agentCoaching(didUpdateAgentState state: LMAgentState)
    func agentCoaching(didSetExecutionTool tool: LMExecutionTool, instruction: String?)
    func agentCoaching(didFinishWithCause cause: LMFinishCause)
    func agentCoaching(didApplyExposureAction semanticAction: String)
}

/// Applies arbitrated semantic actions to the camera UI via delegate.
final class LMActionExecutor: @unchecked Sendable {
    private weak var delegate: LMAgentCoachingUIDelegate?
    private let toolRouter: LMExecutionToolRouter

    init(delegate: LMAgentCoachingUIDelegate?, toolRouter: LMExecutionToolRouter) {
        self.delegate = delegate
        self.toolRouter = toolRouter
    }

    /// Updates the UI delegate after the camera page wires coaching HUD.
    func updateDelegate(_ delegate: LMAgentCoachingUIDelegate?) {
        self.delegate = delegate
    }

    /// Resolves and applies the final execution plan from an arbitrated semantic action.
    @discardableResult
    func execute(
        semanticAction: String,
        scores: LMCompositionScore,
        session: LMCoachingSession,
        systemState: LMExecutionSystemState,
        finishCause: LMFinishCause? = nil
    ) -> LMFinalExecutionPlan {
        let plan = toolRouter.resolveExecution(
            semanticAction: semanticAction,
            scores: scores,
            session: session,
            systemState: systemState
        )
        let display = finishCause.map(LMFinishCopy.display) ?? plan.displayText
        let applyImmediate = { [weak self] in
            guard let self else { return }
            self.delegate?.agentCoaching(didUpdateAction: display, isFinal: true)
            if let finishCause {
                self.delegate?.agentCoaching(didFinishWithCause: finishCause)
            }
        }
        let applyDeferred = { [weak self] in
            guard let self else { return }
            self.delegate?.agentCoaching(
                didSetExecutionTool: plan.executionTool,
                instruction: plan.toolInstruction
            )
            if semanticAction.contains("Adjust_Exposure") {
                self.delegate?.agentCoaching(didApplyExposureAction: semanticAction)
            }
        }
        if Thread.isMainThread {
            applyImmediate()
            DispatchQueue.main.async(execute: applyDeferred)
        } else {
            DispatchQueue.main.sync(execute: applyImmediate)
            DispatchQueue.main.async(execute: applyDeferred)
        }
        return plan
    }
}
