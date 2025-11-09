//
//  LMPersonDetectionManager.swift
//  processor
//
//  Created by Kiro on 2025/11/9.
//

import UIKit
import Vision
import AVFoundation

/// 人物检测结果
struct PersonDetectionResult {
    /// 检测到的人物边界框（归一化坐标 0-1）
    let boundingBox: BoundingBox
    
    /// 置信度 (0-1)
    let confidence: Float
    
    /// 检测时间戳
    let timestamp: Date
}

/// 人物检测管理器代理
protocol LMPersonDetectionManagerDelegate: AnyObject {
    /// 检测到人物
    func personDetectionManager(_ manager: LMPersonDetectionManager, didDetectPerson result: PersonDetectionResult)
    
    /// 检测失败
    func personDetectionManager(_ manager: LMPersonDetectionManager, didFailWithError error: Error)
}

/// 人物检测管理器
class LMPersonDetectionManager {
    
    // MARK: - Properties
    weak var delegate: LMPersonDetectionManagerDelegate?
    
    private var isDetecting = false
    private var detectionQueue = DispatchQueue(label: "com.framaist.persondetection", qos: .userInitiated)
    private var lastDetectionTime: Date?
    private let detectionInterval: TimeInterval = 0.1 // 每100ms检测一次
    
    // Vision 请求
    private lazy var personDetectionRequest: VNDetectHumanRectanglesRequest = {
        let request = VNDetectHumanRectanglesRequest { [weak self] request, error in
            self?.handleDetectionResults(request: request, error: error)
        }
        request.upperBodyOnly = false // 检测全身
        return request
    }()
    
    // MARK: - Public Methods
    
    /// 开始人物检测
    func startDetection() {
        guard !isDetecting else { return }
        isDetecting = true
        LMLogger.log("👤 Person detection started")
    }
    
    /// 停止人物检测
    func stopDetection() {
        isDetecting = false
        lastDetectionTime = nil
        LMLogger.log("👤 Person detection stopped")
    }
    
    /// 处理视频帧进行人物检测
    /// - Parameter sampleBuffer: 视频帧
    func processVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isDetecting else { return }
        
        // 限制检测频率
        if let lastTime = lastDetectionTime,
           Date().timeIntervalSince(lastTime) < detectionInterval {
            return
        }
        
        lastDetectionTime = Date()
        
        // 获取图像
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // 在后台队列执行检测
        detectionQueue.async { [weak self] in
            self?.performDetection(on: pixelBuffer)
        }
    }
    
    /// 处理静态图像进行人物检测
    /// - Parameter image: 待检测的图像
    func processImage(_ image: UIImage) {
        guard isDetecting else { return }
        
        guard let cgImage = image.cgImage else {
            LMLogger.log("❌ Failed to get CGImage from UIImage")
            return
        }
        
        detectionQueue.async { [weak self] in
            self?.performDetection(on: cgImage)
        }
    }
    
    // MARK: - Private Methods
    
    /// 执行检测（CVPixelBuffer）
    private func performDetection(on pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([personDetectionRequest])
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.personDetectionManager(self, didFailWithError: error)
            }
        }
    }
    
    /// 执行检测（CGImage）
    private func performDetection(on cgImage: CGImage) {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([personDetectionRequest])
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.personDetectionManager(self, didFailWithError: error)
            }
        }
    }
    
    /// 处理检测结果
    private func handleDetectionResults(request: VNRequest, error: Error?) {
        if let error = error {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.personDetectionManager(self, didFailWithError: error)
            }
            return
        }
        
        guard let observations = request.results as? [VNHumanObservation],
              let firstPerson = observations.first else {
            // 未检测到人物
            return
        }
        
        // 转换边界框坐标
        let visionBox = firstPerson.boundingBox
        
        // Vision 框架的坐标系统：原点在左下角
        // 需要转换为标准坐标系统：原点在左上角
        let boundingBox = BoundingBox(
            x: Double(visionBox.origin.x),
            y: Double(1.0 - visionBox.origin.y - visionBox.height), // 翻转 Y 坐标
            width: Double(visionBox.size.width),
            height: Double(visionBox.size.height)
        )
        
        let result = PersonDetectionResult(
            boundingBox: boundingBox,
            confidence: firstPerson.confidence,
            timestamp: Date()
        )
        
        // 回到主线程通知代理
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.personDetectionManager(self, didDetectPerson: result)
        }
    }
}

// MARK: - 边界框对齐计算
extension LMPersonDetectionManager {
    
    /// 计算两个边界框的对齐度
    /// - Parameters:
    ///   - box1: 第一个边界框
    ///   - box2: 第二个边界框
    /// - Returns: 对齐度 (0-1)，1表示完全对齐
    static func calculateAlignment(between box1: BoundingBox, and box2: BoundingBox) -> Double {
        // 计算中心点距离
        let center1 = CGPoint(x: box1.x + box1.width / 2, y: box1.y + box1.height / 2)
        let center2 = CGPoint(x: box2.x + box2.width / 2, y: box2.y + box2.height / 2)
        
        let centerDistance = sqrt(
            pow(center1.x - center2.x, 2) +
            pow(center1.y - center2.y, 2)
        )
        
        // 计算尺寸相似度
        let sizeRatio = min(box1.width / box2.width, box2.width / box1.width) *
                       min(box1.height / box2.height, box2.height / box1.height)
        
        // 计算 IoU (Intersection over Union)
        let iou = calculateIoU(box1: box1, box2: box2)
        
        // 综合评分
        let centerScore = max(0, 1.0 - centerDistance * 2) // 中心距离权重
        let sizeScore = sizeRatio // 尺寸相似度权重
        let iouScore = iou // IoU 权重
        
        let alignment = (centerScore * 0.3 + sizeScore * 0.3 + iouScore * 0.4)
        
        return alignment
    }
    
    /// 计算两个边界框的 IoU (Intersection over Union)
    private static func calculateIoU(box1: BoundingBox, box2: BoundingBox) -> Double {
        // 计算交集
        let x1 = max(box1.x, box2.x)
        let y1 = max(box1.y, box2.y)
        let x2 = min(box1.x + box1.width, box2.x + box2.width)
        let y2 = min(box1.y + box1.height, box2.y + box2.height)
        
        let intersectionWidth = max(0, x2 - x1)
        let intersectionHeight = max(0, y2 - y1)
        let intersectionArea = intersectionWidth * intersectionHeight
        
        // 计算并集
        let area1 = box1.width * box1.height
        let area2 = box2.width * box2.height
        let unionArea = area1 + area2 - intersectionArea
        
        // 计算 IoU
        if unionArea > 0 {
            return intersectionArea / unionArea
        } else {
            return 0
        }
    }
    
    /// 判断是否对齐（对齐度超过阈值）
    /// - Parameters:
    ///   - box1: 第一个边界框
    ///   - box2: 第二个边界框
    ///   - threshold: 对齐阈值 (0-1)，默认 0.7
    /// - Returns: 是否对齐
    static func isAligned(box1: BoundingBox, box2: BoundingBox, threshold: Double = 0.7) -> Bool {
        let alignment = calculateAlignment(between: box1, and: box2)
        return alignment >= threshold
    }
}
