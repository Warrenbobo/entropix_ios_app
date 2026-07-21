//
//  LMCoachingBubbleView.swift
//  processor
//

import UIKit
import SnapKit

/// Agent coaching instruction bubble with Liquid Glass material.
final class LMCoachingBubbleView: UIView {
    private static let reasoningViewportHeight: CGFloat = 54

    var onSkipTapped: (() -> Void)?
    var onDismissToolTapped: (() -> Void)?
    var onToggleReasoning: (() -> Void)?

    private let glassPanel = UIVisualEffectView()
    private let edgeBar = LMCoachingEdgeLitBar()
    private let instructionRow = UIStackView()
    private let instructionLabel = UILabel()
    private let expandButton = UIButton(type: .system)
    private let reasoningScrollView = UIScrollView()
    private let reasoningLabel = UILabel()
    private let skipPill = LMCoachingActionPill(title: "")
    private let dismissPill = LMCoachingActionPill(title: "")
    private let finishBorderLayer = CAShapeLayer()
    private var skipHeightConstraint: Constraint?
    private var dismissHeightConstraint: Constraint?
    private var reasoningHeightConstraint: Constraint?
    private var thinkingAnimator: UIViewPropertyAnimator?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isHidden = true
        setupUI()
        applyLocalizedCopy()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: LMLaunageManager.languageDidChangeNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        thinkingAnimator?.stopAnimation(true)
        NotificationCenter.default.removeObserver(self)
    }

    private var thinkingPlaceholder: String { LMText.camera.agentThinkingPlaceholder }

    private func setupUI() {
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.isInteractive = true
            glassPanel.effect = effect
        } else {
            glassPanel.effect = UIBlurEffect(style: .systemMaterialDark)
        }
        glassPanel.layer.cornerRadius = LMLiquidGlassHUDTokens.panelCornerRadius
        glassPanel.clipsToBounds = true

        instructionLabel.font = LMLiquidGlassHUDTokens.instructionFont
        instructionLabel.textColor = LMLiquidGlassHUDTokens.textPrimary
        instructionLabel.numberOfLines = 1
        instructionLabel.lineBreakMode = .byTruncatingTail

        reasoningLabel.font = LMLiquidGlassHUDTokens.reasoningFont
        reasoningLabel.textColor = LMLiquidGlassHUDTokens.textSecondary
        reasoningLabel.numberOfLines = 0

        reasoningScrollView.showsVerticalScrollIndicator = false
        reasoningScrollView.isHidden = true
        reasoningScrollView.addSubview(reasoningLabel)

        expandButton.tintColor = LMLiquidGlassHUDTokens.textSecondary
        expandButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        expandButton.addTarget(self, action: #selector(expandTapped), for: .touchUpInside)
        expandButton.isHidden = true

        skipPill.isHidden = true
        skipPill.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

        dismissPill.isHidden = true
        dismissPill.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)

        instructionRow.axis = .horizontal
        instructionRow.alignment = .center
        instructionRow.spacing = 6
        instructionRow.addArrangedSubview(instructionLabel)
        instructionRow.addArrangedSubview(skipPill)
        instructionRow.addArrangedSubview(dismissPill)
        instructionRow.addArrangedSubview(expandButton)

        let instructionTap = UITapGestureRecognizer(target: self, action: #selector(expandTapped))
        instructionLabel.isUserInteractionEnabled = true
        instructionLabel.addGestureRecognizer(instructionTap)

        addSubview(glassPanel)
        glassPanel.contentView.addSubview(edgeBar)
        glassPanel.contentView.addSubview(instructionRow)
        glassPanel.contentView.addSubview(reasoningScrollView)

        glassPanel.snp.makeConstraints { $0.edges.equalToSuperview() }
        edgeBar.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(LMLiquidGlassHUDTokens.edgeBarWidth)
        }
        instructionRow.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalTo(edgeBar.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.height.greaterThanOrEqualTo(22)
        }
        instructionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        skipPill.snp.makeConstraints { make in
            skipHeightConstraint = make.height.equalTo(0).constraint
        }
        dismissPill.snp.makeConstraints { make in
            dismissHeightConstraint = make.height.equalTo(0).constraint
        }
        expandButton.snp.makeConstraints { make in
            make.width.height.equalTo(18)
        }
        reasoningScrollView.snp.makeConstraints { make in
            make.top.equalTo(instructionRow.snp.bottom).offset(4)
            make.leading.trailing.equalTo(instructionRow)
            reasoningHeightConstraint = make.height.equalTo(0).constraint
            make.bottom.equalToSuperview().offset(-8)
        }
        reasoningLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(reasoningScrollView.snp.width)
        }

        finishBorderLayer.fillColor = UIColor.clear.cgColor
        finishBorderLayer.strokeColor = LMLiquidGlassHUDTokens.finishBorder.cgColor
        finishBorderLayer.lineWidth = 1.5
        finishBorderLayer.isHidden = true
        layer.addSublayer(finishBorderLayer)
    }

    @objc private func languageDidChange() {
        applyLocalizedCopy()
    }

    private func applyLocalizedCopy() {
        skipPill.setTitle(LMText.camera.agentSkipButton)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        finishBorderLayer.path = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: LMLiquidGlassHUDTokens.panelCornerRadius
        ).cgPath
        finishBorderLayer.frame = bounds
    }

    /// Latest instruction text shown in the bubble (for Skip handling).
    var currentInstructionText: String? {
        let text = instructionLabel.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty, text != thinkingPlaceholder else { return nil }
        return text
    }

    func update(
        instruction: String?,
        reasoning: String? = nil,
        reasoningExpanded: Bool = false,
        agentState: LMAgentState,
        isFinished: Bool,
        showSkip: Bool = false,
        executionTool: LMExecutionTool = .none
    ) {
        let trimmedInstruction = instruction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedReasoning = reasoning?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasAction = !trimmedInstruction.isEmpty && trimmedInstruction != thinkingPlaceholder
        let hasReasoning = !trimmedReasoning.isEmpty
        let isThinking = agentState == .running && !hasAction

        stopThinkingAnimation()
        if isThinking {
            instructionLabel.text = thinkingPlaceholder
            startThinkingAnimation()
        } else {
            instructionLabel.text = hasAction ? trimmedInstruction : ""
        }

        reasoningLabel.text = trimmedReasoning
        let showReasoningBody = reasoningExpanded && hasReasoning
        reasoningScrollView.isHidden = !showReasoningBody
        reasoningHeightConstraint?.update(offset: showReasoningBody ? Self.reasoningViewportHeight : 0)
        expandButton.isHidden = !hasReasoning
        expandButton.setImage(
            UIImage(systemName: reasoningExpanded ? "chevron.up" : "chevron.down"),
            for: .normal
        )

        if showReasoningBody {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let bottom = self.reasoningScrollView.contentSize.height - self.reasoningScrollView.bounds.height
                if bottom > 0 {
                    self.reasoningScrollView.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
                }
            }
        }

        let edgeState: LMCoachingEdgeLitState
        switch agentState {
        case .idle: edgeState = hasAction ? .action : .idle
        case .running: edgeState = isThinking ? .thinking : .action
        case .finished: edgeState = .finished
        case .error: edgeState = .error
        }
        edgeBar.apply(state: edgeState)
        finishBorderLayer.isHidden = !isFinished

        let showSkipButton = hasAction && !isThinking && showSkip && !isFinished
        skipPill.isHidden = !showSkipButton
        skipHeightConstraint?.update(offset: showSkipButton ? 28 : 0)

        let dismissLabel: String?
        switch executionTool {
        case .box: dismissLabel = LMText.camera.agentDismissBoxButton
        case .lineArt: dismissLabel = LMText.camera.agentDismissLineArtButton
        case .none: dismissLabel = nil
        }
        let showDismissButton = hasAction && !isThinking && dismissLabel != nil
        dismissPill.isHidden = !showDismissButton
        dismissPill.setTitle(dismissLabel ?? "")
        dismissHeightConstraint?.update(offset: showDismissButton ? 28 : 0)
    }

    func setVisible(_ visible: Bool, animated: Bool = true) {
        guard visible != !isHidden else { return }
        if animated {
            if visible {
                isHidden = false
                alpha = 0
                UIView.animate(withDuration: 0.25) { self.alpha = 1 }
            } else {
                UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in
                    self.isHidden = true
                    self.alpha = 1
                }
            }
        } else {
            isHidden = !visible
        }
    }

    private func startThinkingAnimation() {
        instructionLabel.alpha = 0.45
        thinkingAnimator = UIViewPropertyAnimator(duration: 0.9, curve: .easeInOut) { [weak self] in
            self?.instructionLabel.alpha = 1
        }
        thinkingAnimator?.addAnimations({ [weak self] in
            self?.instructionLabel.alpha = 0.45
        }, delayFactor: 0.5)
        thinkingAnimator?.addCompletion { [weak self] _ in
            guard let self, self.instructionLabel.text == self.thinkingPlaceholder else { return }
            self.startThinkingAnimation()
        }
        thinkingAnimator?.startAnimation()
    }

    private func stopThinkingAnimation() {
        thinkingAnimator?.stopAnimation(true)
        thinkingAnimator = nil
        instructionLabel.alpha = 1
    }

    @objc private func skipTapped() { onSkipTapped?() }
    @objc private func dismissTapped() { onDismissToolTapped?() }
    @objc private func expandTapped() { onToggleReasoning?() }
}
