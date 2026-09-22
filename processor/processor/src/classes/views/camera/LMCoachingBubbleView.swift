//
//  LMCoachingBubbleView.swift
//  processor
//

import UIKit
import SnapKit

/// Agent coaching instruction bubble with Liquid Glass material.
final class LMCoachingBubbleView: UIView {
    private static let reasoningViewportHeight: CGFloat = 54
    private static let actionPillHeight: CGFloat = 28

    var onSkipTapped: (() -> Void)?
    var onDismissToolTapped: (() -> Void)?
    var onToggleReasoning: (() -> Void)?

    private let glassPanel = UIVisualEffectView()
    private let edgeBar = LMCoachingEdgeLitBar()
    /// Vertical stack: instruction row → action pills → reasoning.
    private let contentColumn = UIStackView()
    private let instructionRow = UIStackView()
    private let actionsRow = UIStackView()
    private let instructionLabel = UILabel()
    private let expandButton = UIButton(type: .system)
    private let reasoningScrollView = UIScrollView()
    private let reasoningLabel = UILabel()
    private let skipPill = LMCoachingActionPill(title: "")
    private let dismissPill = LMCoachingActionPill(title: "")
    private let finishBorderLayer = CAShapeLayer()
    private var skipHeightConstraint: Constraint?
    private var dismissHeightConstraint: Constraint?
    private var actionsRowHeightConstraint: Constraint?
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
            effect.tintColor = LMLiquidGlassHUDTokens.panelGlassTint
            glassPanel.effect = effect
        } else {
            glassPanel.effect = UIBlurEffect(style: .systemMaterialDark)
        }
        glassPanel.layer.cornerRadius = LMLiquidGlassHUDTokens.panelCornerRadius
        glassPanel.clipsToBounds = true

        instructionLabel.font = LMLiquidGlassHUDTokens.instructionFont
        instructionLabel.textColor = LMLiquidGlassHUDTokens.textPrimary
        instructionLabel.numberOfLines = 0
        instructionLabel.lineBreakMode = .byWordWrapping
        instructionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        instructionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        instructionLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        reasoningLabel.font = LMLiquidGlassHUDTokens.reasoningFont
        reasoningLabel.textColor = LMLiquidGlassHUDTokens.coachingTextSecondary
        reasoningLabel.numberOfLines = 0

        reasoningScrollView.showsVerticalScrollIndicator = false
        reasoningScrollView.isHidden = true
        reasoningScrollView.addSubview(reasoningLabel)

        expandButton.tintColor = LMLiquidGlassHUDTokens.coachingTextSecondary
        expandButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        expandButton.addTarget(self, action: #selector(expandTapped), for: .touchUpInside)
        expandButton.isHidden = true
        expandButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        expandButton.setContentHuggingPriority(.required, for: .horizontal)

        skipPill.isHidden = true
        skipPill.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        skipPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        skipPill.setContentHuggingPriority(.required, for: .horizontal)

        dismissPill.isHidden = true
        dismissPill.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        dismissPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        dismissPill.setContentHuggingPriority(.required, for: .horizontal)

        // Row 1: full-width instruction + expand chevron (never shares width with pills).
        instructionRow.axis = .horizontal
        instructionRow.alignment = .top
        instructionRow.spacing = 6
        instructionRow.addArrangedSubview(instructionLabel)
        instructionRow.addArrangedSubview(expandButton)

        // Row 2: Skip / Close frame guide keep intrinsic width.
        actionsRow.axis = .horizontal
        actionsRow.alignment = .center
        actionsRow.spacing = 8
        actionsRow.addArrangedSubview(skipPill)
        actionsRow.addArrangedSubview(dismissPill)
        actionsRow.addArrangedSubview(UIView()) // trailing spacer

        contentColumn.axis = .vertical
        contentColumn.alignment = .fill
        contentColumn.spacing = 8
        contentColumn.addArrangedSubview(instructionRow)
        contentColumn.addArrangedSubview(actionsRow)
        contentColumn.addArrangedSubview(reasoningScrollView)

        let instructionTap = UITapGestureRecognizer(target: self, action: #selector(expandTapped))
        instructionLabel.isUserInteractionEnabled = true
        instructionLabel.addGestureRecognizer(instructionTap)

        addSubview(glassPanel)
        glassPanel.contentView.addSubview(edgeBar)
        glassPanel.contentView.addSubview(contentColumn)

        glassPanel.snp.makeConstraints { $0.edges.equalToSuperview() }
        edgeBar.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(LMLiquidGlassHUDTokens.edgeBarWidth)
        }
        contentColumn.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalTo(edgeBar.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.bottom.equalToSuperview().offset(-8)
        }
        instructionRow.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(22)
        }
        actionsRow.snp.makeConstraints { make in
            actionsRowHeightConstraint = make.height.equalTo(0).constraint
        }
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
            reasoningHeightConstraint = make.height.equalTo(0).constraint
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
        // Prefer wrapping within the available instruction width.
        let expandWidth: CGFloat = expandButton.isHidden ? 0 : 24
        let available = max(0, instructionRow.bounds.width - expandWidth)
        if available > 0, instructionLabel.preferredMaxLayoutWidth != available {
            instructionLabel.preferredMaxLayoutWidth = available
            invalidateIntrinsicContentSize()
        }
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
        showSkip: Bool = false
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
        skipHeightConstraint?.update(offset: showSkipButton ? Self.actionPillHeight : 0)

        // Framing / Pose dismiss moved to sidebar toggles — no HUD close pills.
        dismissPill.isHidden = true
        dismissHeightConstraint?.update(offset: 0)

        let showActionsRow = showSkipButton
        actionsRow.isHidden = !showActionsRow
        actionsRowHeightConstraint?.update(offset: showActionsRow ? Self.actionPillHeight : 0)
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
