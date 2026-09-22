//
//  LMLiquidGlassHUDTokens.swift
//  processor
//

import UIKit

/// HUD typography and color tokens (Liquid Glass coaching bubble).
enum LMLiquidGlassHUDTokens {
    static let panelCornerRadius: CGFloat = 18
    static let edgeBarWidth: CGFloat = 2
    static let pillCornerRadius: CGFloat = 10

    static let textPrimary = UIColor.white.withAlphaComponent(0.92)
    static let textSecondary = UIColor.white.withAlphaComponent(0.58)
    /// Reasoning and expand chevron on the dark coaching panel.
    static let coachingTextSecondary = UIColor.white.withAlphaComponent(0.72)
    /// Dark tint so iOS 26 regular glass stays readable over a bright preview.
    static let panelGlassTint = UIColor.black.withAlphaComponent(0.45)
    static let pillFill = UIColor.white.withAlphaComponent(0.16)
    static let pillBorder = UIColor.white.withAlphaComponent(0.28)
    static let finishBorder = UIColor(red: 76/255, green: 217/255, blue: 100/255, alpha: 1)

    static let instructionFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
    static let reasoningFont = UIFont.systemFont(ofSize: 12, weight: .regular)
    static let pillFont = UIFont.systemFont(ofSize: 11, weight: .medium)

    /// Agent accent gradient — matches Android `HudGlassTokens.AgentAccentBorderColors`.
    static let agentAccentBorderColors: [UIColor] = [
        UIColor.hexColor("#6680E6").withAlphaComponent(0.78),
        UIColor.hexColor("#7BA9E8").withAlphaComponent(0.68),
        UIColor.hexColor("#9966E6").withAlphaComponent(0.78),
    ]
}
