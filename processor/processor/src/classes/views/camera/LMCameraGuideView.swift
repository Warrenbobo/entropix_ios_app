//
//  LMCameraGuideView.swift
//  processor
//
//  相机教程视图
//

import UIKit
import SnapKit

protocol LMCameraGuideViewDelegate: AnyObject {
    func cameraGuideViewDidComplete(_ guideView: LMCameraGuideView, step: LMCameraGuideStep)
}

class LMCameraGuideView: UIView {

    weak var delegate: LMCameraGuideViewDelegate?

    private var currentStep: LMCameraGuideStep?
    private var currentTutorialStep: LMCameraTutorialStep?
    private var tutorialTargetProvider: ((LMCameraTutorialStep) -> UIView?)?
    private var tutorialCompletion: (() -> Void)?

    private let dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        return view
    }()

    private let highlightView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.95).cgColor
        view.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        view.isHidden = true
        view.isUserInteractionEnabled = false
        return view
    }()

    private let cardContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.hexColor("#665CF4")
        view.layer.cornerRadius = 24
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.18
        view.layer.shadowRadius = 18
        view.layer.shadowOffset = CGSize(width: 0, height: 12)
        return view
    }()

    private let indicatorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.88)
        label.textAlignment = .center
        return label
    }()

    private let illustrationContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        view.layer.cornerRadius = 22
        return view
    }()

    private let illustrationAccentView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        view.layer.cornerRadius = 32
        return view
    }()

    private let illustrationImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.9)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let buttonsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        return stackView
    }()

    private let secondaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 22
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.42).cgColor
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        return button
    }()

    private let primaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        button.layer.cornerRadius = 22
        button.setTitleColor(UIColor.hexColor("#4B43D0"), for: .normal)
        button.backgroundColor = .white
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTutorialHighlightFrame()
    }

    private func setupUI() {
        backgroundColor = .clear
        isHidden = true

        addSubview(dimmingView)
        addSubview(highlightView)
        addSubview(cardContainerView)

        cardContainerView.addSubview(indicatorLabel)
        cardContainerView.addSubview(illustrationContainerView)
        illustrationContainerView.addSubview(illustrationAccentView)
        illustrationContainerView.addSubview(illustrationImageView)
        cardContainerView.addSubview(titleLabel)
        cardContainerView.addSubview(descriptionLabel)
        cardContainerView.addSubview(buttonsStackView)

        buttonsStackView.addArrangedSubview(secondaryButton)
        buttonsStackView.addArrangedSubview(primaryButton)

        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        cardContainerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-24)
        }

        indicatorLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.centerX.equalToSuperview()
        }

        illustrationContainerView.snp.makeConstraints { make in
            make.top.equalTo(indicatorLabel.snp.bottom).offset(18)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(156)
        }

        illustrationAccentView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(64)
        }

        illustrationImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(72)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(illustrationContainerView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        buttonsStackView.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(22)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().offset(-20)
        }

        primaryButton.addTarget(self, action: #selector(handlePrimaryButtonTapped), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(handleSecondaryButtonTapped), for: .touchUpInside)
    }

    // MARK: - New Tutorial

    func showTutorial(
        startingFrom step: LMCameraTutorialStep = .findScene,
        targetProvider: @escaping (LMCameraTutorialStep) -> UIView?,
        onComplete: @escaping () -> Void
    ) {
        currentStep = nil
        currentTutorialStep = step
        tutorialTargetProvider = targetProvider
        tutorialCompletion = onComplete

        isHidden = false
        alpha = 0
        updateTutorialContent()
        layoutIfNeeded()

        UIView.animate(withDuration: 0.25) {
            self.alpha = 1
        }
    }

    func hideTutorial(animated: Bool = true, markCompleted: Bool = false) {
        let completionBlock = {
            self.isHidden = true
            self.currentTutorialStep = nil
            self.tutorialTargetProvider = nil
            let handler = self.tutorialCompletion
            self.tutorialCompletion = nil
            self.highlightView.isHidden = true
            if markCompleted {
                handler?()
            }
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                self.alpha = 0
            }) { _ in
                completionBlock()
            }
        } else {
            alpha = 0
            completionBlock()
        }
    }

    private func updateTutorialContent() {
        guard let step = currentTutorialStep else { return }

        indicatorLabel.text = String(format: LMText.camera.tutorialStepIndicatorFormat,
                                     step.index,
                                     LMCameraTutorialStep.allCases.count)
        titleLabel.text = step.title
        descriptionLabel.text = step.description
        primaryButton.setTitle(step.primaryButtonTitle, for: .normal)
        secondaryButton.setTitle(step.secondaryButtonTitle, for: .normal)

        if let accentAssetName = step.accentAssetName,
           let accentImage = UIImage(named: accentAssetName) {
            illustrationImageView.image = accentImage.withRenderingMode(.alwaysOriginal)
        } else {
            let imageConfig = UIImage.SymbolConfiguration(pointSize: 42, weight: .bold)
            illustrationImageView.image = UIImage(systemName: step.symbolName, withConfiguration: imageConfig)
            illustrationImageView.tintColor = .white
        }

        switch step {
        case .findScene:
            illustrationContainerView.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        case .tapButton:
            illustrationContainerView.backgroundColor = UIColor.hexColor("#7E73FF", alpha: 0.55)
        case .viewAndSelect:
            illustrationContainerView.backgroundColor = UIColor.hexColor("#847BFF", alpha: 0.48)
        case .alignGuidance:
            illustrationContainerView.backgroundColor = UIColor.hexColor("#7267FF", alpha: 0.52)
        case .savePhoto:
            illustrationContainerView.backgroundColor = UIColor.hexColor("#6459F2", alpha: 0.58)
        }

        updateTutorialHighlightFrame()
    }

    private func updateTutorialHighlightFrame() {
        guard !isHidden,
              let step = currentTutorialStep,
              let targetView = tutorialTargetProvider?(step) else {
            highlightView.isHidden = true
            return
        }

        let targetFrame = targetView.convert(targetView.bounds, to: self)
        let expandedFrame = targetFrame.insetBy(dx: -10, dy: -10)

        highlightView.isHidden = false
        highlightView.frame = expandedFrame
        highlightView.layer.cornerRadius = min(expandedFrame.height / 2, 22)
        bringSubviewToFront(highlightView)
        bringSubviewToFront(cardContainerView)
    }

    @objc private func handlePrimaryButtonTapped() {
        guard let step = currentTutorialStep else { return }

        if let nextStep = step.nextStep {
            currentTutorialStep = nextStep
            updateTutorialContent()
            return
        }

        hideTutorial(markCompleted: true)
    }

    @objc private func handleSecondaryButtonTapped() {
        guard let step = currentTutorialStep else { return }

        if step == .savePhoto {
            currentTutorialStep = .findScene
            updateTutorialContent()
            return
        }

        hideTutorial(markCompleted: true)
    }

    // MARK: - Legacy Methods

    func showGuide(step: LMCameraGuideStep, targetView: UIView?, in parentView: UIView) {
        currentStep = step
        currentTutorialStep = nil
        isHidden = true
    }

    func hideGuide(animated: Bool = true, completion: (() -> Void)? = nil) {
        let step = currentStep
        currentStep = nil
        isHidden = true
        completion?()
        if let step {
            delegate?.cameraGuideViewDidComplete(self, step: step)
        }
    }
}

extension LMCameraGuideView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01 else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
