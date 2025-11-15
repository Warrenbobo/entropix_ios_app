//
//  LMDeviceInfo.swift
//  processor
//
//  设备信息模型
//

import Foundation
import UIKit

struct LMDeviceInfo: Codable {
    let deviceId: String
    let deviceModel: String
    let systemVersion: String
    let appVersion: String
    
    enum CodingKeys: String, CodingKey {
        case deviceId = "device_id"
        case deviceModel = "device_model"
        case systemVersion = "system_version"
        case appVersion = "app_version"
    }
    
    /// 获取当前设备信息
    static func current() -> LMDeviceInfo {
        return LMDeviceInfo(
            deviceId: LMPackageManager.deviceId,
            deviceModel: UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            appVersion: LMPackageManager.package.version
        )
    }
}
