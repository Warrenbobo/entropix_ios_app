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
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case email
        case membership
    }
    
    
}
