//
//  LMAppleLoginRequest.swift
//  processor
//
//  Apple登录请求模型
//

import Foundation

/// Apple登录/注册请求
struct LMAppleLoginRequest: Codable {
    let provider: String = "apple"
    let uid: String
    let fullName: String?
    let email: String?
    let idToken: String
    let deviceInfo: LMDeviceInfo
    
    enum CodingKeys: String, CodingKey {
        case provider
        case uid
        case fullName = "full_name"
        case email
        case idToken = "id_token"
        case deviceInfo = "device_info"
    }
}

/// Apple登录响应
struct LMAppleLoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenExpireAt: String
    let user: LMUserInfo
    let subscriptionType: String
    let inspirePoints: Int
    let isNewUser: Bool  // 是否为新注册用户
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenExpireAt = "token_expire_at"
        case user
        case subscriptionType = "subscription_type"
        case inspirePoints = "inspire_points"
        case isNewUser = "is_new_user"
    }
}
