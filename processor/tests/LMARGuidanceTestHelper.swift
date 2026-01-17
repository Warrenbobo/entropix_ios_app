//
//  LMARGuidanceTestHelper.swift
//  processor
//
//  AR Guidance 测试辅助类 - 用于调试人物检测和坐标转换
//

import UIKit
import Vision
import CoreImage

/// AR Guidance 测试辅助类
class LMARGuidanceTestHelper {
    
    // MARK: - Singleton
    static let shared = LMARGuidanceTestHelper()
    
    private init() {}
    
    // MARK: - Test Methods
    
    /// 测试图片的人物检测和坐标转换
    /// - Parameters:
    ///   - image: 待测试的图片
    ///   - completion: 完成回调，返回测试结果
    func testPersonDetection(
        image: UIImage,
        completion: @escaping (ARGuidanceTestResult) -> Void
    ) {
        var result = ARGuidanceTestResult()
        result.originalImageSize = image.size
        result.isLandscape = image.size.width > image.size.height
        
        // 预处理图片，确保格式兼容 Vision 框架
        guard let normalizedImage = normalizeImageForVision(image) else {
            result.error = "图片预处理失败"
            completion(result)
            return
        }
        
        guard let cgImage = normalizedImage.cgImage else {
            result.error = "无法获取 CGImage"
            completion(result)
            return
        }
        
        // 如果是横向图片，先旋转
        let imageToDetect: CGImage
        if result.isLandscape {
            if let rotated = rotateImageToPortrait(cgImage) {
                imageToDetect = rotated
                result.rotatedImageSize = CGSize(width: rotated.width, height: rotated.height)
            } else {
                result.error = "图片旋转失败"
                completion(result)
                return
            }
        } else {
            imageToDetect = cgImage
            result.rotatedImageSize = nil
        }
        
        // 执行人物检测
        detectPerson(in: imageToDetect) { [weak self] detectionResult in
            guard let self = self else { return }
            
            if var bbox = detectionResult {
                // 如果是横向图片，需要将 bbox 坐标转换回原始横向图片的坐标
                if result.isLandscape {
                    let originalBbox = self.convertBboxFromRotatedToOriginal(bbox)
                    bbox = originalBbox
                    result.originalBbox = originalBbox
                }
                
                result.detectedBbox = bbox
                result.detectionSuccess = true
                
                // 计算人物在原始图片中的位置描述
                let centerX = bbox.origin.x + bbox.width / 2
                let centerY = bbox.origin.y + bbox.height / 2
                
                // Vision 坐标系：原点在左下角，Y轴向上
                let horizontalPosition: String
                if centerX < 0.33 {
                    horizontalPosition = "左侧"
                } else if centerX > 0.67 {
                    horizontalPosition = "右侧"
                } else {
                    horizontalPosition = "中间"
                }
                
                let verticalPosition: String
                if centerY < 0.33 {
                    verticalPosition = "底部"
                } else if centerY > 0.67 {
                    verticalPosition = "顶部"
                } else {
                    verticalPosition = "中间"
                }
                
                result.personPositionDescription = "\(horizontalPosition)\(verticalPosition)"
                
                // 模拟坐标转换到画布
                let screenWidth: CGFloat = 393 // iPhone 14 Pro
                let availableHeight: CGFloat = 700 // 假设可用高度
                
                let canvasSize = self.calculateCanvasSize(
                    imageSize: result.originalImageSize,
                    screenWidth: screenWidth,
                    availableHeight: availableHeight
                )
                result.calculatedCanvasSize = canvasSize
                
                // 转换 bbox 到画布坐标
                let canvasBbox = self.convertBboxToCanvas(bbox: bbox, canvasSize: canvasSize)
                result.canvasBbox = canvasBbox
                
                // 检查是否超出画布边界
                result.isOutOfBounds = canvasBbox.minX < 0 || canvasBbox.minY < 0 ||
                   canvasBbox.maxX > canvasSize.width || canvasBbox.maxY > canvasSize.height
                
            } else {
                result.detectionSuccess = false
                result.error = "未检测到人物"
            }
            
            completion(result)
        }
    }
    
