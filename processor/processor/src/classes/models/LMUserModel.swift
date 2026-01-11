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
    var subscriptionEndDate: String?  // 订阅到期日期
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
    
    // 计算距离到期的天数
    var daysUntilExpiration: Int? {
        guard let endDateString = subscriptionEndDate else { return nil }
        
        // 尝试解析日期字符串（支持多种格式）
        let dateFormatters: [DateFormatter] = {
            let formats = ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd"]
            return formats.map { format in
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                return formatter
            }
        }()
        
        var endDate: Date?
        for formatter in dateFormatters {
            if let date = formatter.date(from: endDateString) {
                endDate = date
                break
            }
        }
        
        guard let expirationDate = endDate else { return nil }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expiration = calendar.startOfDay(for: expirationDate)
        
        let components = calendar.dateComponents([.day], from: today, to: expiration)
        return components.day
    }
    
    // Codable实现（avatar需要特殊处理）
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case nickname
        case email
        case subscription
        case subscriptionEndDate = "subscription_end_date"
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
