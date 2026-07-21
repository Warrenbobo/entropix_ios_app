//
//  LMGlobalStructureScorer.swift
//  processor
//
//  Global structure similarity via EVA02-Small embeddings.
//

import UIKit
import CoreML

/// Global structure similarity via EVA02-Small embeddings.
final class LMGlobalStructureScorer: @unchecked Sendable {
    private let calibration: LMGlobalStructureCalibration
    private let inferenceLock = NSLock()
    private let embedDim = 384

    init(calibration: LMGlobalStructureCalibration) {
        self.calibration = calibration
    }

    /// Computes calibrated S_global from EVA02 cosine and calibration anchors.
    func score(ref: UIImage, cam: UIImage) -> Float {
        score(refEmbedding: encodeEmbedding(ref), cam: cam)
    }

    /// Computes S_global using a precomputed reference embedding.
    func score(refEmbedding: [Float], cam: UIImage) -> Float {
        let rawCosine = LMCompositionMath.cosineSimilarity(refEmbedding, encodeEmbedding(cam))
        let calibrated = LMCompositionMath.calibrateGlobalStructure(rawCosine, calibration: calibration)
        LMLogger.log(
            "GlobalStructure rawCosine=\(String(format: "%.3f", rawCosine)) " +
            "S_global=\(String(format: "%.3f", calibrated))"
        )
        return LMCompositionMath.clipForDisplay(calibrated)
    }

    /// Encodes `image` to an L2-normalized EVA02 embedding.
    func encodeEmbedding(_ image: UIImage) -> [Float] {
        inferenceLock.lock()
        defer { inferenceLock.unlock() }
        return encode(image)
    }

    private func encode(_ image: UIImage) -> [Float] {
        do {
            let imageProcessor = LMImageProcessor.forEVA02()
            let multiArray = try imageProcessor.processImage(image)
            let output = try LMEVA02ModelProvider.predictEmbedding(from: multiArray)
            guard var embedding = extractEmbedding(from: output) else {
                return [Float](repeating: 0, count: embedDim)
            }
            LMCompositionMath.l2Normalize(&embedding)
            return embedding
        } catch {
            LMLogger.log("❌ EVA02 encode failed: \(error.localizedDescription)")
            return [Float](repeating: 0, count: embedDim)
        }
    }

    private func extractEmbedding(from output: Any) -> [Float]? {
        guard let outputObject = output as? EVA02Output else { return nil }
        let multiArray = outputObject.input0_1
        let count = multiArray.count
        var embedding = [Float](repeating: 0, count: count)
        for i in 0..<count {
            embedding[i] = multiArray[i].floatValue
        }
        return embedding
    }
}
