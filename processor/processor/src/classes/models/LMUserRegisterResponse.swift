//
//  LMUserRegisterResponse.swift
//  processor
//
//  用户注册请求模型
//

import Foundation

/// 注册响应
struct LMUserRegisterResponse: Codable {
    let status: String  // "pending", "success"
    let message: String
    let needEmailVerification: Bool
    let user: LMUserInfo?
    
    enum CodingKeys: String, CodingKey {
        case status
        case message
        case needEmailVerification = "need_email_verification"
        case user
    }
}
