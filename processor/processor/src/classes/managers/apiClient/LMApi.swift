//
//  LMApi.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import Foundation

struct LMApi {
    
    // MARK: - User APIs
    struct User {
        /// 用户注册
        static let register = "/v1/users"
        
        /// 获取当前用户信息
        static let info = "/v1/users/info"
        
        /// 修改密码
        static let changePassword = "/v1/users/password"
    }
    
    // MARK: - Auth APIs
    struct Auth {
        /// 用户登录
        static let login = "/v1/auth/tokens"
        
        /// 刷新 Token
        static let refreshToken = "/v1/auth/tokens"
        
        /// 用户登出
        static let logout = "/v1/auth/tokens"
    }
    
    // MARK: - Composition APIs
    struct Composition {
        /// 提交构图任务
        static let analyze = "/v1/composition/analyze"
        
        /// 获取任务建议图
        static func suggestions(taskId: String) -> String {
            return "/v1/composition/suggestions/\(taskId)"
        }
        
        /// 分页获取历史构图结果
        static let results = "/v1/composition/results"
        
        /// 确认建议图
        static let confirm = "/v1/composition/suggestions/confirm"
    }
}
