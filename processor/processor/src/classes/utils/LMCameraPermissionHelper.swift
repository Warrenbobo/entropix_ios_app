//
//  LMCameraPermissionHelper.swift
//  processor
//
//  相机权限辅助工具
//

import UIKit
import AVFoundation

class LMCameraPermissionHelper {
    
    /// 检查并请求相机权限（用于相机入口按钮点击时）
    /// - Parameters:
    ///   - from: 当前视图控制器
    ///   - completion: 完成回调，返回是否有权限
    static func checkAndRequestPermission(from viewController: UIViewController, completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            // 已授权，直接返回 true
            completion(true)
            
        case .notDetermined:
            // 首次请求权限
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
            
        case .denied, .restricted:
            // 权限被拒绝或受限，提示用户前往设置
            DispatchQueue.main.async {
                showSettingsAlert(from: viewController)
                completion(false)
            }
            
        @unknown default:
            DispatchQueue.main.async {
                showSettingsAlert(from: viewController)
                completion(false)
            }
        }
    }
    
    /// 显示前往设置的提示框
    private static func showSettingsAlert(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "Please enable camera access in Settings to use the camera feature.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        viewController.present(alert, animated: true)
    }
    
    /// 检查相机权限状态（不请求权限）
    static func hasPermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
}
