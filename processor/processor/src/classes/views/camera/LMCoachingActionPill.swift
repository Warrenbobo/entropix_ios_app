//
//  LMCoachingActionPill.swift
//  processor
//

import UIKit

/// Solid chip for Skip / Dismiss. Not a second glass layer.
final class LMCoachingActionPill: UIControl {
    private let titleLabel = UILabel()
    private let fillView = UIView()

    init(title: String) {
        super.init(frame: .zero)
        fillView.isUserInteractionEnabled = false
        fillView.backgroundColor = LMLiquidGlassHUDTokens.pillFill
        fillView.layer.cornerRadius = LMLiquidGlassHUDTokens.pillCornerRadius
        fillView.layer.borderWidth = 1
        fillView.layer.borderColor = LMLiquidGlassHUDTokens.pillBorder.cgColor
        fillView.clipsToBounds = true

        titleLabel.text = title
        titleLabel.font = LMLiquidGlassHUDTokens.pillFont
        titleLabel.textColor = LMLiquidGlassHUDTokens.textPrimary

        addSubview(fillView)
        fillView.addSubview(titleLabel)

        fillView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fillView.topAnchor.constraint(equalTo: topAnchor),
            fillView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fillView.trailingAnchor.constraint(equalTo: trailingAnchor),
            fillView.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.topAnchor.constraint(equalTo: fillView.topAnchor, constant: 4),
            titleLabel.bottomAnchor.constraint(equalTo: fillView.bottomAnchor, constant: -4),
            titleLabel.leadingAnchor.constraint(equalTo: fillView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: fillView.trailingAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setTitle(_ title: String) {
        titleLabel.text = title
    }
}
