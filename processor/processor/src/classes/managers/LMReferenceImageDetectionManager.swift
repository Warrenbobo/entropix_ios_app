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

    // MARK: - Initialization

    init(personDetectionManager: LMPersonDetectionManager = .shared) {
        self.personDetectionManager = personDetectionManager
        self.personDetectionManager.delegate = self
    }

    // MARK: - Public Methods

    /// 检测Reference Image中的人物
    /// - Parameters:
    ///   - image: 待检测图片
    ///   - completion: 完成回调，返回检测到的bbox（归一化坐标）
    func detectPersonInReferenceImage(
        _ image: UIImage,
        completion: @escaping (CGRect?) -> Void
    ) {
        print("[Reference Detection] 开始检测Reference Image中的人物, 尺寸: \(image.size)")

        // 判断是否为横向图片
        let isLandscape = image.size.width > image.size.height
        if isLandscape {
            print("[Reference Detection] 横向图片，将旋转到竖屏方向后再识别")
        }

        // 保存完成回调
        currentCompletion = { bbox in
            if let bbox = bbox {
                print("[Reference Detection] 检测成功: \(bbox)")
            } else {
                print("[Reference Detection] 未检测到人物")
            }
            completion(bbox)
        }

        // 启动检测并处理图片
        // 对于横向图片，先旋转到竖屏方向（home键在右侧）再识别
        personDetectionManager.startDetection()
        personDetectionManager.processImage(image, shouldRotateToPortrait: isLandscape)
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

        // 停止检测
        personDetectionManager.stopDetection()

        // 回调结果
        currentCompletion?(bbox)
        currentCompletion = nil
    }

    func personDetectionManagerDidNotDetectPerson(_ manager: LMPersonDetectionManager) {
        // 停止检测
        personDetectionManager.stopDetection()

        // 未检测到人物
        currentCompletion?(nil)
        currentCompletion = nil
    }

    func personDetectionManager(_ manager: LMPersonDetectionManager, didFailWithError error: Error) {
        print("[Reference Detection] 检测失败: \(error.localizedDescription)")

        // 停止检测
        personDetectionManager.stopDetection()

        // 返回失败
        currentCompletion?(nil)
        currentCompletion = nil
    }
}
