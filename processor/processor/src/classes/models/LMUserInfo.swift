//
//  LMUserInfo.swift
//  processor
//
//  用户信息模型
//

import Foundation

struct LMUserInfo: Codable {
    let userId: String
    let username: String
    let email: String
    let subscription: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case email
        case subscription
    }
}
