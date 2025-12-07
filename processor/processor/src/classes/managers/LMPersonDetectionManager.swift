//
//  LMPersonDetectionManager.swift
//  processor
//
//  Created by muz on 2025/11/9.
//

import UIKit
import Vision
import AVFoundation

/// 人物检测结果
struct PersonDetectionResult {
    /// 检测到的人物边界框（归一化坐标 0-1）
    let boundingBox: BoundingBox
    
    // 人脸检测已禁用 - 仅使用人体检测
    // /// 人脸边界框（归一化坐标 0-1），如果检测到人脸
    // let faceBoundingBox: BoundingBox?
    
    /// 置信度 (0-1)
    let confidence: Float
    
    /// 检测时间戳
    let timestamp: Date
    
    // 人体宽度阈值检查已禁用
    // /// 人体宽度是否超过屏幕的2/3
    // let isBodyWidthExceedingThreshold: Bool
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
    
    // MARK: - Singleton
    static let shared = LMPersonDetectionManager()
    
    // MARK: - Properties
    weak var delegate: LMPersonDetectionManagerDelegate?
    
    private var isDetecting = false
    private var detectionQueue = DispatchQueue(label: "com.framaist.persondetection", qos: .userInitiated)
    private var lastDetectionTime: Date?
    private let detectionInterval: TimeInterval = 0.1 // 每100ms检测一次
    
    /// 当前使用的摄像头位置（用于方向计算）
    var currentCameraPosition: AVCaptureDevice.Position = .back
    
    // Vision 请求
    private lazy var personDetectionRequest: VNDetectHumanRectanglesRequest = {
        let request = VNDetectHumanRectanglesRequest { [weak self] request, error in
            self?.handleDetectionResults(request: request, error: error)
        }
        request.upperBodyOnly = false // 检测全身
        return request
    }()
    
    // 人脸检测请求（已禁用 - 仅使用人体检测）
    // private lazy var faceDetectionRequest: VNDetectFaceRectanglesRequest = {
    //     let request = VNDetectFaceRectanglesRequest()
    //     return request
    // }()
    
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
    /// - Parameters:
    ///   - sampleBuffer: 视频帧
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
    /// - Parameters:
    ///   - image: 待检测的图像
    ///   - shouldRotateToPortrait: 是否需要将横向图片旋转到竖屏方向（home键在右侧）
    func processImage(_ image: UIImage, shouldRotateToPortrait: Bool = false) {
        guard isDetecting else { return }
        
        guard let cgImage = image.cgImage else {
            LMLogger.log("❌ Failed to get CGImage from UIImage")
            return
        }
        
        detectionQueue.async { [weak self] in
            if shouldRotateToPortrait {
                // 检查是否为横向图片
                let isLandscape = image.size.width > image.size.height
                if isLandscape {
                    LMLogger.log("🔄 [Image Detection] Landscape image detected, rotating to portrait (home button on right)")
                    // 旋转图片到竖屏方向（逆时针90度，home键在右侧）
                    if let rotatedImage = self?.rotateImageToPortrait(cgImage) {
                        self?.performDetection(on: rotatedImage)
                        return
                    }
                }
            }
            
            // 不需要旋转或旋转失败，使用原图
            self?.performDetection(on: cgImage)
        }
    }
    
    /// 将横向图片旋转到竖屏方向（逆时针90度，home键在右侧）
    /// - Parameter cgImage: 原始CGImage
    /// - Returns: 旋转后的CGImage
    private func rotateImageToPortrait(_ cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        
        // 创建旋转后的尺寸（宽高互换）
        let rotatedWidth = height
        let rotatedHeight = width
        
        // 创建位图上下文
        let colorSpace = cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = cgImage.bitmapInfo.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: rotatedWidth,
            height: rotatedHeight,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            LMLogger.log("❌ Failed to create CGContext for rotation")
            return nil
        }
        
        // 移动到中心点
        context.translateBy(x: CGFloat(rotatedWidth) / 2, y: CGFloat(rotatedHeight) / 2)
        
        // 逆时针旋转90度（-π/2）
        context.rotate(by: -.pi / 2)
        
        // 绘制图片（从中心点偏移）
        context.draw(
            cgImage,
            in: CGRect(
                x: -CGFloat(width) / 2,
                y: -CGFloat(height) / 2,
                width: CGFloat(width),
                height: CGFloat(height)
            )
        )
        
        // 获取旋转后的图片
        guard let rotatedCGImage = context.makeImage() else {
            LMLogger.log("❌ Failed to create rotated CGImage")
            return nil
        }
        
        LMLogger.log("✅ [Image Detection] Image rotated: \(width)x\(height) -> \(rotatedWidth)x\(rotatedHeight)")
        
