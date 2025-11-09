//
//  LMRefreshTokenResponse.swift
//  processor
//
//  刷新 Token 响应模型
//

import Foundation

struct LMRefreshTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
