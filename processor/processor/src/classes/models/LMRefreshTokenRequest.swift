//
//  LMRefreshTokenRequest.swift
//  processor
//
//  刷新 Token 请求模型
//

import Foundation

struct LMRefreshTokenRequest: Codable {
    let refreshToken: String
    
    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}