    /// 将旋转后图片的 bbox 坐标转换回原始横向图片的坐标
    /// 
    /// 图片被逆时针旋转 90° 后：
    /// - 原始横向图片的右边 -> 旋转后竖向图片的上边
    /// - 原始横向图片的下边 -> 旋转后竖向图片的左边
    /// 
    /// Vision 坐标系统：原点在左下角，Y轴向上
    /// 
    /// 逆时针旋转 90° 的坐标变换：
    /// 设原始点为 (X, Y)，旋转后为 (x, y)
    /// x = Y
    /// y = 1 - X
    /// 
    /// 逆操作（从旋转后坐标恢复原始坐标）：
    /// X = 1 - y
    /// Y = x
    /// 
    /// 对于 bbox：
    /// - 旋转后 bbox 的左下角 (rx, ry) 对应原始图片中的某个点
    /// - 旋转后 bbox 的宽高 (rw, rh) 在原始图片中变为 (rh, rw)
    /// - 原始 bbox 的左下角 X = 1 - (ry + rh) = 1 - ry - rh
    /// - 原始 bbox 的左下角 Y = rx
    private func convertBboxFromRotatedToOriginal(_ rotatedBbox: CGRect) -> CGRect {
        let rx = rotatedBbox.origin.x
        let ry = rotatedBbox.origin.y
        let rh = rotatedBbox.height
        let rw = rotatedBbox.width
        
        // 从逆时针旋转90°后的坐标恢复到原始坐标
        // 原始 bbox 的左下角：X = 1 - ry - rh, Y = rx
        // 原始 bbox 的尺寸：width = rh, height = rw
        let originalX = 1.0 - ry - rh
        let originalY = rx
        let originalWidth = rh
        let originalHeight = rw
        
        return CGRect(x: originalX, y: originalY, width: originalWidth, height: originalHeight)
    }
    
    // MARK: - Private Methods
    
    /// 将 UIImage 转换为 Vision 框架兼容的格式
    /// 解决 "Could not create inference context" 错误
    private func normalizeImageForVision(_ image: UIImage) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: image.size, format: {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.opaque = true
            return format
        }())
        
        let normalizedImage = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        
        return normalizedImage
    }
    
    /// 将横向图片旋转到竖屏方向（逆时针90度）
    private func rotateImageToPortrait(_ cgImage: CGImage) -> CGImage? {
        let width = cgImage.width
        let height = cgImage.height
        
        let rotatedWidth = height
        let rotatedHeight = width
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: rotatedWidth,
            height: rotatedHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        context.translateBy(x: CGFloat(rotatedWidth) / 2, y: CGFloat(rotatedHeight) / 2)
        context.rotate(by: -.pi / 2)
        context.draw(
            cgImage,
            in: CGRect(
                x: -CGFloat(width) / 2,
                y: -CGFloat(height) / 2,
                width: CGFloat(width),
                height: CGFloat(height)
            )
        )
        
        return context.makeImage()
    }
    
    /// 执行人物检测（先尝试全身检测，失败后尝试上半身检测）
    private func detectPerson(in cgImage: CGImage, completion: @escaping (CGRect?) -> Void) {
        // 使用 CIImage 作为输入，通常更兼容
        let ciImage = CIImage(cgImage: cgImage)
        
        // 先尝试全身检测
        if let bbox = performSyncDetectionWithCIImage(ciImage, upperBodyOnly: false) {
            completion(bbox)
            return
        }
        
        // 全身检测失败，尝试上半身检测
        if let bbox = performSyncDetectionWithCIImage(ciImage, upperBodyOnly: true) {
            completion(bbox)
            return
        }
        
        // 两种检测都失败
        completion(nil)
    }
    
    /// 使用 CIImage 同步执行人物检测
    private func performSyncDetectionWithCIImage(_ ciImage: CIImage, upperBodyOnly: Bool) -> CGRect? {
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = upperBodyOnly
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observations = request.results,
                  let firstPerson = observations.first else {
                return nil
            }
            
            return firstPerson.boundingBox
            
        } catch {
            return nil
        }
    }
    
    /// 同步执行人物检测（CGImage 版本，备用）
    private func performSyncDetection(in cgImage: CGImage, upperBodyOnly: Bool) -> CGRect? {
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = upperBodyOnly
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observations = request.results,
                  let firstPerson = observations.first else {
                return nil
            }
            
            return firstPerson.boundingBox
            
        } catch {
            return nil
        }
    }
    
    /// 计算画布尺寸
    private func calculateCanvasSize(
        imageSize: CGSize,
        screenWidth: CGFloat,
        availableHeight: CGFloat
    ) -> CGSize {
        let scale = screenWidth / imageSize.width
        let canvasWidth = screenWidth
        var canvasHeight = imageSize.height * scale
        
        if canvasHeight > availableHeight {
            let adjustedScale = availableHeight / imageSize.height
            return CGSize(width: imageSize.width * adjustedScale, height: availableHeight)
        }
        
        return CGSize(width: canvasWidth, height: canvasHeight)
    }
    
    /// 将 bbox 转换到画布坐标
    private func convertBboxToCanvas(bbox: CGRect, canvasSize: CGSize) -> CGRect {
        // Vision 坐标系统：原点在左下角，Y轴向上
        // UIKit 坐标系统：原点在左上角，Y轴向下
        
        // 翻转 Y 坐标
        let flippedY = 1.0 - bbox.origin.y - bbox.height
        
        // 转换到画布坐标
        let canvasX = bbox.origin.x * canvasSize.width
        let canvasY = flippedY * canvasSize.height
        let canvasBboxWidth = bbox.width * canvasSize.width
        let canvasBboxHeight = bbox.height * canvasSize.height
        
        return CGRect(x: canvasX, y: canvasY, width: canvasBboxWidth, height: canvasBboxHeight)
    }
}