        return rotatedCGImage
    }
    
    // MARK: - Private Methods
    
    /// 执行检测（CVPixelBuffer）
    private func performDetection(on pixelBuffer: CVPixelBuffer) {
        // 获取设备方向并转换为 CGImagePropertyOrientation
        let deviceOrientation = LMDeviceOrientationManager.shared.currentOrientation
        let imageOrientation: CGImagePropertyOrientation
        guard deviceOrientation != .faceDown && deviceOrientation != .faceDown && deviceOrientation != .unknown else {
            // 过滤其他方向，防止出现识别错误
            return
        }
        imageOrientation = getImageOrientation(from: deviceOrientation)
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: imageOrientation,
            options: [:]
        )
        do {
            try handler.perform([personDetectionRequest])
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.personDetectionManager(self, didFailWithError: error)
            }
        }
    }
    
    /// 根据设备方向和摄像头位置获取图像方向
    /// - Parameter deviceOrientation: 设备方向
    /// - Returns: CGImagePropertyOrientation
    private func getImageOrientation(from deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        if currentCameraPosition == .front {
            switch deviceOrientation {
            case .portrait:
                return .leftMirrored
            case .portraitUpsideDown:
                return .rightMirrored
            case .landscapeLeft:
                return .upMirrored
            case .landscapeRight:
                return .downMirrored
            default:
                return .leftMirrored
            }
        } else {
            switch deviceOrientation {
            case .portrait:
                return .right
            case .portraitUpsideDown:
                return .left
            case .landscapeLeft:
                return .right
            case .landscapeRight:
                return .left
            default:
                return .right
            }
        }
    }
    
    /// 执行检测（CGImage）
    private func performDetection(on cgImage: CGImage) {
        // 对于静态图像，不设置方向信息
        // 让 Vision 使用图像的原始方向
        // 注意：这里的坐标系统应该与图像的显示方向一致
        
        LMLogger.log("📸 [Image Detection] CGImage size: \(cgImage.width) x \(cgImage.height)")
        
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            options: [:]
        )
        
        do {
            // 仅执行人体检测（人脸检测已禁用）
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
            // 未检测到人物，通知代理
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.personDetectionManagerDidNotDetectPerson(self)
            }
            return
        }
        
        // 转换人体边界框坐标
        let visionBox = firstPerson.boundingBox
        
        // Vision 框架的坐标系统：原点在左下角，Y轴向上
        // 保持 Vision 原始坐标，不进行任何转换
        // 后续在 UI 层根据需要进行坐标转换
        let bodyBoundingBox = BoundingBox(
            x: Double(visionBox.origin.x),
            y: Double(visionBox.origin.y),
            width: Double(visionBox.size.width),
            height: Double(visionBox.size.height)
        )
        
        // 人体宽度阈值检查已禁用 - 不再检查人体宽度
        // let isBodyWidthExceedingThreshold = bodyBoundingBox.width > (2.0 / 3.0)
        // LMLogger.log("👤 Person body width: \(String(format: "%.2f", bodyBoundingBox.width * 100))% of screen, threshold: 66.7%")
        
        // 人脸检测已禁用 - 仅使用人体检测
        // let faceBox = detectFaceInRegion(firstPerson.boundingBox)
        
        // 不再扩展人体 bbox，直接使用原始检测结果
        // let expandedBodyBox = expandBodyBoxToIncludeHead(bodyBox: bodyBoundingBox, faceBox: faceBox)
        
        LMLogger.log("📦 Body box: \(bodyBoundingBox)")
        
        // 人脸检测和宽度阈值检查已禁用
        // if isBodyWidthExceedingThreshold {
        //     guard faceBox != nil else {
        //         LMLogger.log("⚠️ Body width exceeds 2/3 but no face detected - treating as no person")
        //         DispatchQueue.main.async { [weak self] in
        //             guard let self = self else { return }
        //             self.delegate?.personDetectionManagerDidNotDetectPerson(self)
        //         }
        //         return
        //     }
        // }
        
        // 直接使用人体 bbox（不扩展，不包含人脸信息）
        let result = PersonDetectionResult(
            boundingBox: bodyBoundingBox,
            // faceBoundingBox: nil,  // 人脸检测已禁用
            confidence: firstPerson.confidence,
            timestamp: Date()
            // isBodyWidthExceedingThreshold: isBodyWidthExceedingThreshold  // 宽度阈值检查已禁用
        )
        
        LMLogger.log("✅ Using body bbox without face detection")
        
        // 回到主线程通知代理
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.personDetectionManager(self, didDetectPerson: result)
        }
    }
    
    // 人脸检测已禁用 - 不再扩展人体 bbox
    // /// 扩展人体 bbox 以包含头部区域
    // /// - Parameters:
    // ///   - bodyBox: 原始人体 bbox
    // ///   - faceBox: 检测到的人脸 bbox（可选）
    // /// - Returns: 扩展后的人体 bbox
    // private func expandBodyBoxToIncludeHead(bodyBox: BoundingBox, faceBox: BoundingBox?) -> BoundingBox {
    //     guard let face = faceBox else {
    //         // 如果没有检测到人脸，向上扩展 20% 的人体高度作为头部区域
    //         let headExpansion = bodyBox.height * 0.2
    //         return BoundingBox(
    //             x: bodyBox.x,
    //             y: max(0, bodyBox.y - headExpansion), // 确保不超出边界
    //             width: bodyBox.width,
    //             height: min(1.0, bodyBox.height + headExpansion) // 确保不超出边界
    //         )
    //     }
    //     
    //     // 如果检测到人脸，确保 bbox 包含人脸和额外的头部空间
    //     let faceTop = face.y
    //     let faceHeight = face.height
    //     
    //     // 在人脸上方添加额外空间（人脸高度的 30%）作为头顶区域
    //     let headTopMargin = faceHeight * 0.3
    //     let expandedTop = max(0, faceTop - headTopMargin)
    //     
    //     // 计算扩展后的 bbox
    //     let bodyTop = bodyBox.y
    //     let bodyBottom = bodyBox.y + bodyBox.height
    //     
    //     // 使用人脸顶部（含头顶空间）和人体底部
    //     let newTop = min(expandedTop, bodyTop) // 取更靠上的位置
    //     let newBottom = bodyBottom
    //     let newHeight = newBottom - newTop
    //     
    //     // 保持原始宽度和 X 坐标
    //     return BoundingBox(
    //         x: bodyBox.x,
    //         y: newTop,
    //         width: bodyBox.width,
    //         height: min(1.0, newHeight) // 确保不超出边界
    //     )
    // }
    
    // 人脸检测已禁用 - 不再检测人脸
    // /// 检测指定区域内的人脸并返回人脸边界框
    // /// - Parameter personBox: 人体检测的边界框
    // /// - Returns: 人脸边界框（归一化坐标），如果未检测到则返回nil
    // private func detectFaceInRegion(_ personBox: CGRect) -> BoundingBox? {
    //     // 获取人脸检测结果
    //     guard let faceObservations = faceDetectionRequest.results else {
    //         return nil
    //     }
    //     
    //     // 如果没有检测到任何人脸，返回 nil
    //     guard !faceObservations.isEmpty else {
    //         return nil
    //     }
    //     
    //     // 查找在人体区域内的人脸
    //     // 人脸应该在人体框的上半部分
    //     for face in faceObservations {
    //         let faceBox = face.boundingBox
    //         
    //         // 计算人脸中心点
    //         let faceCenterX = faceBox.origin.x + faceBox.width / 2
    //         let faceCenterY = faceBox.origin.y + faceBox.height / 2
    //         
    //         // 检查人脸中心点是否在人体框内
    //         if personBox.contains(CGPoint(x: faceCenterX, y: faceCenterY)) {
    //             LMLogger.log("✅ Face detected within person bounding box")
    //             
    //             // 保持 Vision 原始坐标，不进行任何转换
    //             let faceBoundingBox = BoundingBox(
    //                 x: Double(faceBox.origin.x),
    //                 y: Double(faceBox.origin.y),
    //                 width: Double(faceBox.size.width),
    //                 height: Double(faceBox.size.height)
    //             )
    //             
    //             return faceBoundingBox
    //         }
    //         
    //         // 也检查人脸框是否与人体框有重叠
    //         if personBox.intersects(faceBox) {
    //             // 计算重叠面积
    //             let intersection = personBox.intersection(faceBox)
    //             let intersectionArea = intersection.width * intersection.height
    //             let faceArea = faceBox.width * faceBox.height
    //             
    //             // 如果重叠面积超过人脸面积的30%，认为人脸在人体区域内
    //             if intersectionArea / faceArea > 0.3 {
    //                 LMLogger.log("✅ Face detected with \(String(format: "%.1f", (intersectionArea / faceArea) * 100))% overlap")
    //                 
    //                 // 保持 Vision 原始坐标，不进行任何转换
    //                 let faceBoundingBox = BoundingBox(
    //                     x: Double(faceBox.origin.x),
    //                     y: Double(faceBox.origin.y),
    //                     width: Double(faceBox.size.width),
    //                     height: Double(faceBox.size.height)
    //                 )
    //                 
    //                 return faceBoundingBox
    //             }
    //         }
    //     }
    //     
    //     LMLogger.log("❌ No face found in person bounding box")
    //     return nil
    // }
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
