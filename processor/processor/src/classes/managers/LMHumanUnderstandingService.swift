//
//  LMHumanUnderstandingService.swift
//  processor
//

import AVFoundation
import CoreImage
import ImageIO
import UIKit
import Vision

/// Unified human perception: one segmentation inference per frame; mask-derived bbox for all consumers.
final class LMHumanUnderstandingService {
    static let shared = LMHumanUnderstandingService()

    private let queue = DispatchQueue(label: "com.framaist.humanUnderstanding", qos: .userInitiated)
    private let segmentationRequest = VNGeneratePersonSegmentationRequest()

    private var referenceSnapshotStorage: LMHumanFrameSnapshot?
    private var latestLiveSnapshotStorage: LMHumanFrameSnapshot?
    private var lastLiveBufferID: ObjectIdentifier?
    private var smoothedLiveBBox: CGRect?
    private var lastLiveAnalyzeTime: CFTimeInterval = 0
    private let liveMinInterval: CFTimeInterval = 0.1

    private(set) var referenceSnapshot: LMHumanFrameSnapshot? {
        get { queue.sync { referenceSnapshotStorage } }
        set { queue.async { self.referenceSnapshotStorage = newValue } }
    }

    private(set) var latestLiveSnapshot: LMHumanFrameSnapshot? {
        get { queue.sync { latestLiveSnapshotStorage } }
        set { queue.async { self.latestLiveSnapshotStorage = newValue } }
    }

    private init() {
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    /// One-shot analyze for reference images (cached as [referenceSnapshot]).
    func analyzeReferenceOnce(
        _ image: UIImage,
        shouldRotateToPortrait: Bool = false
    ) async throws -> LMHumanFrameSnapshot? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let snapshot = try self.performAnalyze(
                        image: image,
                        shouldRotateToPortrait: shouldRotateToPortrait,
                        quality: .accurate,
                        source: .referenceWarmup
                    )
                    self.referenceSnapshotStorage = snapshot
                    continuation.resume(returning: snapshot)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// One-shot analyze for a captured camera frame used by composition scoring.
    func analyzeCameraFrameOnce(_ image: UIImage) async throws -> LMHumanFrameSnapshot? {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    let snapshot = try self.performAnalyze(
                        image: image,
                        shouldRotateToPortrait: false,
                        quality: .fast,
                        source: .scoreCapture
                    )
                    continuation.resume(returning: snapshot)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Live preview analyze with dedupe and rate limit (.fast @ ~10 Hz).
    func analyzeLiveFrame(
        _ sampleBuffer: CMSampleBuffer,
        orientation: CGImagePropertyOrientation,
        cameraPosition: AVCaptureDevice.Position
    ) async -> LMHumanFrameSnapshot? {
        let bufferID = ObjectIdentifier(sampleBuffer)
        let now = CACurrentMediaTime()

        return await withCheckedContinuation { continuation in
            queue.async {
                if self.lastLiveBufferID == bufferID {
                    continuation.resume(returning: self.latestLiveSnapshotStorage)
                    return
                }
                if now - self.lastLiveAnalyzeTime < self.liveMinInterval {
                    continuation.resume(returning: self.latestLiveSnapshotStorage)
                    return
                }
                self.lastLiveAnalyzeTime = now
                self.lastLiveBufferID = bufferID

                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    continuation.resume(returning: self.latestLiveSnapshotStorage)
                    return
                }

                do {
                    let snapshot = try self.performAnalyze(
                        pixelBuffer: pixelBuffer,
                        orientation: orientation,
                        quality: .fast,
                        source: .livePreview,
                        smoothBBox: true
                    )
                    self.latestLiveSnapshotStorage = snapshot
                    continuation.resume(returning: snapshot)
                } catch {
                    continuation.resume(returning: self.latestLiveSnapshotStorage)
                }
            }
        }
    }

    func invalidateReference() {
        queue.async {
            self.referenceSnapshotStorage = nil
        }
    }

    func invalidateLive() {
        queue.async {
            self.latestLiveSnapshotStorage = nil
            self.lastLiveBufferID = nil
            self.smoothedLiveBBox = nil
            self.lastLiveAnalyzeTime = 0
        }
    }

    // MARK: - Private

    private func performAnalyze(
        image: UIImage,
        shouldRotateToPortrait: Bool,
        quality: VNGeneratePersonSegmentationRequest.QualityLevel,
        source: LMHumanFrameSnapshot.Source
    ) throws -> LMHumanFrameSnapshot? {
        var cgImage = image.cgImage
        if shouldRotateToPortrait, image.size.width > image.size.height, let rotated = cgImage {
            cgImage = LMARGuidancePolicy.makePortraitCanvasImage(from: rotated, shouldRotateToPortrait: true)
        }
        guard let cgImage else { return nil }

        segmentationRequest.qualityLevel = quality
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([segmentationRequest])

        guard let observation = segmentationRequest.results?.first as? VNPixelBufferObservation else {
            return nil
        }

        return buildSnapshot(
            mask: observation.pixelBuffer,
            confidence: observation.confidence,
            imageSize: CGSize(width: cgImage.width, height: cgImage.height),
            orientation: .up,
            source: source,
            smoothBBox: false
        )
    }

    private func performAnalyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        quality: VNGeneratePersonSegmentationRequest.QualityLevel,
        source: LMHumanFrameSnapshot.Source,
        smoothBBox: Bool
    ) throws -> LMHumanFrameSnapshot? {
        segmentationRequest.qualityLevel = quality
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        try handler.perform([segmentationRequest])

        guard let observation = segmentationRequest.results?.first as? VNPixelBufferObservation else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        return buildSnapshot(
            mask: observation.pixelBuffer,
            confidence: observation.confidence,
            imageSize: CGSize(width: width, height: height),
            orientation: orientation,
            source: source,
            smoothBBox: smoothBBox
        )
    }

    private func buildSnapshot(
        mask: CVPixelBuffer,
        confidence: Float,
        imageSize: CGSize,
        orientation: CGImagePropertyOrientation,
        source: LMHumanFrameSnapshot.Source,
        smoothBBox: Bool
    ) -> LMHumanFrameSnapshot? {
        guard let derived = LMHumanMaskDerivation.derivedBoundingBox(from: mask) else {
            if smoothBBox { smoothedLiveBBox = nil }
            return nil
        }

        var bbox = derived.bbox
        if smoothBBox {
            bbox = LMHumanMaskDerivation.smoothBBox(previous: smoothedLiveBBox, current: bbox)
            smoothedLiveBBox = bbox
        }

        return LMHumanFrameSnapshot(
            timestamp: CACurrentMediaTime(),
            source: source,
            segmentationMask: mask,
            derivedBBox: bbox,
            maskPixelCount: derived.pixelCount,
            maskConfidence: confidence,
            imageSize: imageSize,
            orientation: orientation
        )
    }
}
