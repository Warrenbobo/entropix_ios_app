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
    var avatar: UIImage?
    var subscriptionType: SubscriptionType
    var inspirePoints: Int
    var subscriptionExpiryDate: Date?
    
    // 计算到期天数
    var subscriptionExpiryDays: Int? {
        guard let expiryDate = subscriptionExpiryDate else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: expiryDate)
        return components.day
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
        case subscriptionType = "subscription_type"
        case inspirePoints = "inspire_points"
        case subscriptionExpiryDate = "subscription_expiry_date"
        case avatarData = "avatar_data"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(String.self, forKey: .userId)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        subscriptionType = try container.decode(SubscriptionType.self, forKey: .subscriptionType)
        inspirePoints = try container.decode(Int.self, forKey: .inspirePoints)
        subscriptionExpiryDate = try container.decodeIfPresent(Date.self, forKey: .subscriptionExpiryDate)
        
        // 解码avatar
        if let avatarData = try container.decodeIfPresent(Data.self, forKey: .avatarData) {
            avatar = UIImage(data: avatarData)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(username, forKey: .username)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encode(subscriptionType, forKey: .subscriptionType)
        try container.encode(inspirePoints, forKey: .inspirePoints)
        try container.encodeIfPresent(subscriptionExpiryDate, forKey: .subscriptionExpiryDate)
        
        // 编码avatar
        if let avatar = avatar,
           let avatarData = avatar.pngData() {
            try container.encode(avatarData, forKey: .avatarData)
        }
    }
    
    // 便捷初始化方法
    init(
        userId: String,
        username: String? = nil,
        nickname: String? = nil,
        email: String? = nil,
        avatar: UIImage? = nil,
        subscriptionType: SubscriptionType = .free,
        inspirePoints: Int = 0,
        subscriptionExpiryDate: Date? = nil
    ) {
        self.userId = userId
        self.username = username
        self.nickname = nickname
        self.email = email
        self.avatar = avatar
        self.subscriptionType = subscriptionType
        self.inspirePoints = inspirePoints
        self.subscriptionExpiryDate = subscriptionExpiryDate
    }
    
    // 从LMUserInfo转换
    init(from userInfo: LMUserInfo, subscriptionType: SubscriptionType = .free, inspirePoints: Int = 0) {
        self.userId = userInfo.userId
        self.username = userInfo.username
        self.nickname = nil
        self.email = userInfo.email
        self.avatar = nil
        self.subscriptionType = subscriptionType
        self.inspirePoints = inspirePoints
        self.subscriptionExpiryDate = nil
    }
}

// MARK: - LMUserInfo (API响应模型)

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
    
    // 转换为LMUserModel
    func toLMUser(subscriptionType: SubscriptionType = .free,
                  inspirePoints: Int = 0) -> LMUserModel {
        return LMUserModel(
            from: self,
            subscriptionType: subscriptionType,
            inspirePoints: inspirePoints
        )
    }
}
