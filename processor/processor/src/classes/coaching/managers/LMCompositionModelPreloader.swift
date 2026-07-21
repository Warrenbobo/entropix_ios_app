//
//  LMCompositionModelPreloader.swift
//  processor
//
//  Stage A: eager async Core ML preload for composition scoring.
//

import Foundation

/**
 Eagerly loads composition Core ML models once per resident session.

 Call `startPreloadIfNeeded()` when the camera page appears so Stage B reference
 warmup and the first score tick do not pay cold `MLModel` compile/load cost on
 the main thread.
 */
final class LMCompositionModelPreloader: @unchecked Sendable {
    static let shared = LMCompositionModelPreloader()

    private let lock = NSLock()
    private var preloadTask: Task<Void, Never>?
    private var didComplete = false

    private init() {}

    /// Whether the last preload attempt finished (models may still be partially missing).
    var isComplete: Bool {
        lock.lock()
        defer { lock.unlock() }
        return didComplete
    }

    /**
     Starts a background preload if one is not already running or finished.

     Safe to call repeatedly from `viewDidAppear`.
     */
    func startPreloadIfNeeded() {
        lock.lock()
        if didComplete || preloadTask != nil {
            lock.unlock()
            return
        }
        let task = Task(priority: .utility) { [weak self] in
            await self?.preloadAll()
        }
        preloadTask = task
        lock.unlock()
    }

    /**
     Awaits an in-flight or freshly started preload (Stage B entry gate).

     Failures for optional models are logged; required models retry on first predict.
     */
    func preloadIfNeeded() async {
        startPreloadIfNeeded()
        let task: Task<Void, Never>?
        lock.lock()
        task = preloadTask
        lock.unlock()
        await task?.value
    }

    /// Clears completion state after `unload()` so the next camera session reloads.
    func markUnloaded() {
        lock.lock()
        didComplete = false
        preloadTask = nil
        lock.unlock()
    }

    private func preloadAll() async {
        LMLogger.log("⏳ Composition model preload starting")
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    try await LMEVA02ModelProvider.ensureModelLoadedAsync()
                } catch {
                    LMLogger.log("⚠️ EVA02 preload failed: \(error.localizedDescription)")
                }
            }
            group.addTask {
                do {
                    try await LMDepthEstimationService.shared.ensureModelLoadedAsync()
                } catch {
                    LMLogger.log("⚠️ DepthAnything preload failed: \(error.localizedDescription)")
                }
            }
            group.addTask {
                guard LMPidinetModelProvider.shared.isModelInBundle else { return }
                do {
                    try await LMPidinetModelProvider.shared.ensureModelLoadedAsync()
                } catch {
                    LMLogger.log("⚠️ PiDiNet preload failed: \(error.localizedDescription)")
                }
            }
            group.addTask {
                guard LMU2NetpModelProvider.shared.isModelInBundle else { return }
                do {
                    try await LMU2NetpModelProvider.shared.ensureModelLoadedAsync()
                } catch {
                    LMLogger.log("⚠️ U2Netp preload failed: \(error.localizedDescription)")
                }
            }
        }

        lock.lock()
        didComplete = true
        lock.unlock()
        LMLogger.log(
            "✅ Composition model preload finished " +
            "(eva02=\(LMEVA02ModelProvider.isLoaded), " +
            "depth=\(LMDepthEstimationService.shared.isLoaded), " +
            "pidinet=\(LMPidinetModelProvider.shared.isLoaded), " +
            "u2netp=\(LMU2NetpModelProvider.shared.isLoaded))"
        )
    }
}
