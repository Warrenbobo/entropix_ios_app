//
//  LMUserLoginRequest.swift
//  processor
//
//  用户登录请求模型
//

import Foundation

struct LMUserLoginRequest: Codable {
    let identifier: String
    let password: String
}
