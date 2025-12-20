//
//  LMUserModel.swift
//  processor
//
//  统一的用户模型文件
//

import UIKit

// MARK: - Subscription Type

enum SubscriptionType: String, Codable {
    case free = "free"
    case plus = "plus"
    case lifelong = "lifelong"
    
    var displayName: String {
        switch self {
        case .free:
            return LMText.profile.freePlan
        case .plus:
            return LMText.profile.plusPlan
        case .lifelong:
            return "Lifelong Plan"
        }
    }
}

// MARK: - LMUser (完整用户模型)

struct LMUserModel: Codable {
    var userId: String
    var username: String?
    var nickname: String?
    var email: String?
    var avatar: String?
    var subscription: String?
    var inspirePoints: Int?
    var isGuest: Bool? // Guest 用户标识
    var birthDate: String?
    var language: String?
    
    var subscriptionType: SubscriptionType {
        return SubscriptionType(rawValue: subscription ?? "") ?? .free
    }
    
    // 是否为付费用户
    var isPremiumUser: Bool {
        return subscriptionType == .plus || subscriptionType == .lifelong
    }
    
    // Codable实现（avatar需要特殊处理）
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case nickname
        case email
        case subscription
        case avatar
        case inspirePoints
        case isGuest = "is_guest"
        case birthDate = "date_of_birth"
        case language
    }
    
    // 便捷初始化方法
    static func sample(
        userId: String,
        username: String? = nil,
        nickname: String? = nil,
        email: String? = nil,
        avatar: String? = nil,
        subscription: String = "",
        isGuest: Bool = true
    ) -> LMUserModel {
        return LMUserModel(userId: userId,
                           username: username,
                           nickname: nickname,
                           email: email,
                           avatar: avatar,
                           subscription: subscription,
                           isGuest: isGuest)
    }
}
