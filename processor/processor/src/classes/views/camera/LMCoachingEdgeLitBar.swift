//
//  LMCoachingEdgeLitBar.swift
//  processor
//

import UIKit

enum LMCoachingEdgeLitState {
    case idle, thinking, action, finished, error
}

/// Left edge gradient status bar for coaching bubble.
final class LMCoachingEdgeLitBar: UIView {
    private let gradient = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(gradient)
        layer.cornerRadius = LMLiquidGlassHUDTokens.panelCornerRadius
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
    }

    func apply(state: LMCoachingEdgeLitState) {
        switch state {
        case .idle:
            gradient.colors = [UIColor.white.withAlphaComponent(0.35).cgColor, UIColor.white.withAlphaComponent(0.15).cgColor]
        case .thinking:
            gradient.colors = [UIColor(red: 0.48, green: 0.66, blue: 0.91, alpha: 0.9).cgColor,
                               UIColor(red: 0.30, green: 0.85, blue: 0.39, alpha: 0.7).cgColor]
        case .action:
            gradient.colors = [UIColor(red: 0.48, green: 0.66, blue: 0.91, alpha: 1).cgColor,
                               UIColor(red: 0.36, green: 0.56, blue: 0.86, alpha: 1).cgColor]
        case .finished:
            gradient.colors = [UIColor(red: 0.30, green: 0.85, blue: 0.39, alpha: 1).cgColor,
                               UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1).cgColor]
        case .error:
            gradient.colors = [UIColor(red: 0.91, green: 0.58, blue: 0.42, alpha: 1).cgColor,
                               UIColor(red: 0.88, green: 0.36, blue: 0.36, alpha: 1).cgColor]
        }
    }
}
