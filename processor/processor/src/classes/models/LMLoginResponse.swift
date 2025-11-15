//
//  LMLoginResponse.swift
//  processor
//
//  登录响应模型
//

import Foundation

struct LMLoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenExpireAt: String
    let user: LMUserInfo
    let subscriptionType: String
    let inspirePoints: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenExpireAt = "token_expire_at"
        case user
        case subscriptionType = "subscription_type"
        case inspirePoints = "inspire_points"
    }
}
