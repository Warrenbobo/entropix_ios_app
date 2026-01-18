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
    case trial = "trial"  // 试用订阅
    case plus = "plus"
    case lifelong = "lifelong"
    
    var displayName: String {
        switch self {
        case .free:
            return LMText.profile.freePlan
        case .trial:
            return LMText.profile.trialPlan
        case .plus:
            return LMText.profile.plusPlan
        case .lifelong:
            return "Lifelong Plan"
        }
    }
    
    /// 是否为付费类型（包括试用）
    var isPaidType: Bool {
        switch self {
        case .trial, .plus, .lifelong:
            return true
        case .free:
            return false
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
    
    /// 订阅到期日期（解析后的 Date 对象）
    var subscriptionEndDateParsed: Date? {
        guard let endDateString = subscriptionEndDate else { return nil }
        
        let dateFormatters: [DateFormatter] = {
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd'T'HH:mm:ss'Z'",
                "yyyy-MM-dd"
            ]
            return formats.map { format in
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(identifier: "UTC")
                return formatter
            }
        }()
        
        for formatter in dateFormatters {
            if let date = formatter.date(from: endDateString) {
                return date
            }
        }
        return nil
    }
    
    /// 订阅是否已过期
    var isSubscriptionExpired: Bool {
        // lifelong 永不过期
        if subscriptionType == .lifelong {
            return false
        }
        
        // 没有到期日期，视为已过期（可以领取免费试用）
        guard let endDate = subscriptionEndDateParsed else {
            return true
        }
        
        return Date() > endDate
    }
    
    /// 是否为有效的付费用户（订阅类型为付费且未过期）
    var isPremiumUser: Bool {
        // lifelong 永久有效
        if subscriptionType == .lifelong {
            return true
        }
        
        // 检查订阅类型是否为付费类型，且未过期
        return subscriptionType.isPaidType && !isSubscriptionExpired
    }
    
    // 计算距离到期的天数（负数表示已过期）
    var daysUntilExpiration: Int? {
        // lifelong 不显示到期天数
        if subscriptionType == .lifelong {
            return nil
        }
        
        guard let expirationDate = subscriptionEndDateParsed else { return nil }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expiration = calendar.startOfDay(for: expirationDate)
        
        let components = calendar.dateComponents([.day], from: today, to: expiration)
        return components.day
    }
    
    /// 格式化的到期日期显示（如 "2026-02-10"）
    var formattedExpirationDate: String? {
        guard let date = subscriptionEndDateParsed else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
