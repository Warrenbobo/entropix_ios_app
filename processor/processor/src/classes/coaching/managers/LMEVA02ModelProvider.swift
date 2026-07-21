//
//  LMEVA02ModelProvider.swift
//  processor
//
//  Shared EVA02 Core ML instance for Inspire Me and composition scoring.
//

import CoreML
import Foundation

/// Shared EVA02 model cache — one instance for Inspire Me and score module.
enum LMEVA02ModelProvider {
    private static let lock = NSLock()
    private static var cachedModel: EVA02?
    private static let modelBaseName = "EVA02"

    /// Whether the model is already resident in memory.
    static var isLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cachedModel != nil
    }

    /// Resolves compiled `.mlmodelc` (preferred) or bundled `.mlpackage` URL.
    private static func bundledModelURL() -> URL? {
        let bundle = Bundle.main
        if let compiled = bundle.url(forResource: modelBaseName, withExtension: "mlmodelc") {
            return compiled
        }
        return bundle.url(forResource: modelBaseName, withExtension: "mlpackage")
    }

    /**
     Asynchronously loads EVA02 if needed (Stage A preload).

     Prefers `MLModel.load` + `EVA02(model:)`; falls back to the generated sync initializer
     on a background task so the caller is never blocked on MainActor.
     */
    static func ensureModelLoadedAsync() async throws {
        lock.lock()
        if cachedModel != nil {
            lock.unlock()
            return
        }
        lock.unlock()

        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all

        let wrapped: EVA02
        if let url = bundledModelURL() {
            let mlModel = try await MLModel.load(contentsOf: url, configuration: configuration)
            wrapped = EVA02(model: mlModel)
        } else {
            wrapped = try await Task.detached(priority: .utility) {
                try EVA02(configuration: configuration)
            }.value
        }

        lock.lock()
        if cachedModel == nil {
            cachedModel = wrapped
            LMLogger.log("✅ EVA02 model loaded (shared provider, async)")
        }
        lock.unlock()
    }

    /// Synchronously loads EVA02 if needed (predict-path fallback).
    static func ensureModelLoaded() throws {
        lock.lock()
        defer { lock.unlock() }
        if cachedModel != nil { return }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        if let url = bundledModelURL() {
            let mlModel = try MLModel(contentsOf: url, configuration: configuration)
            cachedModel = EVA02(model: mlModel)
        } else {
            cachedModel = try EVA02(configuration: configuration)
        }
        LMLogger.log("✅ EVA02 model loaded (shared provider)")
    }

    /**
     Runs EVA02 inference under a process-wide lock (load + predict).

     Shared by Inspire Me and `LMGlobalStructureScorer` so only one prediction runs at a time.
     */
    static func predictEmbedding(from multiArray: MLMultiArray) throws -> EVA02Output {
        try ensureModelLoaded()
        lock.lock()
        defer { lock.unlock() }
        guard let model = cachedModel else {
            throw NSError(
                domain: "LMEVA02ModelProvider",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "EVA02 model unavailable"]
            )
        }
        return try model.prediction(image: multiArray)
    }

    /// Releases the cached model (session teardown / memory pressure).
    static func unload() {
        lock.lock()
        cachedModel = nil
        lock.unlock()
    }
}
