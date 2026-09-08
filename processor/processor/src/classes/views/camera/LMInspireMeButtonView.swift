//
//  LMInspireMeButtonView.swift
//  processor
//
//  Created by muz on 2025/1/15.
//

import UIKit
import SnapKit

protocol LMInspireMeButtonViewDelegate: AnyObject {
    func preShootPlanButtonViewDidTapButton()
    func preShootPlanButtonViewDidTapQuestionButton()
    func preShootPlanButtonViewDidTapDisabledButton()
}

class LMInspireMeButtonView: UIView {

    private let glassPanel = UIVisualEffectView()
    private let depthShadowView = UIView()
    private let borderView = UIView()
    private let inspireButton = UIButton()
    private let contentStackView = UIStackView()
    private let titleLabel = UILabel()
    private let questionButton = UIButton()

    weak var delegate: LMInspireMeButtonViewDelegate?
    private var inspirePoints = 1
    private var isEnabledForCamera = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupComponents()
        configureLayoutConstraints()
        configureDefaultStyles()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.point(inside: point, with: event) else {
            return nil
        }

        let questionButtonFrame = questionButton.convert(questionButton.bounds, to: self)
        let expandedQuestionFrame = questionButtonFrame.insetBy(dx: -8, dy: -8)
        if expandedQuestionFrame.contains(point) {
            return questionButton
        }

        return inspireButton
    }
}

extension LMInspireMeButtonView {

    private func setupComponents() {
        addSubview(depthShadowView)
        addSubview(glassPanel)
        addSubview(borderView)
        addSubview(inspireButton)
        inspireButton.addSubview(contentStackView)

        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.spacing = 6
        contentStackView.isUserInteractionEnabled = false

        titleLabel.text = LMText.camera.inspireMeButton
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = LMLiquidGlassHUDTokens.textPrimary
        titleLabel.textAlignment = .center

        let questionImage = UIImage(named: "question_circle")?.withRenderingMode(.alwaysOriginal)
            ?? UIImage(systemName: "questionmark.circle.fill")
        questionButton.setImage(questionImage, for: .normal)
        questionButton.tintColor = nil
        questionButton.imageView?.contentMode = .scaleAspectFit
        questionButton.isUserInteractionEnabled = true
        questionButton.addTarget(self, action: #selector(handleQuestionButtonTapped), for: .touchUpInside)

        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(questionButton)

        inspireButton.addTarget(self, action: #selector(handleInspireButtonTapped), for: .touchUpInside)
    }

    private func configureLayoutConstraints() {
        depthShadowView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        glassPanel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        borderView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        inspireButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(14)
            make.trailing.lessThanOrEqualToSuperview().offset(-14)
        }

        questionButton.snp.makeConstraints { make in
            make.width.height.equalTo(20)
        }
    }

    private func configureDefaultStyles() {
        backgroundColor = .clear
        layer.cornerRadius = LMLiquidGlassHUDTokens.panelCornerRadius
        layer.masksToBounds = false

        depthShadowView.backgroundColor = UIColor.black.withAlphaComponent(0.28)
        depthShadowView.layer.cornerRadius = LMLiquidGlassHUDTokens.panelCornerRadius
        depthShadowView.layer.shadowColor = UIColor.black.cgColor
        depthShadowView.layer.shadowOpacity = 0.45
        depthShadowView.layer.shadowRadius = 10
        depthShadowView.layer.shadowOffset = CGSize(width: 0, height: 6)
        depthShadowView.isUserInteractionEnabled = false

        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.isInteractive = true
            glassPanel.effect = effect
        } else {
            glassPanel.effect = UIBlurEffect(style: .systemThinMaterialDark)
        }
        glassPanel.layer.cornerRadius = LMLiquidGlassHUDTokens.panelCornerRadius
        glassPanel.clipsToBounds = true

        borderView.backgroundColor = .clear
        borderView.layer.cornerRadius = LMLiquidGlassHUDTokens.panelCornerRadius
        borderView.layer.borderWidth = 0.5
        borderView.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        borderView.isUserInteractionEnabled = false

        inspireButton.backgroundColor = .clear
        inspireButton.adjustsImageWhenHighlighted = false
        updateInspireButtonAppearance()
    }

    private func updateInspireButtonAppearance() {
        alpha = isEnabledForCamera ? 1.0 : 0.5
        transform = isEnabledForCamera ? CGAffineTransform(translationX: 0, y: -1) : .identity
    }
}

extension LMInspireMeButtonView {

    @objc private func handleInspireButtonTapped() {
        guard !isHidden else { return }

        if !isEnabledForCamera {
            delegate?.preShootPlanButtonViewDidTapDisabledButton()
            return
        }

        delegate?.preShootPlanButtonViewDidTapButton()
    }

    @objc private func handleQuestionButtonTapped() {
        guard !isHidden else { return }
        delegate?.preShootPlanButtonViewDidTapQuestionButton()
    }
}

extension LMInspireMeButtonView {

    func updateInspirePointsCount(_ points: Int) {
        inspirePoints = max(0, points)
        updateInspireButtonAppearance()
    }

    func decrementInspirePointsCount() {
        updateInspireButtonAppearance()
    }

    func getCurrentInspirePoints() -> Int {
        inspirePoints
    }

    func setInspireMeButtonEnabled(_ enabled: Bool) {
        isEnabledForCamera = enabled
        updateInspireButtonAppearance()
    }
}