// MARK: - Test Result

/// AR Guidance 测试结果
struct ARGuidanceTestResult {
    var originalImageSize: CGSize = .zero
    var isLandscape: Bool = false
    var rotatedImageSize: CGSize?
    var detectionSuccess: Bool = false
    var detectedBbox: CGRect?           // 最终使用的 bbox（对于横向图片，是转换后的原始坐标）
    var originalBbox: CGRect?           // 横向图片转换后的原始坐标 bbox
    var personPositionDescription: String?
    var calculatedCanvasSize: CGSize?
    var canvasBbox: CGRect?
    var isOutOfBounds: Bool = false
    var error: String?
    
    /// 生成测试报告
    func generateReport() -> String {
        var report = """
        ========================================
        AR Guidance 测试报告
        ========================================
        
        📷 原始图片尺寸: \(originalImageSize)
        📷 是否横向: \(isLandscape)
        """
        
        if let rotated = rotatedImageSize {
            report += "\n🔄 旋转后尺寸: \(rotated)"
        }
        
        report += "\n\n🔍 检测结果: \(detectionSuccess ? "成功" : "失败")"
        
        if let bbox = detectedBbox {
            report += """
            
            📦 最终 bbox (归一化): \(bbox)
            """
            
            if isLandscape, let originalBbox = originalBbox {
                report += """
                
                📦 原始横向坐标 bbox: \(originalBbox)
                """
            }
            
            report += """
            
            👤 人物位置: \(personPositionDescription ?? "未知")
            """
        }
        
        if let canvas = calculatedCanvasSize {
            report += "\n📐 画布尺寸: \(canvas)"
        }
        
        if let canvasBbox = canvasBbox {
            report += """
            
            📐 画布 bbox: \(canvasBbox)
            📐 画布 bbox 中心: (\(String(format: "%.1f", canvasBbox.midX)), \(String(format: "%.1f", canvasBbox.midY)))
            ⚠️ 超出边界: \(isOutOfBounds)
            """
        }
        
        if let error = error {
            report += "\n\n❌ 错误: \(error)"
            if error == "未检测到人物" {
                report += """
                
                💡 提示: Vision 框架可能无法检测到某些图片中的人物：
                   - 只显示上半身的图片
                   - 人物占比过小的图片
                   - 人物被遮挡的图片
                   - 图片质量较低的情况
                """
            }
        }
        
        report += "\n========================================"
        
        return report
    }
}

// MARK: - String Extension for Repeat

private extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
