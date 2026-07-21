//
//  LMPersonDetectionManager.swift
//  processor
//
//  Human rectangle detection for AR box guidance (VNDetectHumanRectanglesRequest).
//

import UIKit
import Vision
import AVFoundation
import CoreImage
import ImageIO

/// 人物检测结果
struct PersonDetectionResult {
    let boundingBox: BoundingBox
    let confidence: Float
    let timestamp: Date
}

/// 人物检测管理器代理
protocol LMPersonDetectionManagerDelegate: AnyObject {
    func personDetectionManager(_ manager: LMPersonDetectionManager, didDetectPerson result: PersonDetectionResult)
    func personDetectionManagerDidNotDetectPerson(_ manager: LMPersonDetectionManager)
    func personDetectionManager(_ manager: LMPersonDetectionManager, didFailWithError error: Error)
}

/// Box-guidance person detection via Vision human rectangles (full body, then upper body).
class LMPersonDetectionManager {

    static let shared = LMPersonDetectionManager()

    weak var delegate: LMPersonDetectionManagerDelegate?

    private var isDetecting = false
    private let detectionQueue = DispatchQueue(label: "com.framaist.persondetection", qos: .userInitiated)
    private var lastDetectionTime: Date?
    private let detectionInterval: TimeInterval = 0.1

    var currentCameraPosition: AVCaptureDevice.Position = .back

    func startDetection() {
        guard !isDetecting else { return }
        isDetecting = true
        LMLogger.log("👤 Person detection started (human rectangles)")
    }

    func stopDetection() {
        isDetecting = false
        lastDetectionTime = nil
        LMLogger.log("👤 Person detection stopped")
    }

    func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isDetecting else { return }

        if let lastTime = lastDetectionTime,
           Date().timeIntervalSince(lastTime) < detectionInterval {
            return
        }
        lastDetectionTime = Date()

        let orientation = imageOrientation(for: currentCameraPosition)

        detectionQueue.async { [weak self] in
            guard let self else { return }
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                self.dispatchDetection(nil, confidence: 0)
                return
            }

            do {
                let detection = try self.detectHumanRectangle(
                    in: pixelBuffer,
                    orientation: orientation
                )
                self.dispatchDetection(detection?.bbox, confidence: detection?.confidence ?? 0)
            } catch {
                self.dispatchFailure(error)
            }
        }
    }

    func processImage(_ image: UIImage, shouldRotateToPortrait: Bool = false) {
        guard isDetecting else { return }

        detectionQueue.async { [weak self] in
            guard let self else { return }

            do {
                let detection = try self.detectHumanRectangle(
                    in: image,
                    shouldRotateToPortrait: shouldRotateToPortrait
                )
                self.dispatchDetection(detection?.bbox, confidence: detection?.confidence ?? 0)
            } catch {
                self.dispatchFailure(error)
            }
        }
    }

    // MARK: - Vision

    private struct HumanRectangleDetection {
        let bbox: CGRect
        let confidence: Float
    }

    private func detectHumanRectangle(
        in image: UIImage,
        shouldRotateToPortrait: Bool
    ) throws -> HumanRectangleDetection? {
        var cgImage = image.cgImage
        if shouldRotateToPortrait, image.size.width > image.size.height, let source = cgImage {
            cgImage = LMARGuidancePolicy.makePortraitCanvasImage(from: source, shouldRotateToPortrait: true)
        }
        guard let cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        return try detectHumanRectangle(in: ciImage)
    }

    private func detectHumanRectangle(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation
    ) throws -> HumanRectangleDetection? {
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        return try performHumanRectangleDetection(with: handler)
    }

    private func detectHumanRectangle(in ciImage: CIImage) throws -> HumanRectangleDetection? {
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        return try performHumanRectangleDetection(with: handler)
    }

    /// Tries full-body detection first, then upper-body fallback.
    private func performHumanRectangleDetection(
        with handler: VNImageRequestHandler
    ) throws -> HumanRectangleDetection? {
        if let fullBody = try runHumanRectangleRequest(handler: handler, upperBodyOnly: false) {
            return fullBody
        }
        return try runHumanRectangleRequest(handler: handler, upperBodyOnly: true)
    }

    private func runHumanRectangleRequest(
        handler: VNImageRequestHandler,
        upperBodyOnly: Bool
    ) throws -> HumanRectangleDetection? {
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = upperBodyOnly
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return nil
        }

        return HumanRectangleDetection(
            bbox: observation.boundingBox,
            confidence: observation.confidence
        )
    }

    // MARK: - Dispatch

    private func dispatchDetection(_ bbox: CGRect?, confidence: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let bbox else {
                self.delegate?.personDetectionManagerDidNotDetectPerson(self)
                return
            }

            let result = PersonDetectionResult(
                boundingBox: BoundingBox(
                    x: Double(bbox.origin.x),
                    y: Double(bbox.origin.y),
                    width: Double(bbox.width),
                    height: Double(bbox.height)
                ),
                confidence: confidence,
                timestamp: Date()
            )
            self.delegate?.personDetectionManager(self, didDetectPerson: result)
        }
    }

    private func dispatchFailure(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.personDetectionManager(self, didFailWithError: error)
        }
    }

    private func imageOrientation(for position: AVCaptureDevice.Position) -> CGImagePropertyOrientation {
        position == .front ? .leftMirrored : .right
    }
}

// MARK: - 边界框对齐计算
extension LMPersonDetectionManager {

    static func calculateAlignment(between box1: BoundingBox, and box2: BoundingBox) -> Double {
        let center1 = CGPoint(x: box1.x + box1.width / 2, y: box1.y + box1.height / 2)
        let center2 = CGPoint(x: box2.x + box2.width / 2, y: box2.y + box2.height / 2)

        let centerDistance = sqrt(
            pow(center1.x - center2.x, 2) +
            pow(center1.y - center2.y, 2)
        )

        let sizeRatio = min(box1.width / box2.width, box2.width / box1.width) *
                       min(box1.height / box2.height, box2.height / box1.height)
        let iou = calculateIoU(box1: box1, box2: box2)
        let centerScore = max(0, 1.0 - centerDistance * 2)

        return centerScore * 0.3 + sizeRatio * 0.3 + iou * 0.4
    }

    private static func calculateIoU(box1: BoundingBox, box2: BoundingBox) -> Double {
        let x1 = max(box1.x, box2.x)
        let y1 = max(box1.y, box2.y)
        let x2 = min(box1.x + box1.width, box2.x + box2.width)
        let y2 = min(box1.y + box1.height, box2.y + box2.height)

        let intersectionArea = max(0, x2 - x1) * max(0, y2 - y1)
        let unionArea = box1.width * box1.height + box2.width * box2.height - intersectionArea
        return unionArea > 0 ? intersectionArea / unionArea : 0
    }

    static func isAligned(box1: BoundingBox, box2: BoundingBox, threshold: Double = 0.7) -> Bool {
        calculateAlignment(between: box1, and: box2) >= threshold
    }
}
