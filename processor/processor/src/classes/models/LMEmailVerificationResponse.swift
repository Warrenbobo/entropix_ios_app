//
//  LMEmailVerificationResponse.swift
//  processor
//
//  邮箱验证请求模型
//

import Foundation


/// 邮箱验证响应
struct LMEmailVerificationResponse: Codable {
    let status: String  // "pending", "sent", "verified"
    let message: String
    let expiresIn: Int?  // 验证码有效期（秒）
    
    enum CodingKeys: String, CodingKey {
        case status
        case message
        case expiresIn = "expires_in"
    }
}
