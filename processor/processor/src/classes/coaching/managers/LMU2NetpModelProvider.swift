//
//  LMU2NetpModelProvider.swift
//  processor
//
//  U2-Netp saliency mask via dynamically loaded Core ML model.
//

import UIKit
import CoreML

/**
 U2-Netp saliency provider (Android `u2netp.tflite` parity).

 Letterbox 320×320, pad `#727272` (RGB 114,114,114), ImageNet normalize, NCHW float32.
 */
final class LMU2NetpModelProvider: @unchecked Sendable {
    static let shared = LMU2NetpModelProvider()

    static let inputSize = 320
    private static let modelBaseName = "U2Netp"
    private static let imagenetMean: [Float] = [0.485, 0.456, 0.406]
    private static let imagenetStd: [Float] = [0.229, 0.224, 0.225]

    private let lock = NSLock()
    private var model: MLModel?

    private init() {}

    /// Whether the U2-Netp model is already resident in memory.
    var isLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return model != nil
    }

    /// Whether a bundled U2-Netp Core ML package is present.
    var isModelInBundle: Bool {
        bundledModelURL() != nil
    }

    /// Resolves compiled `.mlmodelc` (preferred) or bundled `.mlpackage` URL.
    private func bundledModelURL() -> URL? {
        let bundle = Bundle.main
        if let compiled = bundle.url(forResource: Self.modelBaseName, withExtension: "mlmodelc") {
            return compiled
        }
        return bundle.url(forResource: Self.modelBaseName, withExtension: "mlpackage")
    }

    /**
     Asynchronously loads U2-Netp if needed (Stage A preload).

     No-ops when the model is missing from the bundle (Vision fallback remains available).
     */
    func ensureModelLoadedAsync() async throws {
        lock.lock()
        if model != nil {
            lock.unlock()
            return
        }
        lock.unlock()

        guard let url = bundledModelURL() else {
            throw U2NetpError.modelNotFound
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        let loaded = try await MLModel.load(contentsOf: url, configuration: configuration)

        lock.lock()
        if model == nil {
            model = loaded
            LMLogger.log("✅ U2Netp model loaded (\(Self.inputSize)x\(Self.inputSize), async)")
        }
        lock.unlock()
    }

    /// Loads the U2-Netp model from bundle if not already loaded (predict-path fallback).
    func ensureModelLoaded() throws {
        lock.lock()
        defer { lock.unlock() }
        if model != nil { return }
        guard let url = bundledModelURL() else {
            throw U2NetpError.modelNotFound
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .cpuAndNeuralEngine
        model = try MLModel(contentsOf: url, configuration: configuration)
        LMLogger.log("✅ U2Netp model loaded (\(Self.inputSize)x\(Self.inputSize))")
    }

    /// Unloads the cached model (session teardown / memory pressure).
    func unload() {
        lock.lock()
        model = nil
        lock.unlock()
    }

    /**
     Predicts a 320×320 saliency mask (row-major `[Float]` of length `320*320`, clipped to [0, 1]).

     Returns `nil` on load / preprocess / inference failure.
     */
    func predictSaliencyMask(for image: UIImage) -> [Float]? {
        do {
            try ensureModelLoaded()
        } catch {
            LMLogger.log("❌ U2Netp model load failed: \(error.localizedDescription)")
            return nil
        }

        lock.lock()
        defer { lock.unlock() }

        guard let loadedModel = model else { return nil }
        guard let input = makeLetterboxImagenetNchw(from: image, size: Self.inputSize) else {
            LMLogger.log("❌ U2Netp preprocess failed")
            return nil
        }

        do {
            let inputName = loadedModel.modelDescription.inputDescriptionsByName.keys.first ?? "image"
            let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: input])
            let output = try loadedModel.prediction(from: provider)
            guard let values = extractOutputMap(from: output, model: loadedModel, size: Self.inputSize) else {
                LMLogger.log("❌ U2Netp output extract failed")
                return nil
            }
            return values
        } catch {
            LMLogger.log("❌ U2Netp inference failed: \(error.localizedDescription)")
            return nil
        }
    }

    /**
     Letterboxes `image` into a square canvas with pad RGB(114,114,114), then ImageNet-normalizes to NCHW.
     */
    private func makeLetterboxImagenetNchw(from image: UIImage, size: Int) -> MLMultiArray? {
        guard let cgImage = image.cgImage else { return nil }
        let srcW = cgImage.width
        let srcH = cgImage.height
        guard srcW > 0, srcH > 0 else { return nil }

        let scale = min(CGFloat(size) / CGFloat(srcW), CGFloat(size) / CGFloat(srcH))
        let drawW = max(1, Int((CGFloat(srcW) * scale).rounded()))
        let drawH = max(1, Int((CGFloat(srcH) * scale).rounded()))
        let offsetX = (size - drawW) / 2
        let offsetY = (size - drawH) / 2

        let bytesPerRow = size * 4
        var rgba = [UInt8](repeating: 114, count: size * size * 4)
        for i in stride(from: 3, to: rgba.count, by: 4) {
            rgba[i] = 255
        }

        let drew = rgba.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress else { return false }
            guard let context = CGContext(
                data: base,
                width: size,
                height: size,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            // Match Android Canvas (top-left origin) for letterbox pixel order.
            context.translateBy(x: 0, y: CGFloat(size))
            context.scaleBy(x: 1, y: -1)
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: offsetX, y: offsetY, width: drawW, height: drawH))
            return true
        }
        guard drew else { return nil }

        guard let multiArray = try? MLMultiArray(
            shape: [1, 3, NSNumber(value: size), NSNumber(value: size)],
            dataType: .float32
        ) else { return nil }

        let plane = size * size
        let ptr = multiArray.dataPointer.bindMemory(to: Float.self, capacity: 3 * plane)
        let mean = Self.imagenetMean
        let std = Self.imagenetStd
        for y in 0..<size {
            for x in 0..<size {
                let px = (y * size + x) * 4
                let r = Float(rgba[px]) / 255
                let g = Float(rgba[px + 1]) / 255
                let b = Float(rgba[px + 2]) / 255
                let idx = y * size + x
                ptr[idx] = (r - mean[0]) / std[0]
                ptr[plane + idx] = (g - mean[1]) / std[1]
                ptr[2 * plane + idx] = (b - mean[2]) / std[2]
            }
        }
        return multiArray
    }

    /// Flattens model output into a clipped [0, 1] saliency map of `size*size`.
    private func extractOutputMap(from output: MLFeatureProvider, model: MLModel, size: Int) -> [Float]? {
        let outputName = model.modelDescription.outputDescriptionsByName.keys.first ?? "saliency"
        guard let feature = output.featureValue(for: outputName),
              let multiArray = feature.multiArrayValue else { return nil }

        let expected = size * size
        let count = multiArray.count
        guard count >= expected else { return nil }
        var result = [Float](repeating: 0, count: expected)
        if multiArray.dataType == .float16 {
            let src = multiArray.dataPointer.bindMemory(to: Float16.self, capacity: count)
            for i in 0..<expected {
                result[i] = min(max(Float(src[i]), 0), 1)
            }
        } else {
            let src = multiArray.dataPointer.bindMemory(to: Float.self, capacity: count)
            for i in 0..<expected {
                result[i] = min(max(src[i], 0), 1)
            }
        }
        return result
    }

    enum U2NetpError: Error, LocalizedError {
        case modelNotFound

        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "\(LMU2NetpModelProvider.modelBaseName).mlmodelc / .mlpackage not found in bundle"
            }
        }
    }
}
