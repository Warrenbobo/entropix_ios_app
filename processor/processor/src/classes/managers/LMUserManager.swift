//
//  LMUserManager.swift
//  processor
//
//  Created by muz on 2025/10/12.
//

import Foundation

struct LMUserManager {
    
    /// 当前是否为已登陆用户
    static var isSignIn: Bool {
        return userModel != nil
    }
    
    
    /// 用户数据
    static var userModel: LMUserModel?
    
    
    private static func cachedUserModelData() {
        guard let model = userModel else { return }
        if let modelData = try? JSONEncoder().encode(model) {
            UserDefaults.standard.set(modelData, forKey: cachedUserModelKey)
        }
    }
    
    static func loadCachedUserModelData() {
        if let data = UserDefaults.standard.data(forKey: cachedUserModelKey),
           let model = try? JSONDecoder().decode(LMUserModel.self, from: data) {
            userModel = model
        }
    }
    
    private static let cachedUserModelKey = "com.processor.userModel"
}
