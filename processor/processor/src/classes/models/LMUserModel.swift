//
//  LMUserModel.swift
//  processor
//
//  Created by muz on 2025/10/3.
//

import Foundation

struct LMUserModel: Codable {
    
    var userId: String?
    var username: String?
    var email: String?
    var membership: String?
    
    // Subscription fields
    var subscriptionType: String?
    var subscriptionExpirationDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case email
        case membership
        case subscriptionType = "subscription_type"
        case subscriptionExpirationDate = "subscription_expiration_date"
    }
    
    /// Check if user has an active subscription
    var isSubscriptionActive: Bool {
        guard let type = subscriptionType else { return false }
        
        // Lifelong subscription is always active
        if type == "lifelong" {
            return true
        }
        
        // Plus subscription is active if not expired
        if type == "plus", let expiration = subscriptionExpirationDate {
            return expiration > Date()
        }
        
        return false
    }
}
