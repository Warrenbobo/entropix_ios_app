//
//  LMLoginResponse.swift
//  processor
//
//  登录响应模型
//

import Foundation

struct LMLoginResponse: Codable {
    var accessToken: String?
    var refreshToken: String?
    var user: LMUserModel?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}
