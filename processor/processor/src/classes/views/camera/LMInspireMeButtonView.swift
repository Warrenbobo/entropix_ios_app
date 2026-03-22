//
//  LMInspireMeButtonView.swift
//  processor
//
//  Created by muz on 2025/1/15.
//

import UIKit
import SnapKit

protocol LMInspireMeButtonViewDelegate: AnyObject {
    func inspireMeButtonViewDidTapButton()
    func inspireMeButtonViewDidTapQuestionButton()
    func inspireMeButtonViewDidTapDisabledButton()
}

class LMInspireMeButtonView: UIView {

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
        addSubview(inspireButton)
        inspireButton.addSubview(contentStackView)

        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.spacing = 8
        contentStackView.isUserInteractionEnabled = false

        titleLabel.text = LMText.camera.inspireMeButton
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = .white
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
        inspireButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }

        questionButton.snp.makeConstraints { make in
            make.width.height.equalTo(28)
        }
    }

    private func configureDefaultStyles() {
        backgroundColor = .clear
        layer.cornerRadius = 18
        layer.masksToBounds = true

        let gradientImage = UIImage.gradientImage(
            size: CGSize(width: 220, height: 80),
            colors: [UIColor.hexColor("#6680E6").cgColor,
                    UIColor.hexColor("#9966E6").cgColor],
            direction: .horizontal,
            cornerRadius: 18
        )
        inspireButton.setBackgroundImage(gradientImage, for: .normal)
        inspireButton.adjustsImageWhenHighlighted = false
        updateInspireButtonAppearance()
    }

    private func updateInspireButtonAppearance() {
        inspireButton.alpha = isEnabledForCamera ? 1.0 : 0.5
    }
}

extension LMInspireMeButtonView {

    @objc private func handleInspireButtonTapped() {
        guard !isHidden else { return }

        if !isEnabledForCamera {
            delegate?.inspireMeButtonViewDidTapDisabledButton()
            return
        }

        delegate?.inspireMeButtonViewDidTapButton()
    }

    @objc private func handleQuestionButtonTapped() {
        guard !isHidden else { return }
        delegate?.inspireMeButtonViewDidTapQuestionButton()
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
