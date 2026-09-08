//
//  LMPreShootPlanButtonView.swift
//  processor
//
//  Top-bar pre-shoot mode chip (Camera / Find Spot / Get Template) — Liquid Glass.
//  Tap opens the mode sheet; the shutter executes the selected mode.
//

import UIKit
import SnapKit

/// SF Symbol names for PreShootPlan modes (with fallbacks for older glyph catalogs).
enum LMPreShootPlanSymbols {
    /**
     Find Spot icon.

     Prefers `person.badge.location` (SF Symbols 2026). Falls back when the
     runtime CoreGlyphs catalog does not include that name yet.
     */
    static func findSpot(configuration: UIImage.SymbolConfiguration? = nil) -> UIImage? {
        let names = [
            "person.badge.location",
            "person.badge.location.fill",
            "person.fill.viewfinder",
            "mappin.and.ellipse"
        ]
        return firstSystemImage(names: names, configuration: configuration)
    }

    /// Get Template icon (`person.and.background.dotted`).
    static func composition(configuration: UIImage.SymbolConfiguration? = nil) -> UIImage? {
        let names = [
            "person.and.background.dotted",
            "rectangle.grid.2x2"
        ]
        return firstSystemImage(names: names, configuration: configuration)
    }

    /// Plain Camera mode icon.
    static func camera(configuration: UIImage.SymbolConfiguration? = nil) -> UIImage? {
        firstSystemImage(names: ["camera.fill", "camera"], configuration: configuration)
    }

    /**
     Icon for the given pre-shoot mode.

     - Parameters:
       - mode: Selected planning mode.
       - configuration: Optional symbol configuration.
     */
    static func icon(
        for mode: LMPreShootPlanMode,
        configuration: UIImage.SymbolConfiguration? = nil
    ) -> UIImage? {
        switch mode {
        case .camera:
            return camera(configuration: configuration)
        case .findSpot:
            return findSpot(configuration: configuration)
        case .composition:
            return composition(configuration: configuration)
        }
    }

    private static func firstSystemImage(
        names: [String],
        configuration: UIImage.SymbolConfiguration?
    ) -> UIImage? {
        for name in names {
            let image: UIImage?
            if let configuration {
                image = UIImage(systemName: name, withConfiguration: configuration)
            } else {
                image = UIImage(systemName: name)
            }
            if let image {
                return image.withRenderingMode(.alwaysTemplate)
            }
        }
        return nil
    }
}

/**
 Pre-shoot planning mode.

 Cold start / reset defaults to `.findSpot`. `.composition` is Get Template
 (kept for call-site compatibility).
 */
enum LMPreShootPlanMode: Equatable {
    case camera
    case findSpot
    /// Get Template / Idea Inspiration.
    case composition

    /// Whether this mode triggers an AI path that is blocked on the front camera.
    var requiresBackCamera: Bool {
        switch self {
        case .camera: return false
        case .findSpot, .composition: return true
        }
    }

    /// Whether the shutter uses AI (dashed ring) chrome.
    var isAIShutter: Bool {
        switch self {
        case .camera: return false
        case .findSpot, .composition: return true
        }
    }
}

protocol LMPreShootPlanButtonViewDelegate: AnyObject {
    /// User tapped the mode chip — present the mode sheet (not execute).
    func preShootPlanButtonDidTap()
    func preShootPlanButtonDidTapDisabled()
    func preShootPlanButtonDidTapHint()
}

/// Liquid Glass mode chip anchored in the top status bar (center).
final class LMPreShootPlanButtonView: UIView {

    weak var delegate: LMPreShootPlanButtonViewDelegate?

    private let depthShadowView = UIView()
    private let glassPanel = UIVisualEffectView()
    private let fillOverlay = UIView()
    private let borderView = UIView()
    private let accentStrokeLayer = CAGradientLayer()
    private let accentStrokeMask = CAShapeLayer()
    private let mainButton = UIButton(type: .custom)
    private let contentStack = UIStackView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let chevronView = UIImageView()
    private let questionButton = UIButton(type: .system)

    private var mode: LMPreShootPlanMode = .findSpot
    private var modeSwitchEnabled = true
    private var isEnabledForCamera = true
    private var inspirePoints = 1

    private let cornerRadius: CGFloat = 14

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        configureLayout()
        applyStyle()
        refreshContent()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        accentStrokeLayer.frame = borderView.bounds
        accentStrokeMask.path = UIBezierPath(
            roundedRect: borderView.bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerRadius: cornerRadius - 0.5
        ).cgPath
    }
}

extension LMPreShootPlanButtonView {

    /// Updates mode label/icon and whether the chip can open the mode sheet.
    func setMode(_ mode: LMPreShootPlanMode, modeSwitchEnabled: Bool) {
        self.mode = mode
        self.modeSwitchEnabled = modeSwitchEnabled
        refreshContent()
    }

    var currentMode: LMPreShootPlanMode { mode }

    func setEnabledForCamera(_ enabled: Bool) {
        isEnabledForCamera = enabled
        alpha = enabled ? 1 : 0.5
    }

