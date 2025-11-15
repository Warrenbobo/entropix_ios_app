//
//  LMEmailVerificationRequest.swift
//  processor
//
//  邮箱验证请求模型
//

import Foundation

/// 发送验证邮件请求
struct LMEmailVerificationRequest: Codable {
    let email: String
}

/// 验证邮箱验证码请求
struct LMVerifyEmailCodeRequest: Codable {
    let email: String
    let verificationCode: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case verificationCode = "verification_code"
    }
}

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
