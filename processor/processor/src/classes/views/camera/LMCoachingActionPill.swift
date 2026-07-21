//
//  LMCoachingActionPill.swift
//  processor
//

import UIKit

/// Secondary glass pill button (Skip / Dismiss).
final class LMCoachingActionPill: UIControl {
    private let titleLabel = UILabel()
    private let glassView = UIVisualEffectView()

    init(title: String) {
        super.init(frame: .zero)
        if #available(iOS 26.0, *) {
            glassView.effect = UIGlassEffect(style: .regular)
        } else {
            glassView.effect = UIBlurEffect(style: .systemThinMaterialDark)
        }
        glassView.isUserInteractionEnabled = false
        glassView.layer.cornerRadius = LMLiquidGlassHUDTokens.pillCornerRadius
        glassView.clipsToBounds = true

        titleLabel.text = title
        titleLabel.font = LMLiquidGlassHUDTokens.pillFont
        titleLabel.textColor = LMLiquidGlassHUDTokens.textSecondary

        addSubview(glassView)
        glassView.contentView.addSubview(titleLabel)

        glassView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: 4),
            titleLabel.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -4),
            titleLabel.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTitle(_ title: String) {
        titleLabel.text = title
    }
}
