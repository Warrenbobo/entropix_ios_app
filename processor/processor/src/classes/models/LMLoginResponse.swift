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
    let user: LMUserInfo
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}
