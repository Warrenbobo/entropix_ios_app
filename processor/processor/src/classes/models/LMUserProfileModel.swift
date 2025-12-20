//
//  LMUserProfileModel.swift
//  processor
//
//  Created by muz on 2025/10/3.
//  Updated: 2025-01-16 - 符合接口文档规范
//

import UIKit

struct LMUserProfileModel: Codable {
    var userId: String?
    var username: String?
    var nickname: String?
    var email: String?
    var avatar: String?
    var subscription: String?
    var inspirePoints: Int?
    var dateOfBirth: String?
    var language: String?
    var isGuest: Bool?
    
    // 本地使用的头像图片（不参与编码）
    var avatarImage: UIImage?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case nickname
        case email
        case avatar
        case subscription
        case inspirePoints = "inspire_points"
        case dateOfBirth = "date_of_birth"
        case language
        case isGuest = "is_guest"
    }
    
    // 便捷属性
    var displayName: String {
        return nickname ?? username ?? "User"
    }
    
    var subscriptionDisplayName: String {
        guard let subscription = subscription else { return "Free Plan" }
        switch subscription.lowercased() {
        case "free":
            return "Free Plan"
        case "plus":
            return "Plus Plan"
        case "lifelong":
            return "Lifelong Plan"
        case "trial":
            return "Trial"
        default:
            return subscription
        }
    }
    
    var inspirePointsDisplay: String {
        if let points = inspirePoints {
            return "\(points)"
        }
        return "0"
    }
    
    static func createDefault() -> LMUserProfileModel {
        return LMUserProfileModel(
            userId: "default_user",
            username: "alex.j@email.com",
            nickname: "Alex Johnson",
            email: "alex.j@email.com",
            avatar: nil,
            subscription: "plus",
            inspirePoints: nil,
            dateOfBirth: nil,
            language: "en",
            isGuest: false,
            avatarImage: nil
        )
    }
}
