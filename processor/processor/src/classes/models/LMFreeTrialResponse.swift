//
//  LMFreeTrialResponse.swift
//  processor
//
//  免费试用响应模型
//

import Foundation

struct LMFreeTrialResponse: Codable {
    var granted: Bool?
    var subscription: LMSubscriptionInfo?
    
    enum CodingKeys: String, CodingKey {
        case granted
        case subscription
    }
}

struct LMSubscriptionInfo: Codable {
    var planType: String?
    var status: String?
    var startDate: String?
    var endDate: String?
    
    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case status
        case startDate = "start_date"
        case endDate = "end_date"
    }
}
