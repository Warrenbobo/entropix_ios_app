//
//  LMCameraStreamDetectionManager.swift
//  processor
//
//  Created by Kiro on 2025-01-XX.
//

import UIKit
import CoreMedia
import AVFoundation

/// 相机流检测管理器 - 专门处理实时相机流的人物检测
class LMCameraStreamDetectionManager: LMPersonDetectionManagerDelegate {
    
    // MARK: - Properties
    
    /// 人物检测管理器
    private let personDetectionManager: LMPersonDetectionManager
    
    /// 检测队列
    private let detectionQueue = DispatchQueue(label: "com.processor.cameraStreamDetection", qos: .userInitiated)
    
    /// 是否正在检测
    private(set) var isDetecting: Bool = false
    
    /// 上次检测时间
    private var lastDetectionTime: TimeInterval = 0
    
    /// 检测间隔（秒）- 控制检测频率
    private let detectionInterval: TimeInterval = 0.2  // 每秒5帧
    
    /// 方向匹配状态
    private var isOrientationMatched: Bool = false
    
    /// 检测结果回调
    var onDetectionResult: ((CGRect?, Float) -> Void)?
    
    // MARK: - Initialization
    
    init(personDetectionManager: LMPersonDetectionManager = .shared) {
        self.personDetectionManager = personDetectionManager
        self.personDetectionManager.delegate = self
    }
    
    // MARK: - Public Methods
    
    /// 设置方向匹配状态
    /// - Parameter matched: 是否匹配
    func setOrientationMatched(_ matched: Bool) {
        isOrientationMatched = matched
        if !matched {
            stopRealtimeDetection()
        }
        print("[Camera Stream Detection] 方向匹配状态: \(matched)")
    }
    
    /// 开始实时检测
    /// - Parameter sampleBuffer: 相机输出的样本缓冲区
    func startRealtimeDetection(from sampleBuffer: CMSampleBuffer) {
        // 检查方向是否匹配
        guard isOrientationMatched else {
            return
        }
        
        // 控制检测频率
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastDetectionTime >= detectionInterval else {
            return
        }
        
        lastDetectionTime = currentTime
        
        // 如果还没开始检测，启动检测
        if !isDetecting {
            personDetectionManager.startDetection()
            isDetecting = true
        }
        
        // 处理视频帧
        personDetectionManager.processVideoFrame(sampleBuffer)
    }
    
    /// 停止实时检测
    func stopRealtimeDetection() {
        if isDetecting {
            personDetectionManager.stopDetection()
            isDetecting = false
        }
        lastDetectionTime = 0
        print("[Camera Stream Detection] 停止实时检测")
    }
    
    /// 重置检测状态
    func reset() {
        stopRealtimeDetection()
        isOrientationMatched = false
        onDetectionResult = nil
        print("[Camera Stream Detection] 重置检测状态")
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
        
        // 回调检测结果
        onDetectionResult?(bbox, result.confidence)
    }
    
    func personDetectionManagerDidNotDetectPerson(_ manager: LMPersonDetectionManager) {
        // 未检测到人物
        onDetectionResult?(nil, 0.0)
    }
    
    func personDetectionManager(_ manager: LMPersonDetectionManager, didFailWithError error: Error) {
        print("[Camera Stream Detection] 检测失败: \(error.localizedDescription)")
        onDetectionResult?(nil, 0.0)
    }
}
