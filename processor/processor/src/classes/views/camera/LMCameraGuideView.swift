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

final class LMCameraGuideView: UIView {

    weak var delegate: LMCameraGuideViewDelegate?

    private var currentStep: LMCameraGuideStep?
    private var currentTutorialStep: LMCameraTutorialStep?
    private var tutorialCompletion: (() -> Void)?
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

    private let footerCenterStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.distribution = .fill
        return stack
    }()

    /// Fixed-width slot so PREV/NEXT stay symmetric around the page indicator.
    private let leadingNavSlot = UIView()

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

        footerView.addSubview(secondaryButton)
        footerView.addSubview(footerCenterStack)

        leadingNavSlot.addSubview(prevButton)
        footerCenterStack.addArrangedSubview(leadingNavSlot)
        footerCenterStack.addArrangedSubview(indicatorLabel)
        footerCenterStack.addArrangedSubview(primaryButton)

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
            make.height.equalTo(240)
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

        secondaryButton.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            secondaryButtonWidthConstraint = make.width.equalTo(0).constraint
        }

        footerCenterStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        leadingNavSlot.snp.makeConstraints { make in
            make.width.equalTo(Self.navButtonWidth)
            make.height.equalToSuperview()
        }

        prevButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        primaryButton.snp.makeConstraints { make in
            make.width.equalTo(Self.navButtonWidth)
            make.height.equalToSuperview()
        }

        indicatorLabel.setContentHuggingPriority(.required, for: .horizontal)
        indicatorLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        skipButton.addTarget(self, action: #selector(handleSkipButtonTapped), for: .touchUpInside)
        secondaryButton.addTarget(self, action: #selector(handleSecondaryButtonTapped), for: .touchUpInside)
        prevButton.addTarget(self, action: #selector(handlePrevButtonTapped), for: .touchUpInside)
        primaryButton.addTarget(self, action: #selector(handlePrimaryButtonTapped), for: .touchUpInside)
    }

    func showTutorial(
        startingFrom step: LMCameraTutorialStep = .findScene,
        targetProvider _: @escaping (LMCameraTutorialStep) -> UIView?,
        onComplete: @escaping () -> Void
    ) {
        currentStep = nil
        currentTutorialStep = step
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
            let handler = self.tutorialCompletion
            self.tutorialCompletion = nil
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

        titleLabel.text = step.title
        descriptionLabel.text = step.description
        indicatorLabel.text = String(format: LMText.camera.tutorialStepIndicatorFormat,
                                     step.index,
                                     LMCameraTutorialStep.allCases.count)
        primaryButton.setTitle(step == .savePhoto ? step.primaryButtonTitle : step.primaryButtonTitle.uppercased(), for: .normal)

        let shouldShowReplay = step == .savePhoto
        secondaryButton.setTitle(LMText.camera.tutorialReplay, for: .normal)
        secondaryButton.alpha = shouldShowReplay ? 1 : 0
        secondaryButton.isUserInteractionEnabled = shouldShowReplay
        secondaryButtonWidthConstraint?.update(offset: shouldShowReplay ? 82 : 0)

        let shouldShowPrev = step.showsPreviousButton
        prevButton.setTitle(LMText.camera.tutorialPrev.uppercased(), for: .normal)
        prevButton.isHidden = !shouldShowPrev
        leadingNavSlot.isHidden = step == .savePhoto

        skipButton.isHidden = shouldShowReplay
        skipButton.setTitle(LMText.camera.tutorialSkip.uppercased(), for: .normal)

        renderIllustration(for: step)
    }

    private func renderIllustration(for step: LMCameraTutorialStep) {
        illustrationContentView.subviews.forEach { $0.removeFromSuperview() }

        switch step {
        case .findScene:
            renderFindSceneIllustration()
        case .tapButton:
            renderTapButtonIllustration()
        case .viewAndSelect:
            renderViewAndSelectIllustration()
        case .alignGuidance:
            renderAlignGuidanceIllustration()
        case .savePhoto:
            renderSavePhotoIllustration()
        }
    }

    private func renderFindSceneIllustration() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.alignment = .center

        let screenshotView = makeScreenshotView(assetName: AppConfigs.Assets.tutorialScene,
                                                size: CGSize(width: 84, height: 182))
        let calloutView = makeCalloutView(text: LMText.camera.tutorialFindSceneCallout)

        illustrationContentView.addSubview(stackView)
        stackView.addArrangedSubview(screenshotView)
        stackView.addArrangedSubview(calloutView)

        calloutView.snp.makeConstraints { make in
            make.width.equalTo(158)
        }

        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func renderTapButtonIllustration() {
        let horizontalStack = UIStackView()
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = 14
        horizontalStack.alignment = .center

        let leftImageView = makeScreenshotView(assetName: AppConfigs.Assets.tutorialTapLeft,
                                               size: CGSize(width: 90, height: 196))
        let rightImageView = makeScreenshotView(assetName: AppConfigs.Assets.tutorialTapRight,
                                                size: CGSize(width: 90, height: 196))

        let arrowImageView = UIImageView(image: UIImage(systemName: "arrow.right"))
        arrowImageView.tintColor = .white
        arrowImageView.contentMode = .scaleAspectFit

        illustrationContentView.addSubview(horizontalStack)
        horizontalStack.addArrangedSubview(leftImageView)
        horizontalStack.addArrangedSubview(arrowImageView)
        horizontalStack.addArrangedSubview(rightImageView)

        arrowImageView.snp.makeConstraints { make in
            make.width.equalTo(26)
            make.height.equalTo(22)
        }

        horizontalStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func renderViewAndSelectIllustration() {
        let horizontalStack = UIStackView()
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = 12
        horizontalStack.alignment = .bottom

        let leftImageView = makeScreenshotView(assetName: AppConfigs.Assets.tutorialSelectLeft,
                                               size: CGSize(width: 86, height: 196))

        let rightColumn = UIStackView()
        rightColumn.axis = .vertical
        rightColumn.spacing = 10
        rightColumn.alignment = .center

        let rightImageView = makeScreenshotView(assetName: AppConfigs.Assets.tutorialSelectRight,
                                                size: CGSize(width: 84, height: 112),
                                                cornerRadius: 10)
        let noteLabel = UILabel()
        noteLabel.text = String(format: LMText.camera.tutorialViewAndSelectNote, LMText.profile.savedIdeas)
        noteLabel.textColor = UIColor.white.withAlphaComponent(0.95)
        noteLabel.font = UIFont.italicSystemFont(ofSize: 12)
        noteLabel.numberOfLines = 0
        noteLabel.textAlignment = .left

        rightColumn.addArrangedSubview(rightImageView)
        rightColumn.addArrangedSubview(noteLabel)

        noteLabel.snp.makeConstraints { make in
            make.width.equalTo(128)
        }

        illustrationContentView.addSubview(horizontalStack)
        horizontalStack.addArrangedSubview(leftImageView)
        horizontalStack.addArrangedSubview(rightColumn)

        horizontalStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func renderAlignGuidanceIllustration() {
        let screenshotView = makeScreenshotView(assetName: AppConfigs.Assets.tutorialAlign,
                                                size: CGSize(width: 108, height: 204))
        illustrationContentView.addSubview(screenshotView)

        screenshotView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func renderSavePhotoIllustration() {
        let horizontalStack = UIStackView()
        horizontalStack.axis = .horizontal
        horizontalStack.spacing = 14
        horizontalStack.alignment = .center

        let screenshotView = makeScreenshotView(assetName: AppConfigs.Assets.tutorialSave,
                                                size: CGSize(width: 94, height: 204))

        let actionStack = UIStackView()
        actionStack.axis = .vertical
        actionStack.spacing = 10
        actionStack.alignment = .leading

        let savePill = makeActionPill(text: LMText.common.save)
        let cloudLabel = makeActionLabel(text: LMText.camera.tutorialSaveToCloudGallery)
        let downloadBadge = makeDownloadBadge()
        let localLabel = makeActionLabel(text: LMText.camera.tutorialSaveToLocalAlbum)

        actionStack.addArrangedSubview(savePill)
        actionStack.addArrangedSubview(cloudLabel)
        actionStack.addArrangedSubview(downloadBadge)
        actionStack.addArrangedSubview(localLabel)

        illustrationContentView.addSubview(horizontalStack)
        horizontalStack.addArrangedSubview(screenshotView)
        horizontalStack.addArrangedSubview(actionStack)

        savePill.snp.makeConstraints { make in
            make.width.equalTo(80)
        }

        cloudLabel.snp.makeConstraints { make in
            make.width.equalTo(134)
        }

        localLabel.snp.makeConstraints { make in
            make.width.equalTo(134)
        }

        downloadBadge.snp.makeConstraints { make in
            make.width.height.equalTo(42)
        }

        horizontalStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }

    private func makeScreenshotView(assetName: String,
                                    size: CGSize,
                                    cornerRadius: CGFloat = 8) -> UIView {
        let container = UIView()
        container.layer.cornerRadius = cornerRadius
        container.layer.masksToBounds = true

        let imageView = UIImageView(image: UIImage(named: assetName))
        imageView.contentMode = .scaleAspectFill
        container.addSubview(imageView)

        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.width.equalTo(size.width)
            make.height.equalTo(size.height)
        }

        return container
    }

    private func makeCalloutView(text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        container.layer.cornerRadius = 17
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor

        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        label.numberOfLines = 0
        label.textAlignment = .center

        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        }

        return container
    }

    private func makeActionPill(text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        container.layer.cornerRadius = 17
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor

        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        label.textAlignment = .center

        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16))
        }

        return container
    }

    private func makeActionLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }

    private func makeDownloadBadge() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        container.layer.cornerRadius = 21
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor

        let iconView = UIImageView(image: UIImage(named: "download_white"))
        iconView.contentMode = .scaleAspectFit
        container.addSubview(iconView)

        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(16)
        }

        return container
    }

    @objc private func handleSkipButtonTapped() {
        hideTutorial(markCompleted: true)
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
        guard currentTutorialStep == .savePhoto else { return }
        currentTutorialStep = .findScene
        updateTutorialContent()
    }

    @objc private func handlePrevButtonTapped() {
        guard let step = currentTutorialStep,
              let previousStep = step.previousStep,
              step.showsPreviousButton else { return }
        currentTutorialStep = previousStep
        updateTutorialContent()
    }

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
