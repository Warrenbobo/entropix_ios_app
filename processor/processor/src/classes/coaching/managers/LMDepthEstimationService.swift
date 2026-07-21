//
//  LMDepthEstimationService.swift
//  processor
//
//  DepthAnything V2 depth estimation via dynamically loaded Core ML model.
//

import UIKit
import CoreML
import CoreVideo

/// Depth estimation service using DepthAnythingV2SmallF16P6 (compiled Core ML model).
final class LMDepthEstimationService: @unchecked Sendable {
    static let shared = LMDepthEstimationService()

    private static let modelBaseName = "DepthAnythingV2SmallF16P6"

    private let lock = NSLock()
    private var model: MLModel?
    /// Model input width from `MLImageConstraint` (DepthAnythingV2SmallF16P6: 518).
    private var modelInputWidth = 518
    /// Model input height from `MLImageConstraint` (DepthAnythingV2SmallF16P6: 392).
    private var modelInputHeight = 392

    private init() {}

    /// Whether the depth model is already resident in memory.
    var isLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return model != nil
    }

    /// Resolves the compiled `.mlmodelc` (preferred) or bundled `.mlpackage` URL.
    private func bundledModelURL() -> URL? {
        let bundle = Bundle.main
        if let compiled = bundle.url(forResource: Self.modelBaseName, withExtension: "mlmodelc") {
            return compiled
        }
        return bundle.url(forResource: Self.modelBaseName, withExtension: "mlpackage")
    }

    /// Applies a freshly loaded model and reads its input image constraints.
    private func adoptLoadedModel(_ loadedModel: MLModel) {
        if let inputDesc = loadedModel.modelDescription.inputDescriptionsByName.values.first,
           let constraint = inputDesc.imageConstraint {
            modelInputWidth = Int(constraint.pixelsWide)
            modelInputHeight = Int(constraint.pixelsHigh)
        }
        model = loadedModel
        LMLogger.log("✅ DepthAnythingV2 model loaded (\(modelInputWidth)x\(modelInputHeight))")
    }

    /**
     Asynchronously loads the depth model if needed (Stage A preload).

     Uses `MLModel.load` so compile/load does not block the caller’s thread.
     */
    func ensureModelLoadedAsync() async throws {
        lock.lock()
        if model != nil {
            lock.unlock()
            return
        }
        lock.unlock()

        guard let url = bundledModelURL() else {
            throw DepthEstimationError.modelNotFound
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        let loadedModel = try await MLModel.load(contentsOf: url, configuration: configuration)

        lock.lock()
        if model == nil {
            adoptLoadedModel(loadedModel)
        }
        lock.unlock()
    }

    /// Loads the depth model from bundle if not already loaded (predict-path fallback).
    func ensureModelLoaded() throws {
        lock.lock()
        defer { lock.unlock() }
        if model != nil { return }
        guard let url = bundledModelURL() else {
            throw DepthEstimationError.modelNotFound
        }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        let loadedModel = try MLModel(contentsOf: url, configuration: configuration)
        adoptLoadedModel(loadedModel)
    }

    /// Unloads the cached model (session teardown / memory pressure).
    func unload() {
        lock.lock()
        model = nil
        lock.unlock()
    }

    /**
     Predicts a **model-resolution** inverse depth map (letterboxed input space).

     Returns `nil` on load / preprocess / inference failure — **no silent 0.5 fallback**.
     Hold `lock` for the entire predict to match EVA02 serialization.
     */
    func predictDepthMap(for image: UIImage) -> LMDepthMap? {
        do {
            try ensureModelLoaded()
        } catch {
            LMLogger.log("❌ Depth model load failed: \(error.localizedDescription)")
            return nil
        }

        lock.lock()
        defer { lock.unlock() }

        guard let loadedModel = model else { return nil }
        let inputWidth = modelInputWidth
        let inputHeight = modelInputHeight

        guard let pixelBuffer = makeInputPixelBuffer(from: image, width: inputWidth, height: inputHeight) else {
            LMLogger.log("❌ Depth preprocess failed: pixel buffer")
            return nil
        }

        do {
            let inputName = loadedModel.modelDescription.inputDescriptionsByName.keys.first ?? "image"
            let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: pixelBuffer])
            let output = try loadedModel.prediction(from: provider)
            guard let values = extractDepthArray(from: output, model: loadedModel, width: inputWidth, height: inputHeight) else {
                LMLogger.log("❌ Depth output extract failed")
                return nil
            }
            return LMDepthMap(values: values, width: inputWidth, height: inputHeight)
        } catch {
            LMLogger.log("❌ Depth inference failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Letterboxes `image` into a BGRA pixel buffer matching the model's fixed input size.
    private func makeInputPixelBuffer(from image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }

        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer = buffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let srcW = CGFloat(cgImage.width)
        let srcH = CGFloat(cgImage.height)
        let scale = min(CGFloat(width) / srcW, CGFloat(height) / srcH)
        let drawW = srcW * scale
        let drawH = srcH * scale
        let offsetX = (CGFloat(width) - drawW) * 0.5
        let offsetY = (CGFloat(height) - drawH) * 0.5

        // CVPixelBuffer + CGContext uses a bottom-left origin; flip before drawing.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(
            cgImage,
            in: CGRect(x: offsetX, y: offsetY, width: drawW, height: drawH)
        )
        return pixelBuffer
    }

    /// Reads the low-resolution depth map from model output (grayscale FP16 image or MultiArray).
    private func extractDepthArray(
        from output: MLFeatureProvider,
        model: MLModel,
        width: Int,
        height: Int
    ) -> [Float]? {
        let outputName = model.modelDescription.outputDescriptionsByName.keys.first ?? "depth"
        guard let feature = output.featureValue(for: outputName) else { return nil }
        if let pixelBuffer = feature.imageBufferValue {
            return depthArray(from: pixelBuffer)
        }
        if let multiArray = feature.multiArrayValue {
            let count = multiArray.count
            var result = [Float](repeating: 0, count: count)
            for i in 0..<count {
                result[i] = multiArray[i].floatValue
            }
            guard count == width * height || count > 0 else { return nil }
            return result
        }
        return nil
    }

    /// Converts a grayscale depth `CVPixelBuffer` (FP16 or UInt8) to a row-major `[Float]` array.
    private func depthArray(from pixelBuffer: CVPixelBuffer) -> [Float]? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let count = width * height
        var result = [Float](repeating: 0, count: count)

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        if format == kCVPixelFormatType_OneComponent16Half {
            let src = baseAddress.assumingMemoryBound(to: UInt16.self)
            let rowStride = bytesPerRow / MemoryLayout<UInt16>.size
            for y in 0..<height {
                for x in 0..<width {
                    let half = src[y * rowStride + x]
                    result[y * width + x] = Float(Float16(bitPattern: half))
                }
            }
        } else if format == kCVPixelFormatType_OneComponent8 {
            let src = baseAddress.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    result[y * width + x] = Float(src[y * bytesPerRow + x]) / 255
                }
            }
        } else if format == kCVPixelFormatType_32BGRA {
            let src = baseAddress.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * bytesPerRow + x * 4
                    result[y * width + x] = Float(src[offset + 2]) / 255
                }
            }
        } else {
            return nil
        }
        return result
    }

    enum DepthEstimationError: Error, LocalizedError {
        case modelNotFound

        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "\(LMDepthEstimationService.modelBaseName).mlmodelc not found in bundle"
            }
        }
    }
}
