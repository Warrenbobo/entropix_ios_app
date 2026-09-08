//
//  LMInstructProgressCoordinator.swift
//  processor
//
//  Event-driven Get Tips HUD phases (SPEC §5) with minimum dwell.
//

import Foundation

/// Instruct / Get Tips progress phases (no BUILD_PROMPT).
enum LMInstructProgressPhase: Int, CaseIterable, Comparable {
    case capture
    case scorePrepare
    case global
    case geometric
    case human
    case fuse
    case thinking

    static func < (lhs: LMInstructProgressPhase, rhs: LMInstructProgressPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Localized HUD copy for this phase.
    var displayText: String {
        switch self {
        case .capture: return LMText.camera.instructPhaseCapture
        case .scorePrepare: return LMText.camera.instructPhaseScorePrepare
        case .global: return LMText.camera.instructPhaseGlobal
        case .geometric: return LMText.camera.instructPhaseGeometric
        case .human: return LMText.camera.instructPhaseHuman
        case .fuse: return LMText.camera.instructPhaseFuse
        case .thinking: return LMText.camera.instructPhaseThinking
        }
    }
}

/**
 Drives Capture → … → Thinking HUD with completion-event gating + min dwell (~280ms).

 Call `markModuleDone` when GLOBAL / GEOMETRIC / HUMAN / FUSE complete; call
 `enterThinking` once fuse work finishes so prompt/LLM stay under Thinking.
 */
final class LMInstructProgressCoordinator {
    /// Android-aligned shortest readable dwell per phase.
    static let minDwellSeconds: TimeInterval = 0.28

    private let lock = NSLock()
    private var currentPhase: LMInstructProgressPhase?
    private var phaseEnteredAt = Date()
    private var moduleDone: Set<LMInstructProgressPhase> = []
    private var isActive = false
    private var onPhase: ((LMInstructProgressPhase) -> Void)?

    /**
     Starts a new instruct progress sequence.

     - Parameter onPhase: Invoked on the main queue whenever the displayed phase changes.
     */
    func start(onPhase: @escaping (LMInstructProgressPhase) -> Void) {
        lock.lock()
        isActive = true
        moduleDone.removeAll()
        currentPhase = nil
        self.onPhase = onPhase
        lock.unlock()
        advanceTo(.capture)
    }

    /// Stops progress updates (finished / cancelled / error).
    func stop() {
        lock.lock()
        isActive = false
        onPhase = nil
        currentPhase = nil
        moduleDone.removeAll()
        lock.unlock()
    }

    /// Marks a scoring module complete; advances HUD when dwell allows.
    func markModuleDone(_ phase: LMInstructProgressPhase) {
        lock.lock()
        guard isActive else {
            lock.unlock()
            return
        }
        moduleDone.insert(phase)
        lock.unlock()
        tryAdvance()
    }

    /// Moves HUD to Thinking (post-fuse work: prompt, SSE, arbiter).
    func enterThinking() {
        advanceTo(.thinking)
    }

    private func advanceTo(_ phase: LMInstructProgressPhase) {
        lock.lock()
        guard isActive else {
            lock.unlock()
            return
        }
        if let current = currentPhase, phase <= current {
            lock.unlock()
            return
        }
        currentPhase = phase
        phaseEnteredAt = Date()
        let callback = onPhase
        lock.unlock()
        DispatchQueue.main.async {
            callback?(phase)
        }
        tryAdvance()
    }

    private func tryAdvance() {
        lock.lock()
        guard isActive, let current = currentPhase else {
            lock.unlock()
            return
        }

        let next: LMInstructProgressPhase?
        switch current {
        case .capture:
            next = .scorePrepare
        case .scorePrepare:
            next = .global
        case .global:
            next = moduleDone.contains(.global) ? .geometric : nil
        case .geometric:
            next = moduleDone.contains(.geometric) ? .human : nil
        case .human:
            next = moduleDone.contains(.human) ? .fuse : nil
        case .fuse:
            // Thinking is explicit via enterThinking() after fuse completes.
            next = nil
        case .thinking:
            next = nil
        }

        let elapsed = Date().timeIntervalSince(phaseEnteredAt)
        let remaining = Self.minDwellSeconds - elapsed
        lock.unlock()

        guard let next else { return }

        if remaining > 0 {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + remaining) { [weak self] in
                self?.advanceTo(next)
            }
        } else {
            advanceTo(next)
        }
    }
}