    func updateInspirePointsCount(_ points: Int) {
        inspirePoints = max(0, points)
    }

    func decrementInspirePointsCount() {}

    func getCurrentInspirePoints() -> Int { inspirePoints }

    /// Compatibility alias used by existing camera session code.
    func setInspireMeButtonEnabled(_ enabled: Bool) {
        setEnabledForCamera(enabled)
    }
}

private extension LMPreShootPlanButtonView {

    func setup() {
        addSubview(depthShadowView)
        addSubview(glassPanel)
        glassPanel.contentView.addSubview(fillOverlay)
        addSubview(borderView)
        addSubview(mainButton)
        mainButton.addSubview(contentStack)

        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 6
        contentStack.isUserInteractionEnabled = false

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = LMLiquidGlassHUDTokens.textPrimary

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = LMLiquidGlassHUDTokens.textPrimary
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        chevronView.image = UIImage(systemName: "chevron.down", withConfiguration: chevronConfig)
        chevronView.tintColor = LMLiquidGlassHUDTokens.textSecondary
        chevronView.contentMode = .scaleAspectFit

        let qConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        questionButton.setImage(UIImage(systemName: "questionmark.circle", withConfiguration: qConfig), for: .normal)
        questionButton.tintColor = LMLiquidGlassHUDTokens.textSecondary
        questionButton.addTarget(self, action: #selector(handleHint), for: .touchUpInside)

        contentStack.addArrangedSubview(iconView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(chevronView)

        mainButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        addSubview(questionButton)
    }

    func configureLayout() {
        depthShadowView.snp.makeConstraints { $0.edges.equalToSuperview() }
        glassPanel.snp.makeConstraints { $0.edges.equalToSuperview() }
        fillOverlay.snp.makeConstraints { $0.edges.equalToSuperview() }
        borderView.snp.makeConstraints { $0.edges.equalToSuperview() }
        mainButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        contentStack.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(12)
            make.trailing.lessThanOrEqualTo(questionButton.snp.leading).offset(-4)
        }
        iconView.snp.makeConstraints { $0.size.equalTo(16) }
        chevronView.snp.makeConstraints { $0.size.equalTo(10) }
        questionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.size.equalTo(22)
        }
    }

    /**
     Applies Liquid Glass HUD styling: translucent fill, soft depth, Agent accent stroke.
     */
    func applyStyle() {
        backgroundColor = .clear
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = false

        depthShadowView.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        depthShadowView.layer.cornerRadius = cornerRadius
        depthShadowView.layer.shadowColor = UIColor.black.cgColor
        depthShadowView.layer.shadowOpacity = 0.35
        depthShadowView.layer.shadowRadius = 8
        depthShadowView.layer.shadowOffset = CGSize(width: 0, height: 3)
        depthShadowView.isUserInteractionEnabled = false

        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: .regular)
            effect.isInteractive = true
            glassPanel.effect = effect
        } else {
            glassPanel.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        }
        glassPanel.layer.cornerRadius = cornerRadius
        glassPanel.clipsToBounds = true

        fillOverlay.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        fillOverlay.isUserInteractionEnabled = false

        borderView.backgroundColor = .clear
        borderView.isUserInteractionEnabled = false
        borderView.layer.cornerRadius = cornerRadius

        accentStrokeLayer.colors = LMLiquidGlassHUDTokens.agentAccentBorderColors.map { $0.cgColor }
        accentStrokeLayer.startPoint = CGPoint(x: 0, y: 0.5)
        accentStrokeLayer.endPoint = CGPoint(x: 1, y: 0.5)
        accentStrokeMask.fillColor = UIColor.clear.cgColor
        accentStrokeMask.strokeColor = UIColor.white.cgColor
        accentStrokeMask.lineWidth = 1.0
        accentStrokeLayer.mask = accentStrokeMask
        borderView.layer.addSublayer(accentStrokeLayer)

        borderView.layer.borderWidth = 0.5
        borderView.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor

        mainButton.backgroundColor = .clear
        mainButton.adjustsImageWhenHighlighted = false
    }

    func refreshContent() {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        iconView.image = LMPreShootPlanSymbols.icon(for: mode, configuration: symbolConfig)
        switch mode {
        case .camera:
            titleLabel.text = LMText.camera.preShootPlanButtonCamera
        case .findSpot:
            titleLabel.text = LMText.camera.preShootPlanButtonFindSpot
        case .composition:
            titleLabel.text = LMText.camera.preShootPlanButtonComposition
        }
        chevronView.isHidden = !modeSwitchEnabled
        accentStrokeLayer.isHidden = !mode.isAIShutter
    }

    @objc func handleTap() {
        guard !isHidden else { return }
        if !isEnabledForCamera {
            delegate?.preShootPlanButtonDidTapDisabled()
            return
        }
        guard modeSwitchEnabled else { return }
        delegate?.preShootPlanButtonDidTap()
    }

    @objc func handleHint() {
        delegate?.preShootPlanButtonDidTapHint()
    }
}
