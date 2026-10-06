//
//  LMPreShootPlanModePanelView.swift
//  processor
//
//  Shared Camera / Find Spot / Get Template mode list for the live sheet and tutorial.
//

import UIKit
import SnapKit

/**
 Vertical mode-chooser panel shared by `LMPreShootPlanModeSheet` and Mode help.

 - Parameter isInteractive: When false, taps are ignored (tutorial miniature).
 */
final class LMPreShootPlanModePanelView: UIView {

    var onSelect: ((LMPreShootPlanMode) -> Void)?

    private let titleLabel = UILabel()
    private let stack = UIStackView()
    private let cameraButton = UIButton(type: .system)
    private let findSpotButton = UIButton(type: .system)
    private let compositionButton = UIButton(type: .system)

    private let isInteractive: Bool
    private var selectedMode: LMPreShootPlanMode

    /**
     Creates a mode panel.

     - Parameters:
       - isInteractive: Whether row taps fire `onSelect`.
       - selected: Initially highlighted mode.
     */
    init(isInteractive: Bool, selected: LMPreShootPlanMode = .findSpot) {
        self.isInteractive = isInteractive
        self.selectedMode = selected
        super.init(frame: .zero)
        setup()
        refreshSelection()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /**
     Updates the highlighted row.

     - Parameter mode: Mode to highlight.
     */
    func setSelected(_ mode: LMPreShootPlanMode) {
        selectedMode = mode
        refreshSelection()
    }

    /// Reloads localized titles (call after language change if needed).
    func refreshLocalizedTitles() {
        applyTitle(cameraButton, title: LMText.camera.preShootPlanButtonCamera)
        applyTitle(findSpotButton, title: LMText.camera.preShootPlanButtonFindSpot)
        applyTitle(compositionButton, title: LMText.camera.preShootPlanButtonComposition)
        titleLabel.text = LMText.camera.preShootPlanModeSheetTitle
    }
}

private extension LMPreShootPlanModePanelView {

    func setup() {
        backgroundColor = UIColor.white.withAlphaComponent(0.14)
        layer.cornerRadius = 18
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor

        titleLabel.text = LMText.camera.preShootPlanModeSheetTitle
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = LMLiquidGlassHUDTokens.textSecondary
        titleLabel.textAlignment = .center

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        styleModeButton(
            cameraButton,
            title: LMText.camera.preShootPlanButtonCamera,
            image: LMPreShootPlanSymbols.camera(configuration: symbolConfig)
        )
        styleModeButton(
            findSpotButton,
            title: LMText.camera.preShootPlanButtonFindSpot,
            image: LMPreShootPlanSymbols.findSpot(configuration: symbolConfig)
        )
        styleModeButton(
            compositionButton,
            title: LMText.camera.preShootPlanButtonComposition,
            image: LMPreShootPlanSymbols.composition(configuration: symbolConfig)
        )

        if isInteractive {
            cameraButton.addTarget(self, action: #selector(handleCamera), for: .touchUpInside)
            findSpotButton.addTarget(self, action: #selector(handleFindSpot), for: .touchUpInside)
            compositionButton.addTarget(self, action: #selector(handleComposition), for: .touchUpInside)
        } else {
            [cameraButton, findSpotButton, compositionButton].forEach {
                $0.isUserInteractionEnabled = false
            }
        }

        stack.axis = .vertical
        stack.spacing = 8
        stack.distribution = .fillEqually
        [cameraButton, findSpotButton, compositionButton].forEach { stack.addArrangedSubview($0) }

        addSubview(titleLabel)
        addSubview(stack)

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        stack.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(10)
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalToSuperview().offset(-12)
            make.height.equalTo(168)
        }
    }

    func styleModeButton(_ button: UIButton, title: String, image: UIImage?) {
        var config = UIButton.Configuration.plain()
        config.image = image
        config.title = title
        config.imagePlacement = .leading
        config.imagePadding = 12
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14)
        config.baseForegroundColor = LMLiquidGlassHUDTokens.textPrimary
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 14, weight: .semibold)
            return out
        }
        button.configuration = config
        button.contentHorizontalAlignment = .leading
        button.layer.cornerRadius = 12
        button.backgroundColor = UIColor.white.withAlphaComponent(0.08)
    }

    func applyTitle(_ button: UIButton, title: String) {
        guard var config = button.configuration else { return }
        config.title = title
        button.configuration = config
    }

    func refreshSelection() {
        applySelection(cameraButton, selected: selectedMode == .camera)
        applySelection(findSpotButton, selected: selectedMode == .findSpot)
        applySelection(compositionButton, selected: selectedMode == .composition)
    }

    func applySelection(_ button: UIButton, selected: Bool) {
        button.layer.borderWidth = selected ? 1.5 : 0
        button.layer.borderColor = UIColor.hexColor("#6680E6").cgColor
        button.backgroundColor = selected
            ? UIColor.white.withAlphaComponent(0.18)
            : UIColor.white.withAlphaComponent(0.08)
    }

    @objc func handleCamera() { onSelect?(.camera) }
    @objc func handleFindSpot() { onSelect?(.findSpot) }
    @objc func handleComposition() { onSelect?(.composition) }
}
