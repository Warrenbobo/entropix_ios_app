//
//  LMUserRegisterRequest.swift
//  processor
//
//  用户注册请求模型
//

import Foundation

struct LMUserRegisterRequest: Codable {
    let identifier: String
    let password: String
}
