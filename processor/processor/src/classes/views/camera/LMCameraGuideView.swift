//
//  LMCameraGuideView.swift
//  processor
//
//  Camera tutorial popup card: Journey deck + Mode help deck.
//

import UIKit
import SnapKit

/// Popup tutorial card over the live camera.
final class LMCameraGuideView: UIView {

    private var currentTutorialStep: LMCameraTutorialStep?
    private var currentDeck: LMCameraTutorialDeck = .journey
    private var tutorialCompletion: (() -> Void)?
    private var marksJourneyCompleteOnFinish = false
    private var secondaryButtonWidthConstraint: Constraint?

    private let dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        return view
    }()

    private let skipButton: UIButton = {
        let button = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var configuration = UIButton.Configuration.plain()
            configuration.baseForegroundColor = .white
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.systemFont(ofSize: 16, weight: .bold)
                return outgoing
            }
            button.configuration = configuration
        } else {
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            button.setTitleColor(.white, for: .normal)
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        }
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        return button
    }()

    private let cardContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.hexColor("#645DD5", alpha: 0.74)
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.26).cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.16
        view.layer.shadowRadius = 18
        view.layer.shadowOffset = CGSize(width: 0, height: 12)
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.96)
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()

    private let illustrationContainerView = UIView()
    private let illustrationContentView = UIView()
    private let footerView = UIView()

    private let secondaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor
        button.alpha = 0
        button.isUserInteractionEnabled = false
        return button
    }()

    private let prevButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor
        button.isHidden = true
        return button
    }()

    private let indicatorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private let primaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor
        return button
    }()

    private static let navButtonWidth: CGFloat = 88
    private static let illustrationHeight: CGFloat = 240

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        isHidden = true

        addSubview(dimmingView)
        addSubview(skipButton)
        addSubview(cardContainerView)

        cardContainerView.addSubview(titleLabel)
        cardContainerView.addSubview(descriptionLabel)
        cardContainerView.addSubview(illustrationContainerView)
        illustrationContainerView.addSubview(illustrationContentView)
        cardContainerView.addSubview(footerView)

        // Absolute footer: page indicator stays card-centered; side buttons pin L/R.
        footerView.addSubview(secondaryButton)
        footerView.addSubview(prevButton)
        footerView.addSubview(indicatorLabel)
        footerView.addSubview(primaryButton)

        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        skipButton.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(12)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(32)
        }

        cardContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(44)
            make.trailing.equalToSuperview().offset(-44)
            make.centerY.equalToSuperview().offset(-10)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        illustrationContainerView.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(14)
            make.height.equalTo(Self.illustrationHeight)
        }

        illustrationContentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        footerView.snp.makeConstraints { make in
            make.top.equalTo(illustrationContainerView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(36)
            make.bottom.equalToSuperview().offset(-16)
        }

        indicatorLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        indicatorLabel.setContentHuggingPriority(.required, for: .horizontal)
        indicatorLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        secondaryButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            secondaryButtonWidthConstraint = make.width.equalTo(0).constraint
        }

        prevButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(Self.navButtonWidth)
        }

        primaryButton.snp.makeConstraints { make in
            make.trailing.top.bottom.equalToSuperview()
            make.width.equalTo(Self.navButtonWidth)
        }

        skipButton.addTarget(self, action: #selector(handleSkipButtonTapped), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(handleSecondaryButtonTapped), for: .touchUpInside)
        prevButton.addTarget(self, action: #selector(handlePrevButtonTapped), for: .touchUpInside)
        primaryButton.addTarget(self, action: #selector(handlePrimaryButtonTapped), for: .touchUpInside)
    }

    /**
     Presents a tutorial deck.

     - Parameters:
       - deck: Journey (first-time) or Mode help.
       - onComplete: Invoked when the deck finishes with `markCompleted` semantics for Journey only.
     */
    func showTutorial(deck: LMCameraTutorialDeck, onComplete: (() -> Void)? = nil) {
        currentDeck = deck
        marksJourneyCompleteOnFinish = (deck == .journey)
        currentTutorialStep = .first(of: deck)
        tutorialCompletion = onComplete

        isHidden = false
        alpha = 0
        updateTutorialContent()
        layoutIfNeeded()

        UIView.animate(withDuration: 0.25) {
            self.alpha = 1
        }
    }

    /**
     Hides the tutorial card.

     - Parameters:
       - animated: Fade out when true.
       - markCompleted: When true and presenting Journey, runs the completion handler (persists flag).
     */
    func hideTutorial(animated: Bool = true, markCompleted: Bool = false) {
        let shouldMark = markCompleted && marksJourneyCompleteOnFinish
        let completionBlock = {
            self.isHidden = true
            self.currentTutorialStep = nil
            let handler = self.tutorialCompletion
            self.tutorialCompletion = nil
            self.marksJourneyCompleteOnFinish = false
            if shouldMark {
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

        titleLabel.text = step.title
        descriptionLabel.text = step.description
        indicatorLabel.text = String(
            format: LMText.camera.tutorialStepIndicatorFormat,
            step.index,
            step.stepCount
        )

        let primaryTitle = step.isLast
            ? step.primaryButtonTitle
            : step.primaryButtonTitle.uppercased()
        primaryButton.setTitle(primaryTitle, for: .normal)

        let shouldShowReplay = step.deck == .journey && step.isLast
        secondaryButton.setTitle(LMText.camera.tutorialReplay, for: .normal)
        secondaryButton.alpha = shouldShowReplay ? 1 : 0
        secondaryButton.isUserInteractionEnabled = shouldShowReplay
        secondaryButtonWidthConstraint?.update(offset: shouldShowReplay ? Self.navButtonWidth : 0)

        let shouldShowPrev = step.showsPreviousButton && !shouldShowReplay
        prevButton.setTitle(LMText.camera.tutorialPrev.uppercased(), for: .normal)
        prevButton.isHidden = !shouldShowPrev

        skipButton.isHidden = shouldShowReplay
        skipButton.setTitle(LMText.camera.tutorialSkip.uppercased(), for: .normal)

        if step.deck == .modeHelp {
            skipButton.isHidden = false
            skipButton.setTitle(LMText.camera.tutorialSkip.uppercased(), for: .normal)
        }

        renderIllustration(for: step)
    }

    private func renderIllustration(for step: LMCameraTutorialStep) {
        illustrationContentView.subviews.forEach { $0.removeFromSuperview() }

        switch step {
        case .journey(let journeyStep):
            renderJourneyScreenshot(assetName: journeyStep.assetName)
        case .modeHelp(.modeDeck):
            renderModeDeckIllustration()
        case .modeHelp(.spotVsTemplate):
            renderModeContrastIllustration()
        }
    }

    private func renderJourneyScreenshot(assetName: String) {
        let imageView = UIImageView(image: UIImage(named: assetName))
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        illustrationContentView.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func renderModeDeckIllustration() {
        let panel = LMPreShootPlanModePanelView(isInteractive: false, selected: .findSpot)
        illustrationContentView.addSubview(panel)
        panel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(200)
        }
        // Scale down slightly to fit illustration slot.
        panel.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
    }

    private func renderModeContrastIllustration() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .fill

        let findCard = makeContrastCard(
            icon: LMPreShootPlanSymbols.findSpot(
                configuration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
            ),
            title: LMText.camera.preShootPlanButtonFindSpot,
            caption: LMText.camera.tutorialModeContrastFindSpotCaption
        )
        let templateCard = makeContrastCard(
            icon: LMPreShootPlanSymbols.composition(
                configuration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
            ),
            title: LMText.camera.preShootPlanButtonComposition,
            caption: LMText.camera.tutorialModeContrastGetTemplateCaption
        )

        let vsLabel = UILabel()
        vsLabel.text = "vs"
        vsLabel.font = .systemFont(ofSize: 12, weight: .bold)
        vsLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        vsLabel.textAlignment = .center

        stack.addArrangedSubview(findCard)
        stack.addArrangedSubview(vsLabel)
        stack.addArrangedSubview(templateCard)

        illustrationContentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(8)
        }
    }

    private func makeContrastCard(icon: UIImage?, title: String, caption: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        container.layer.cornerRadius = 14
        container.layer.borderWidth = 1.5
        container.layer.borderColor = UIColor.hexColor("#6680E6").cgColor

        let iconView = UIImageView(image: icon)
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white

        let captionLabel = UILabel()
        captionLabel.text = caption
        captionLabel.font = .systemFont(ofSize: 12, weight: .regular)
        captionLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        captionLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [titleLabel, captionLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        container.addSubview(iconView)
        container.addSubview(textStack)

        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(28)
        }
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(iconView.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-12)
            make.top.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }
        return container
    }

    @objc private func handleSkipButtonTapped() {
        // Journey Skip marks complete; Mode help Skip just dismisses.
        hideTutorial(markCompleted: currentDeck == .journey)
    }

    @objc private func handlePrimaryButtonTapped() {
        guard let step = currentTutorialStep else { return }

        if let nextStep = step.next {
            currentTutorialStep = nextStep
            updateTutorialContent()
            return
        }

        hideTutorial(markCompleted: currentDeck == .journey)
    }

    @objc private func handleSecondaryButtonTapped() {
        guard case .journey = currentTutorialStep, currentTutorialStep?.isLast == true else { return }
        currentTutorialStep = .journey(.findSpot)
        updateTutorialContent()
    }

    @objc private func handlePrevButtonTapped() {
        guard let step = currentTutorialStep,
              let previousStep = step.previous,
              step.showsPreviousButton else { return }
        currentTutorialStep = previousStep
        updateTutorialContent()
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
