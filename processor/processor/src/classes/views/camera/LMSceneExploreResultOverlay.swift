//
//  LMSceneExploreResultOverlay.swift
//  processor
//
//  Scene Explore result: freeze/heatmap base, pulsing spot dots, description card + CTAs.
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

/// Full-screen Explore result UI over the camera preview canvas.
final class LMSceneExploreResultOverlay: UIView {

    weak var delegate: LMSceneExploreResultOverlayDelegate?

    private let imageView = UIImageView()
    private let spotsContainer = UIView()
    private let backButton = UIButton(type: .system)
    private let card = UIView()
    private let cardTitle = UILabel()
    private let cardReason = UILabel()
    private let cardCloseButton = UIButton(type: .system)
    private let goToSpotButton = UIButton(type: .system)
    private let getTemplateButton = UIButton(type: .system)

    private var freezeImage: UIImage?
    private var heatmapImage: UIImage?
    private var spots: [LMSceneExploreSpot] = []
    private var selectedSpot: LMSceneExploreSpot?
    private var generatedSpotIds: Set<String> = []
    private var showHeatmap = false
    private var isCardVisible = false
    private var isRebuildingDots = false

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
       - image: Clean freeze frame.
       - heatmap: Precomposed heatmap (used when `showHeatmap` is true).
       - showHeatmap: Whether to display heatmap base + pulsing dots.
       - spots: Parsed VLM spots.
       - selectedSpotId: Initially selected spot (card shown when non-nil).
       - generatedSpotIds: Spots that already have templates.
     */
    func configure(
        image: UIImage,
        heatmap: UIImage? = nil,
        showHeatmap: Bool,
        spots: [LMSceneExploreSpot],
        selectedSpotId: String? = nil,
        generatedSpotIds: Set<String> = []
    ) {
        freezeImage = image
        heatmapImage = heatmap
        self.showHeatmap = showHeatmap && heatmap != nil
        self.spots = spots
        self.generatedSpotIds = generatedSpotIds
        selectedSpot = spots.first { $0.id == selectedSpotId } ?? spots.first
        isCardVisible = selectedSpot != nil
        refreshBaseImage()
        rebuildSpotDots()
        refreshCard()
        isHidden = false
    }

    func markGenerated(spotId: String) {
        generatedSpotIds.insert(spotId)
        refreshCard()
    }

    func selectSpot(id: String) {
        selectedSpot = spots.first { $0.id == id }
        isCardVisible = selectedSpot != nil
        refreshCard()
        rebuildSpotDots()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildSpotDots()
    }
}

private extension LMSceneExploreResultOverlay {

    func setup() {
        backgroundColor = .black
        addSubview(imageView)
        addSubview(spotsContainer)
        addSubview(backButton)
        addSubview(card)

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = false
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }

