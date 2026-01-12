//
//  LMApi.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import Foundation

// MARK: - Type Aliases for API Callbacks

/// 通用 API 回调类型别名
/// 所有 API 回调统一使用此类型，T 为响应数据的具体类型
typealias LMApiCallback<T: Codable> = (LMApiResponseModel<T>) -> Void

struct LMApi {
    
    // MARK: - User APIs
    struct User {
        /// 用户注册（邮箱+密码）
        static let register = "/v1/users"
        
        /// 获取当前用户信息
        static let info = "/v1/users/info"
        
        /// 修改密码（需要旧密码）
        static let changePassword = "/v1/users/password"
        
        /// 更新用户资料
        static let updateProfile = "/v1/users"
        
        /// 更新用户头像
        static let updateAvatar = "/v1/users/avatar"
    }
    
    // MARK: - Auth APIs
    struct Auth {
        /// 用户登录（邮箱+密码）
        static let login = "/v1/auth/tokens"
        
        /// 刷新 Token
        static let refreshToken = "/v1/auth/tokens"
        
        /// Apple注册
        static let appleRegister = "/v1/auth/apple/users"
        
        /// Apple登录
        static let appleLogin = "/v1/auth/apple/tokens"
        
        /// 用户登出
        static let logout = "/v1/auth/tokens"
        
        /// Guest 用户注册
        static let guestRegister = "/v1/auth/guest/users"
        
        /// Guest 用户登录
        static let guestLogin = "/v1/auth/guest/tokens"
    }
    
    // MARK: - Subscription APIs
    struct Subscription {
        /// 领取免费试用（14天）
        static let freeTrial = "/v1/subscriptions/free-trial"
    }
    
    // MARK: - Composition APIs
    struct Composition {
        /// 提交构图任务
        static let analyze = "/v1/composition/analyze"
        
        /// 获取任务建议图（轮询：获取所有建议图）
        static func suggestions(taskId: String) -> String {
            return "/v1/composition/suggestions/\(taskId)"
        }
        
        /// 查询任务概要（轮询：查询任务概要）
        static func taskDetail(taskId: String) -> String {
            return "/v1/composition/tasks/\(taskId)"
        }
        
        /// 获取任务 Job 列表
        static func jobList(taskId: String) -> String {
            return "/v1/composition/tasks/\(taskId)/jobs"
        }
        
        /// 按 Job 轮询建议图
        static func jobDetail(taskId: String, jobId: String) -> String {
            return "/v1/composition/tasks/\(taskId)/jobs/\(jobId)"
        }
        
        /// 分页获取历史构图结果
        static let results = "/v1/composition/results"
        
        /// 确认建议图
        static let confirm = "/v1/composition/suggestions/confirm"
    }
    
    struct Terms {
        static let service = "https://legal.framaist.entropixai.com/terms-of-use.html"
        
        static let privacy = "https://legal.framaist.entropixai.com/privacy-policy.html"
    }
    
    // MARK: - Notification APIs
    struct Notification {
        /// 拉取通知列表（轮询）
        static let list = "/v1/notifications"
        
        /// 标记已读
        static let markRead = "/v1/notifications/read"
    }
}
