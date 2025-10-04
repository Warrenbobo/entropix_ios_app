//
//  LMUserProfileModel.swift
//  processor
//
//  Created by muz on 2025/10/3.
//

import UIKit

struct LMUserProfileModel {
    var fullName: String
    var username: String
    var emailAddress: String
    var avatarImage: UIImage?
    var subscriptionType: String
    var inspirePoints: String
    var dateOfBirth: String?
    
    // 用于数据更新时的标识
    let userId: String
    
    static func createDefault() -> LMUserProfileModel {
        return LMUserProfileModel(
            fullName: "Alex Johnson",
            username: "alex.j@email.com",
            emailAddress: "alex.j@email.com",
            avatarImage: nil,
            subscriptionType: "Plus Plan",
            inspirePoints: "Unlimited",
            dateOfBirth: nil,
            userId: "default_user"
        )
    }
}
