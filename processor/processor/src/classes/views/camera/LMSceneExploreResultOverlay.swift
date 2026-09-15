//
//  LMSceneExploreResultOverlay.swift
//  processor
//
//  Scene Explore result: freeze/heatmap base, pulsing spot dots, floating card + CTAs.
//  Camera preview slot: ContentScale.Crop (cover). History browse: ContentScale.Fit (letterbox).
//

import UIKit
import SnapKit

protocol LMSceneExploreResultOverlayDelegate: AnyObject {
    func sceneExploreResultOverlayDidSelectSpot(_ spot: LMSceneExploreSpot)
    func sceneExploreResultOverlayDidTapGoToSpot(_ spot: LMSceneExploreSpot)
    func sceneExploreResultOverlayDidTapGetTemplate(_ spot: LMSceneExploreSpot)
    func sceneExploreResultOverlayDidTapBack()
    func sceneExploreResultOverlayDidDismissCard()
}

/// Chrome for embedding in camera preview slot vs Mine History fullscreen browse.
enum LMSceneExploreResultChrome {
    /// Nested in camera preview canvas — no in-overlay back (camera top bar owns it).
    case cameraPreviewSlot
    /// Fullscreen black History browse — circular back, no exit confirm.
    case historyBrowse
}

/// Explore result UI: freeze base + dots + spot card. Crop in camera slot; Fit in history browse.
final class LMSceneExploreResultOverlay: UIView {

    weak var delegate: LMSceneExploreResultOverlayDelegate?

    private let imageView = UIImageView()
    /// Soft heatmap drawn on top of the freeze frame (transparent elsewhere).
    private let heatmapOverlayView = UIImageView()
    private let spotsContainer = UIView()
    private let backButton = UIButton(type: .system)
    private let card = UIView()
    private let cardTitle = UILabel()
    private let cardReason = UILabel()
    private let cardCloseButton = UIButton(type: .system)
    private let goToSpotButton = UIButton(type: .system)
    private let getTemplateButton = UIButton(type: .system)
    private let cardContentStack = UIStackView()

    private var freezeImage: UIImage?
    private var heatmapImage: UIImage?
    private var spots: [LMSceneExploreSpot] = []
    private var selectedSpot: LMSceneExploreSpot?
    private var generatedSpotIds: Set<String> = []
    /// When true, bake heatmap into display and show pulsing dots.
    private var showDots = false
    private var isCardVisible = false
    private var isRebuildingDots = false
    private var chrome: LMSceneExploreResultChrome = .cameraPreviewSlot
    private var spotCentersInView: [(spot: LMSceneExploreSpot, point: CGPoint)] = []
    private var lastLaidOutBounds: CGSize = .zero
    private var dotsNeedRebuild = true

    private enum Metrics {
        static let dotDiameter: CGFloat = 20
        static let hitRadius: CGFloat = 28
        static let cardMaxWidth: CGFloat = 220
        static let cardBelowSpot: CGFloat = 18
        static let edgeInset: CGFloat = 12
        static let bottomReserve: CGFloat = 120
        static let cardCorner: CGFloat = 18
        static let ctaCorner: CGFloat = 8
        static let cardPaddingH: CGFloat = 14
        static let cardPaddingV: CGFloat = 12
        static let closeHit: CGFloat = 28
        static let textTrailingForClose: CGFloat = 20
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /**
     Binds freeze frame / optional heatmap + spots and shows the overlay.

     - Parameters:
       - image: Clean freeze frame (always shown as the base).
       - heatmap: Soft glow overlay drawn on top when `showHeatmap` is true.
       - showHeatmap: Whether to display heatmap overlay + pulsing dots.
       - spots: Parsed VLM spots.
       - selectedSpotId: Initially selected spot (card shown only when non-nil and found).
       - generatedSpotIds: Spots that already have templates.
       - chrome: Camera slot vs History browse chrome.
     */
    func configure(
        image: UIImage,
        heatmap: UIImage? = nil,
        showHeatmap: Bool,
        spots: [LMSceneExploreSpot],
        selectedSpotId: String? = nil,
        generatedSpotIds: Set<String> = [],
        chrome: LMSceneExploreResultChrome = .cameraPreviewSlot
    ) {
        freezeImage = image
        heatmapImage = heatmap
        self.chrome = chrome
        self.showDots = showHeatmap && heatmap != nil && !spots.isEmpty
        self.spots = spots
        self.generatedSpotIds = generatedSpotIds
        selectedSpot = selectedSpotId.flatMap { id in spots.first { $0.id == id } }
        isCardVisible = selectedSpot != nil
        dotsNeedRebuild = true
        applyChrome()
        refreshBaseImage()
        setNeedsLayout()
        isHidden = false
    }

