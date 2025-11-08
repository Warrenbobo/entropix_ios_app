//
//  SubscriptionPlan.swift
//  processor
//
//  Created by muz on 2025/11/8.
//

import UIKit

// MARK: - Plan Type Enum
enum SubscriptionPlanType {
    case free
    case plus
    case lifelong
    
    var title: String {
        switch self {
        case .free:
            return "Free Plan"
        case .plus:
            return "Plus Plan"
        case .lifelong:
            return "Life-long Plan"
        }
    }
}

// MARK: - Plan Card Model
struct SubscriptionPlan {
    let planType: SubscriptionPlanType
    let title: String
    let subtitle: String?  // For Free Plan: "Perfect for trying out"
    let price: String
    let originalPrice: String?
    let discount: String?
    let period: String
    let adsInfo: String?  // For Free Plan: "Google AdSense + 5 Request / ad-session"
    let description: String
    let features: [String]
    let gradientColors: [UIColor]
    let textColor: UIColor
    let buttonTitle: String
    let isSelected: Bool
    let isDisabled: Bool
    let popularBadge: String?
    let showCountdown: Bool
    let showProgress: Bool
    let progressValue: Double?
    let progressText: String?
}