        spotsContainer.backgroundColor = .clear
        spotsContainer.isUserInteractionEnabled = true
        spotsContainer.snp.makeConstraints { $0.edges.equalTo(imageView) }
        let blankTap = UITapGestureRecognizer(target: self, action: #selector(handleBlankTap))
        blankTap.cancelsTouchesInView = false
        spotsContainer.addGestureRecognizer(blankTap)

        let chevron = UIImage(systemName: "chevron.left")
        backButton.setImage(chevron, for: .normal)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        backButton.snp.makeConstraints { make in
            make.leading.equalTo(safeAreaLayoutGuide).offset(12)
            make.top.equalTo(safeAreaLayoutGuide).offset(8)
            make.size.equalTo(36)
        }

        card.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        card.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-16)
        }

        cardTitle.font = .systemFont(ofSize: 18, weight: .bold)
        cardTitle.textColor = .white
        cardTitle.numberOfLines = 1

        cardReason.font = .systemFont(ofSize: 14, weight: .regular)
        cardReason.textColor = UIColor.white.withAlphaComponent(0.88)
        cardReason.numberOfLines = 3

        cardCloseButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        cardCloseButton.tintColor = .white
        cardCloseButton.addTarget(self, action: #selector(handleCardClose), for: .touchUpInside)

        stylePrimaryButton(goToSpotButton, title: LMText.camera.ctaGoToSpot)
        styleSecondaryButton(getTemplateButton, title: LMText.camera.ctaGenerateSpotComposition)
        goToSpotButton.addTarget(self, action: #selector(handleGoToSpot), for: .touchUpInside)
        getTemplateButton.addTarget(self, action: #selector(handleGetTemplate), for: .touchUpInside)

        [cardTitle, cardReason, cardCloseButton, goToSpotButton, getTemplateButton].forEach {
            card.addSubview($0)
        }
        cardCloseButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(12)
            make.size.equalTo(28)
        }
        cardTitle.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16)
            make.trailing.equalTo(cardCloseButton.snp.leading).offset(-8)
        }
        cardReason.snp.makeConstraints { make in
            make.top.equalTo(cardTitle.snp.bottom).offset(6)
            make.leading.equalToSuperview().inset(16)
            make.trailing.equalTo(cardCloseButton.snp.leading).offset(-8)
        }
        goToSpotButton.snp.makeConstraints { make in
            make.top.equalTo(cardReason.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
        }
        getTemplateButton.snp.makeConstraints { make in
            make.top.equalTo(goToSpotButton.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(44)
            make.bottom.equalToSuperview().inset(16)
        }
    }

    func stylePrimaryButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.backgroundColor = UIColor.hexColor("#6680E6")
        button.layer.cornerRadius = 12
    }

    func styleSecondaryButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
    }

    func refreshBaseImage() {
        if showHeatmap, let heatmapImage {
            imageView.image = heatmapImage
        } else {
            imageView.image = freezeImage
        }
    }

    /// Aspect-fit rect of the displayed image inside `imageView`.
    func imageContentRect() -> CGRect {
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else {
            return imageView.bounds
        }
        let bounds = imageView.bounds
        let imageRatio = image.size.width / image.size.height
        let viewRatio = bounds.width / max(bounds.height, 0.001)
        if imageRatio > viewRatio {
            let height = bounds.width / imageRatio
            let y = (bounds.height - height) / 2
            return CGRect(x: 0, y: y, width: bounds.width, height: height)
        } else {
            let width = bounds.height * imageRatio
            let x = (bounds.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: bounds.height)
        }
    }

    func rebuildSpotDots() {
        guard !isRebuildingDots else { return }
        isRebuildingDots = true
        defer { isRebuildingDots = false }
        spotsContainer.subviews.forEach { $0.removeFromSuperview() }
        layoutIfNeeded()

        // Dots only when heatmap is shown (SPEC).
        guard showHeatmap else { return }
        let content = imageContentRect()
        guard content.width > 1, content.height > 1 else { return }

        for spot in spots {
            let center = spot.center
            let point = CGPoint(
                x: content.minX + center.x * content.width,
                y: content.minY + center.y * content.height
            )
            let isSelected = isCardVisible && spot.id == selectedSpot?.id
            let size: CGFloat = isSelected ? 20 : 16
            let dot = UIView(frame: CGRect(
                x: point.x - size / 2,
                y: point.y - size / 2,
                width: size,
                height: size
            ))
            dot.backgroundColor = UIColor.white.withAlphaComponent(0.92)
            dot.layer.cornerRadius = size / 2
            dot.layer.shadowColor = UIColor.white.cgColor
            dot.layer.shadowOpacity = 0.85
            dot.layer.shadowRadius = 8
            dot.layer.shadowOffset = .zero
            spotsContainer.addSubview(dot)

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleSpotTap(_:)))
            dot.addGestureRecognizer(tap)
            dot.isUserInteractionEnabled = true
            dot.accessibilityIdentifier = spot.id

            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 1
            pulse.toValue = 1.4
            pulse.duration = 0.95
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dot.layer.add(pulse, forKey: "pulse")
        }
    }

    func refreshCard() {
        guard isCardVisible, let spot = selectedSpot else {
            card.isHidden = true
            return
        }
        card.isHidden = false
        cardTitle.text = spot.name
        if let warning = spot.safetyWarning, !warning.isEmpty {
            cardReason.text = "\(spot.reason)\n⚠️ \(warning)"
        } else {
            cardReason.text = spot.reason
        }
        let templateTitle = generatedSpotIds.contains(spot.id)
            ? LMText.camera.ctaViewCompositions
            : LMText.camera.ctaGenerateSpotComposition
        getTemplateButton.setTitle(templateTitle, for: .normal)
    }

    @objc func handleBack() {
        delegate?.sceneExploreResultOverlayDidTapBack()
    }

    @objc func handleCardClose() {
        isCardVisible = false
        refreshCard()
        rebuildSpotDots()
        delegate?.sceneExploreResultOverlayDidDismissCard()
    }

    @objc func handleBlankTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: spotsContainer)
        if spotsContainer.hitTest(point, with: nil) !== spotsContainer {
            return
        }
        if isCardVisible {
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

    @objc func handleSpotTap(_ gesture: UITapGestureRecognizer) {
        guard let id = gesture.view?.accessibilityIdentifier,
              let spot = spots.first(where: { $0.id == id }) else { return }
        selectedSpot = spot
        isCardVisible = true
        refreshCard()
        rebuildSpotDots()
        delegate?.sceneExploreResultOverlayDidSelectSpot(spot)
    }
}
