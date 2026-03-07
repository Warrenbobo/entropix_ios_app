//
//  LMReferenceImageDetectionManager.swift
//  processor
//
//  Created by Kiro on 2025-01-XX.
//

import UIKit

/// Reference Image检测管理器 - 专门处理静态图片的人物检测
class LMReferenceImageDetectionManager: LMPersonDetectionManagerDelegate {

    // MARK: - Properties

    /// 人物检测管理器
    private let personDetectionManager: LMPersonDetectionManager

    /// 检测队列
    private let detectionQueue = DispatchQueue(label: "com.processor.referenceImageDetection", qos: .userInitiated)

    /// 当前检测的完成回调
    private var currentCompletion: ((CGRect?) -> Void)?
    
    /// 当前检测的图片是否为横向（用于坐标转换）
    private var isCurrentImageLandscape: Bool = false

    // MARK: - Initialization

    init(personDetectionManager: LMPersonDetectionManager = .shared) {
        self.personDetectionManager = personDetectionManager
        self.personDetectionManager.delegate = self
    }

    // MARK: - Public Methods

    /// 检测Reference Image中的人物
    /// - Parameters:
    ///   - image: 待检测图片
    ///   - completion: 完成回调，返回检测到的bbox（归一化坐标，基于原始图片方向）
    func detectPersonInReferenceImage(
        _ image: UIImage,
        completion: @escaping (CGRect?) -> Void
    ) {
        // 判断是否为横向图片
        isCurrentImageLandscape = image.size.width > image.size.height

        // 保存完成回调
        currentCompletion = { bbox in
            completion(bbox)
        }

        // 启动检测并处理图片
        // 对于横向图片，先旋转到竖屏方向（home键在右侧）再识别
        personDetectionManager.startDetection()
        personDetectionManager.processImage(image, shouldRotateToPortrait: isCurrentImageLandscape)
    }
    
    /// 取消当前正在进行的检测（如果有）
    /// 注意：Vision 请求无法强制中断，但会清空 completion，避免回调影响已切换的页面状态
    func cancelCurrentDetection() {
        currentCompletion = nil
        personDetectionManager.stopDetection()
        isCurrentImageLandscape = false
        LMLogger.log("🛑 [Reference Detection] Current detection cancelled")
    }

    // MARK: - LMPersonDetectionManagerDelegate

    func personDetectionManager(_ manager: LMPersonDetectionManager, didDetectPerson result: PersonDetectionResult) {
        // 转换归一化坐标为 CGRect
        let bbox = CGRect(
            x: result.boundingBox.x,
            y: result.boundingBox.y,
            width: result.boundingBox.width,
            height: result.boundingBox.height
        )

        // 注意：不再将 bbox 坐标转换回原始横向坐标
        // 因为 ARGuidanceView 现在使用旋转后的竖向尺寸作为画布
        // bbox 坐标直接对应旋转后的竖向图片，当设备旋转到横向时，ARGuidanceView 旋转后视觉效果正确
        
        LMLogger.log("📦 [Reference Detection] bbox detected: \(bbox), isLandscape: \(isCurrentImageLandscape)")

        // 停止检测
        personDetectionManager.stopDetection()

        // 回调结果
        currentCompletion?(bbox)
        currentCompletion = nil
    }
    
    /// 将旋转后图片的 bbox 坐标转换回原始横向图片的坐标
    /// 
    /// 图片被逆时针旋转 90°（context.rotate(by: -.pi / 2)）后：
    /// - 原始横向图片的右边 -> 旋转后竖向图片的上边
    /// - 原始横向图片的上边 -> 旋转后竖向图片的左边
    /// - 原始横向图片的左边 -> 旋转后竖向图片的下边
    /// - 原始横向图片的下边 -> 旋转后竖向图片的右边
    /// 
    /// Vision 坐标系统：原点在左下角，Y轴向上
    /// 
    /// 坐标映射（逆时针旋转90°）：
    /// - 原始 (1, 0) -> 旋转后 (0, 0)
    /// - 原始 (1, 1) -> 旋转后 (1, 0)
    /// - 原始 (0, 1) -> 旋转后 (1, 1)
    /// - 原始 (0, 0) -> 旋转后 (0, 1)
    /// 
    /// 变换公式：
    /// x = Y
    /// y = 1 - X
    /// 
    /// 逆变换（从旋转后坐标恢复原始坐标）：
    /// X = 1 - y
    /// Y = x
    /// 
    /// 对于 bbox：
    /// - 旋转后 bbox 的左下角 (rx, ry)，宽高 (rw, rh)
    /// - 原始图片中宽高变为 (rh, rw)
    /// - 原始 bbox 的左下角 X = 1 - (ry + rh)
    /// - 原始 bbox 的左下角 Y = rx
    private func convertBboxFromRotatedToOriginal(_ rotatedBbox: CGRect) -> CGRect {
        let rx = rotatedBbox.origin.x
        let ry = rotatedBbox.origin.y
        let rw = rotatedBbox.width
        let rh = rotatedBbox.height
        
        // 从逆时针旋转90°后的坐标恢复到原始坐标
        let originalX = 1.0 - ry - rh
        let originalY = rx
        let originalWidth = rh
        let originalHeight = rw
        
        return CGRect(x: originalX, y: originalY, width: originalWidth, height: originalHeight)
    }

    func personDetectionManagerDidNotDetectPerson(_ manager: LMPersonDetectionManager) {
        // 停止检测
        personDetectionManager.stopDetection()

        // 未检测到人物
        currentCompletion?(nil)
        currentCompletion = nil
    }

    func personDetectionManager(_ manager: LMPersonDetectionManager, didFailWithError error: Error) {
        // 停止检测
        personDetectionManager.stopDetection()

        // 返回失败
        currentCompletion?(nil)
        currentCompletion = nil
    }
}