    func markGenerated(spotId: String) {
        generatedSpotIds.insert(spotId)
        refreshCardContent()
    }

    func selectSpot(id: String) {
        selectedSpot = spots.first { $0.id == id }
        isCardVisible = selectedSpot != nil
        refreshCardContent()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let sizeChanged = bounds.size != lastLaidOutBounds
        if sizeChanged || dotsNeedRebuild {
            lastLaidOutBounds = bounds.size
            dotsNeedRebuild = false
            rebuildSpotDots()
        } else {
            refreshSpotCentersOnly()
        }
        positionFloatingCard()
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if view === self || view === spotsContainer || view === imageView || view === heatmapOverlayView {
            return spotsContainer
        }
        return view
    }
}

private extension LMSceneExploreResultOverlay {

    func setup() {
        backgroundColor = .black
        clipsToBounds = true

        addSubview(imageView)
        addSubview(heatmapOverlayView)
        addSubview(spotsContainer)
        addSubview(card)
        addSubview(backButton)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }

        heatmapOverlayView.contentMode = .scaleAspectFill
        heatmapOverlayView.clipsToBounds = true
        heatmapOverlayView.isUserInteractionEnabled = false
        heatmapOverlayView.snp.makeConstraints { $0.edges.equalToSuperview() }

        spotsContainer.backgroundColor = .clear
        spotsContainer.isUserInteractionEnabled = true
        spotsContainer.snp.makeConstraints { $0.edges.equalToSuperview() }
        let canvasTap = UITapGestureRecognizer(target: self, action: #selector(handleCanvasTap(_:)))
        spotsContainer.addGestureRecognizer(canvasTap)

        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .white
        backButton.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        backButton.layer.cornerRadius = 18
        backButton.clipsToBounds = true
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        backButton.snp.makeConstraints { make in
            make.leading.equalTo(safeAreaLayoutGuide).offset(12)
            make.top.equalTo(safeAreaLayoutGuide).offset(8)
            make.size.equalTo(36)
        }

        card.backgroundColor = UIColor.hexColor("#404040").withAlphaComponent(0.85)
        card.layer.cornerRadius = Metrics.cardCorner
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor
        card.clipsToBounds = true
        card.isHidden = true
        card.translatesAutoresizingMaskIntoConstraints = true

        cardTitle.font = .systemFont(ofSize: 15, weight: .semibold)
        cardTitle.textColor = .white
        cardTitle.numberOfLines = 2

        cardReason.font = .systemFont(ofSize: 13, weight: .regular)
        cardReason.textColor = UIColor.white.withAlphaComponent(0.88)
        cardReason.numberOfLines = 4

        cardCloseButton.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)), for: .normal)
        cardCloseButton.tintColor = UIColor.white.withAlphaComponent(0.9)
        cardCloseButton.addTarget(self, action: #selector(handleCardClose), for: .touchUpInside)

        stylePrimaryButton(goToSpotButton, title: LMText.camera.ctaGoToSpot)
        styleSecondaryButton(getTemplateButton, title: LMText.camera.ctaGenerateSpotComposition)
        goToSpotButton.addTarget(self, action: #selector(handleGoToSpot), for: .touchUpInside)
        getTemplateButton.addTarget(self, action: #selector(handleGetTemplate), for: .touchUpInside)

        let textColumn = UIStackView(arrangedSubviews: [cardTitle, cardReason])
        textColumn.axis = .vertical
        textColumn.spacing = 6
        textColumn.alignment = .fill

        let headerRow = UIStackView(arrangedSubviews: [textColumn, cardCloseButton])
        headerRow.axis = .horizontal
        headerRow.alignment = .top
        headerRow.spacing = 4
        cardCloseButton.snp.makeConstraints { $0.size.equalTo(Metrics.closeHit) }

        let ctaColumn = UIStackView(arrangedSubviews: [goToSpotButton, getTemplateButton])
        ctaColumn.axis = .vertical
        ctaColumn.spacing = 8
        ctaColumn.alignment = .fill
        goToSpotButton.snp.makeConstraints { $0.height.equalTo(36) }
        getTemplateButton.snp.makeConstraints { $0.height.equalTo(36) }

        cardContentStack.axis = .vertical
        cardContentStack.spacing = 10
        cardContentStack.alignment = .fill
        cardContentStack.addArrangedSubview(headerRow)
        cardContentStack.addArrangedSubview(ctaColumn)
        card.addSubview(cardContentStack)
        cardContentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(
                UIEdgeInsets(
                    top: Metrics.cardPaddingV,
                    left: Metrics.cardPaddingH,
                    bottom: Metrics.cardPaddingV,
                    right: Metrics.cardPaddingH
                )
            )
        }
    }

    func applyChrome() {
        switch chrome {
        case .cameraPreviewSlot:
            backButton.isHidden = true
            backgroundColor = .clear
            // Match live preview slot: cover / crop edges.
            imageView.contentMode = .scaleAspectFill
            heatmapOverlayView.contentMode = .scaleAspectFill
        case .historyBrowse:
            backButton.isHidden = false
            backgroundColor = .black
            // Full cover visible with letterboxing; no crop or fill.
            imageView.contentMode = .scaleAspectFit
            heatmapOverlayView.contentMode = .scaleAspectFit
        }
    }

    func stylePrimaryButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        button.layer.cornerRadius = Metrics.ctaCorner
        button.layer.borderWidth = 0
    }

    func styleSecondaryButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        button.layer.cornerRadius = Metrics.ctaCorner
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
    }

    func refreshBaseImage() {
        // Always show the captured freeze frame; heatmap is a separate soft overlay.
        imageView.image = freezeImage
        if showDots, let heatmapImage {
            heatmapOverlayView.image = heatmapImage
            heatmapOverlayView.isHidden = false
        } else {
            heatmapOverlayView.image = nil
            heatmapOverlayView.isHidden = true
        }
    }

    /**
     Drawn image rect inside bounds for spot mapping.
     - Camera preview slot: Crop (`max` scale) — matches live preview cover.
     - History browse: Fit (`min` scale) — full image letterboxed on black.
     */
    func imageContentRect() -> CGRect {
        guard let image = freezeImage ?? imageView.image, image.size.width > 0, image.size.height > 0 else {
            return bounds
        }
        let boxW = bounds.width
        let boxH = bounds.height
        let imgW = image.size.width
        let imgH = image.size.height
        let scale: CGFloat
        switch chrome {
        case .cameraPreviewSlot:
            scale = max(boxW / imgW, boxH / imgH)
        case .historyBrowse:
            scale = min(boxW / imgW, boxH / imgH)
        }
        let drawnW = imgW * scale
        let drawnH = imgH * scale
        let offsetX = (boxW - drawnW) / 2
        let offsetY = (boxH - drawnH) / 2
        return CGRect(x: offsetX, y: offsetY, width: drawnW, height: drawnH)
    }

    func pointOnCanvas(for spot: LMSceneExploreSpot, content: CGRect) -> CGPoint {
        let center = spot.center
        return CGPoint(
            x: content.minX + center.x * content.width,
            y: content.minY + center.y * content.height
        )
    }

    func rebuildSpotDots() {
        guard !isRebuildingDots else { return }
        isRebuildingDots = true
        defer { isRebuildingDots = false }

        spotsContainer.subviews.forEach { $0.removeFromSuperview() }
        spotCentersInView.removeAll()

        guard showDots, !spots.isEmpty, bounds.width > 1, bounds.height > 1 else { return }
        let content = imageContentRect()
        guard content.width > 1, content.height > 1 else { return }

        let size = Metrics.dotDiameter
        for spot in spots {
            let point = pointOnCanvas(for: spot, content: content)
            spotCentersInView.append((spot, point))

            let dot = UIView(frame: CGRect(
                x: point.x - size / 2,
                y: point.y - size / 2,
                width: size,
                height: size
            ))
            dot.isUserInteractionEnabled = false
            dot.backgroundColor = .white
            dot.layer.cornerRadius = size / 2
            dot.layer.borderWidth = 1.5
            dot.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
            spotsContainer.addSubview(dot)
            addBreathingAnimation(to: dot.layer)
        }
    }

    /// Updates hit-test centers / frames without restarting pulse animations.
    func refreshSpotCentersOnly() {
        guard showDots, !spots.isEmpty, spotsContainer.subviews.count == spots.count else { return }
        let content = imageContentRect()
        let size = Metrics.dotDiameter
        spotCentersInView.removeAll()
        for (index, spot) in spots.enumerated() {
            let point = pointOnCanvas(for: spot, content: content)
            spotCentersInView.append((spot, point))
            guard index < spotsContainer.subviews.count else { continue }
            spotsContainer.subviews[index].frame = CGRect(
                x: point.x - size / 2,
                y: point.y - size / 2,
                width: size,
                height: size
            )
        }
    }

    func addBreathingAnimation(to layer: CALayer) {
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.85
        scale.toValue = 1.25

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.45
        opacity.toValue = 0.95

        let group = CAAnimationGroup()
        group.animations = [scale, opacity]
        group.duration = 0.9
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.isRemovedOnCompletion = false
        layer.add(group, forKey: "breathe")
    }

    func refreshCardContent() {
        guard isCardVisible, let spot = selectedSpot else {
            card.isHidden = true
            return
        }
        card.isHidden = false
        cardTitle.text = spot.name
        let reason = spot.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        cardReason.text = reason
        cardReason.isHidden = reason.isEmpty
        let templateTitle = generatedSpotIds.contains(spot.id)
            ? LMText.camera.ctaViewCompositions
            : LMText.camera.ctaGenerateSpotComposition
        getTemplateButton.setTitle(templateTitle, for: .normal)
        card.setNeedsLayout()
        card.layoutIfNeeded()
    }

    func positionFloatingCard() {
        refreshCardContent()
        guard isCardVisible, let spot = selectedSpot, !card.isHidden else {
            card.isHidden = true
            return
        }

        let content = imageContentRect()
        let anchor = pointOnCanvas(for: spot, content: content)
        let maxWidth = min(Metrics.cardMaxWidth, max(0, bounds.width - Metrics.edgeInset * 2))
        let targetSize = card.systemLayoutSizeFitting(
            CGSize(width: maxWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        let cardW = min(maxWidth, max(targetSize.width, 120))
        let cardH = targetSize.height

        var originX = anchor.x - cardW / 2
        var originY = anchor.y + Metrics.cardBelowSpot

        let minX = Metrics.edgeInset
        let maxX = bounds.width - Metrics.edgeInset - cardW
        originX = min(max(originX, minX), max(minX, maxX))

        let minY = Metrics.edgeInset
        let maxY = bounds.height - Metrics.bottomReserve - cardH
        if maxY >= minY {
            originY = min(max(originY, minY), maxY)
        } else {
            // Very short slot: keep top inset and allow overlapping bottom reserve.
            originY = minY
        }

        card.frame = CGRect(x: originX, y: originY, width: cardW, height: cardH)
        bringSubviewToFront(card)
        if chrome == .historyBrowse {
            bringSubviewToFront(backButton)
        }
    }

    func nearestSpot(to point: CGPoint, maxDistance: CGFloat) -> LMSceneExploreSpot? {
        var best: (LMSceneExploreSpot, CGFloat)?
        for entry in spotCentersInView {
            let d = hypot(entry.point.x - point.x, entry.point.y - point.y)
            if d <= maxDistance {
                if best == nil || d < best!.1 {
                    best = (entry.spot, d)
                }
            }
        }
        return best?.0
    }

    @objc func handleBack() {
        delegate?.sceneExploreResultOverlayDidTapBack()
    }

    @objc func handleCardClose() {
        isCardVisible = false
        selectedSpot = nil
        refreshCardContent()
        delegate?.sceneExploreResultOverlayDidDismissCard()
    }

    @objc func handleCanvasTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: spotsContainer)
        if let spot = nearestSpot(to: point, maxDistance: Metrics.hitRadius) {
            selectedSpot = spot
            isCardVisible = true
            setNeedsLayout()
            delegate?.sceneExploreResultOverlayDidSelectSpot(spot)
            return
        }
        if isCardVisible {
            // Tap outside card dismisses; card is a sibling so this only fires on canvas.
            if !card.isHidden, card.frame.contains(convert(point, from: spotsContainer)) {
                return
            }
            handleCardClose()
        }
    }

    @objc func handleGoToSpot() {
        guard let spot = selectedSpot else { return }
        delegate?.sceneExploreResultOverlayDidTapGoToSpot(spot)
    }

    @objc func handleGetTemplate() {
        guard let spot = selectedSpot else { return }
        delegate?.sceneExploreResultOverlayDidTapGetTemplate(spot)
    }
}
