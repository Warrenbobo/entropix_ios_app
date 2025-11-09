//
//  LMChangePasswordRequest.swift
//  processor
//
//  修改密码请求模型
//

import Foundation

struct LMChangePasswordRequest: Codable {
    let oldPassword: String
    let newPassword: String
    
    enum CodingKeys: String, CodingKey {
        case oldPassword = "old_password"
        case newPassword = "new_password"
    }
}
