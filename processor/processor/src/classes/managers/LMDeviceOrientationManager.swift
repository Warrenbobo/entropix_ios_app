//
//  LMDeviceOrientationManager.swift
//  processor
//
//  设备物理方向检测管理器
//  使用加速度计检测设备的物理方向，独立于UI方向
//

import Foundation
import CoreMotion
import UIKit

/// 设备方向变化通知
extension Notification.Name {
    static let devicePhysicalOrientationDidChange = Notification.Name("devicePhysicalOrientationDidChange")
}

/// 设备物理方向检测管理器
class LMDeviceOrientationManager {
    
    // MARK: - Singleton
    static let shared = LMDeviceOrientationManager()
    
    // MARK: - Properties
    private var motionManager: CMMotionManager?
    private var isMonitoring = false
    
    /// 当前设备方向（只读，通过加速度计实时更新）
    private(set) var currentOrientation: UIDeviceOrientation = .portrait {
        didSet {
            if oldValue != currentOrientation {
                // 发送方向变化通知
                NotificationCenter.default.post(
                    name: .devicePhysicalOrientationDidChange,
                    object: nil,
                    userInfo: ["orientation": currentOrientation]
                )
                LMLogger.log("📱 Device orientation changed: \(oldValue.rawValue) -> \(currentOrientation.rawValue)")
            }
        }
    }
    
    // MARK: - Initialization
    private init() {
        motionManager = CMMotionManager()
    }
    
    // MARK: - Public Methods
    
    /// 开始监听设备物理方向
    func startMonitoring() {
        guard !isMonitoring else {
            LMLogger.log("⚠️ Device orientation monitoring already started")
            return
        }
        
        guard let motionManager = motionManager else {
            LMLogger.log("❌ Motion manager not initialized")
            return
        }
        
        guard motionManager.isAccelerometerAvailable else {
            LMLogger.log("❌ Accelerometer not available on this device")
            return
        }
        
        // 设置更新频率（每秒10次）
        motionManager.accelerometerUpdateInterval = 0.1
        
        // 开始接收加速度计数据
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self else { return }
            
            if let error = error {
                LMLogger.log("❌ Accelerometer error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else { return }
            
            // 根据加速度计数据计算设备方向
            let newOrientation = self.calculateOrientation(from: data.acceleration)
            
            // 更新当前方向（只在真正改变时触发 didSet）
            self.currentOrientation = newOrientation
        }
        
        isMonitoring = true
        LMLogger.log("✅ Started monitoring device physical orientation using accelerometer")
    }
    
    /// 停止监听设备物理方向
    func stopMonitoring() {
        guard isMonitoring else {
            LMLogger.log("⚠️ Device orientation monitoring not started")
            return
        }
        
        motionManager?.stopAccelerometerUpdates()
        isMonitoring = false
        LMLogger.log("🛑 Stopped monitoring device physical orientation")
    }
    
    /// 获取当前方向对应的旋转角度（弧度）
    /// - Returns: 旋转角度（弧度）
    func getCurrentRotationAngle() -> CGFloat {
        return calculateRotationAngle(for: currentOrientation)
    }
    
    // MARK: - Private Methods
    
    /// 根据加速度计数据计算设备方向
    /// - Parameter acceleration: 加速度数据
    /// - Returns: 设备方向
    private func calculateOrientation(from acceleration: CMAcceleration) -> UIDeviceOrientation {
        let x = acceleration.x
        let y = acceleration.y
        let z = acceleration.z
        
        // 使用阈值避免频繁切换（防抖动）
        let threshold: Double = 0.5
        
        // 判断设备是否平放（FaceUp 或 FaceDown）
        if abs(z) > 0.8 {
            // z轴主导，设备平放
            return z > 0 ? .faceUp : .faceDown
        }
        
        // 判断竖屏或横屏方向
        if abs(y) > abs(x) {
            // y轴主导，竖屏方向
            if y > threshold {
                return .portraitUpsideDown
            } else if y < -threshold {
                return .portrait
            }
        } else {
            // x轴主导，横屏方向
            if x > threshold {
                return .landscapeRight
            } else if x < -threshold {
                return .landscapeLeft
            }
        }
        
        // 如果加速度变化不明显，保持当前方向
        return currentOrientation
    }
    
    /// 计算旋转角度（根据设备方向）
    /// - Parameter orientation: 设备方向
    /// - Returns: 旋转角度（弧度）
    private func calculateRotationAngle(for orientation: UIDeviceOrientation) -> CGFloat {
        switch orientation {
        case .portrait:
            return 0 // 0°
        case .landscapeLeft:
            return .pi / 2 // 90°
        case .portraitUpsideDown:
            return .pi // 180°
        case .landscapeRight:
            return -.pi / 2 // -90° (270°)
        default:
            return 0
        }
    }
}
