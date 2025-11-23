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
    
    /// 人脸边界框（归一化坐标 0-1），如果检测到人脸
    let faceBoundingBox: BoundingBox?
    
    /// 置信度 (0-1)
    let confidence: Float
    
    /// 检测时间戳
    let timestamp: Date
    
    /// 人体宽度是否超过屏幕的2/3
    let isBodyWidthExceedingThreshold: Bool
}

/// 人物检测管理器代理
protocol LMPersonDetectionManagerDelegate: AnyObject {
    /// 检测到人物
    func personDetectionManager(_ manager: LMPersonDetectionManager, didDetectPerson result: PersonDetectionResult)
    
    /// 未检测到人物
    func personDetectionManagerDidNotDetectPerson(_ manager: LMPersonDetectionManager)
    
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
    
    // 人脸检测请求
    private lazy var faceDetectionRequest: VNDetectFaceRectanglesRequest = {
        let request = VNDetectFaceRectanglesRequest()
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
        // 获取设备方向并转换为 CGImagePropertyOrientation
        let deviceOrientation = UIDevice.current.orientation
        let imageOrientation = cgImageOrientation(from: deviceOrientation)
        
        // 创建带有方向信息的请求处理器
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: imageOrientation,
            options: [:]
        )
        
        do {
            // 同时执行人体检测和人脸检测
            try handler.perform([personDetectionRequest, faceDetectionRequest])
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.personDetectionManager(self, didFailWithError: error)
            }
        }
    }
    
    /// 执行检测（CGImage）
    private func performDetection(on cgImage: CGImage) {
        // 获取设备方向并转换为 CGImagePropertyOrientation
        let deviceOrientation = UIDevice.current.orientation
        let imageOrientation = cgImageOrientation(from: deviceOrientation)
        
        // 创建带有方向信息的请求处理器
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: imageOrientation,
            options: [:]
        )
        
        do {
            // 同时执行人体检测和人脸检测
            try handler.perform([personDetectionRequest, faceDetectionRequest])
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.personDetectionManager(self, didFailWithError: error)
            }
        }
    }
    
    /// 将设备方向转换为 CGImagePropertyOrientation
    /// - Parameter deviceOrientation: 设备方向
    /// - Returns: CGImage 方向
    private func cgImageOrientation(from deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        switch deviceOrientation {
        case .portrait:
            return .right // 后置摄像头，设备竖直时图像需要向右旋转90度
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .up // 设备向左横屏时，后置摄像头图像是正的
        case .landscapeRight:
            return .down
        default:
            // 默认使用竖屏方向
            return .right
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
            // 未检测到人物，通知代理
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.personDetectionManagerDidNotDetectPerson(self)
            }
            return
        }
        
        // 转换人体边界框坐标
        let visionBox = firstPerson.boundingBox
        
        // Vision 框架的坐标系统：原点在左下角
        // 需要转换为标准坐标系统：原点在左上角
        let bodyBoundingBox = BoundingBox(
            x: Double(visionBox.origin.x),
            y: Double(1.0 - visionBox.origin.y - visionBox.height), // 翻转 Y 坐标
            width: Double(visionBox.size.width),
            height: Double(visionBox.size.height)
        )
        
        // 检查人体宽度是否超过屏幕的2/3
        let isBodyWidthExceedingThreshold = bodyBoundingBox.width > (2.0 / 3.0)
        
        LMLogger.log("👤 Person body width: \(String(format: "%.2f", bodyBoundingBox.width * 100))% of screen, threshold: 66.7%")
        
        // 检测人脸
        let faceBox = detectFaceInRegion(firstPerson.boundingBox)
        
        // 如果人体宽度超过2/3，必须检测到人脸
        if isBodyWidthExceedingThreshold {
            guard let detectedFaceBox = faceBox else {
                // 人体宽度超过2/3但没有检测到人脸，视为未检测到有效人物
                LMLogger.log("⚠️ Body width exceeds 2/3 but no face detected - treating as no person")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.personDetectionManagerDidNotDetectPerson(self)
                }
                return
            }
            
            // 使用人脸位置作为蓝色框的位置
            let result = PersonDetectionResult(
                boundingBox: detectedFaceBox,
                faceBoundingBox: detectedFaceBox,
                confidence: firstPerson.confidence,
                timestamp: Date(),
                isBodyWidthExceedingThreshold: true
            )
            
            LMLogger.log("✅ Body width exceeds 2/3, using face position for blue frame")
            
            // 回到主线程通知代理
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.personDetectionManager(self, didDetectPerson: result)
            }
        } else {
            // 人体宽度未超过2/3，使用人体位置
            let result = PersonDetectionResult(
                boundingBox: bodyBoundingBox,
                faceBoundingBox: faceBox,
                confidence: firstPerson.confidence,
                timestamp: Date(),
                isBodyWidthExceedingThreshold: false
            )
            
            LMLogger.log("✅ Body width within threshold, using body position for blue frame")
            
            // 回到主线程通知代理
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.personDetectionManager(self, didDetectPerson: result)
            }
        }
    }
    
    /// 检测指定区域内的人脸并返回人脸边界框
    /// - Parameter personBox: 人体检测的边界框
    /// - Returns: 人脸边界框（归一化坐标），如果未检测到则返回nil
    private func detectFaceInRegion(_ personBox: CGRect) -> BoundingBox? {
        // 获取人脸检测结果
        guard let faceObservations = faceDetectionRequest.results as? [VNFaceObservation] else {
            return nil
        }
        
        // 如果没有检测到任何人脸，返回 nil
        guard !faceObservations.isEmpty else {
            return nil
        }
        
        // 查找在人体区域内的人脸
        // 人脸应该在人体框的上半部分
        for face in faceObservations {
            let faceBox = face.boundingBox
            
            // 计算人脸中心点
            let faceCenterX = faceBox.origin.x + faceBox.width / 2
            let faceCenterY = faceBox.origin.y + faceBox.height / 2
            
            // 检查人脸中心点是否在人体框内
            if personBox.contains(CGPoint(x: faceCenterX, y: faceCenterY)) {
                LMLogger.log("✅ Face detected within person bounding box")
                
                // 转换人脸边界框坐标（Vision坐标系转换为标准坐标系）
                let faceBoundingBox = BoundingBox(
                    x: Double(faceBox.origin.x),
                    y: Double(1.0 - faceBox.origin.y - faceBox.height), // 翻转 Y 坐标
                    width: Double(faceBox.size.width),
                    height: Double(faceBox.size.height)
                )
                
                return faceBoundingBox
            }
            
            // 也检查人脸框是否与人体框有重叠
            if personBox.intersects(faceBox) {
                // 计算重叠面积
                let intersection = personBox.intersection(faceBox)
                let intersectionArea = intersection.width * intersection.height
                let faceArea = faceBox.width * faceBox.height
                
                // 如果重叠面积超过人脸面积的30%，认为人脸在人体区域内
                if intersectionArea / faceArea > 0.3 {
                    LMLogger.log("✅ Face detected with \(String(format: "%.1f", (intersectionArea / faceArea) * 100))% overlap")
                    
                    // 转换人脸边界框坐标
                    let faceBoundingBox = BoundingBox(
                        x: Double(faceBox.origin.x),
                        y: Double(1.0 - faceBox.origin.y - faceBox.height), // 翻转 Y 坐标
                        width: Double(faceBox.size.width),
                        height: Double(faceBox.size.height)
                    )
                    
                    return faceBoundingBox
                }
            }
        }
        
        LMLogger.log("❌ No face found in person bounding box")
        return nil
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
