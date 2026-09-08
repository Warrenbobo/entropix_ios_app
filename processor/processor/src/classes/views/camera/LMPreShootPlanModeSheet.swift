//
//  LMPreShootPlanModeSheet.swift
//  processor
//
//  Mode picker: 1-column × 3-row list expanding downward from the mode chip.
//

import UIKit
import SnapKit

protocol LMPreShootPlanModeSheetDelegate: AnyObject {
    func preShootPlanModeSheetDidSelect(_ mode: LMPreShootPlanMode)
    func preShootPlanModeSheetDidDismiss()
}

/// Fullscreen dimmed overlay with a vertical mode panel below the top mode chip.
final class LMPreShootPlanModeSheet: UIView {

    weak var delegate: LMPreShootPlanModeSheetDelegate?

    private let dimView = UIControl()
    private let panel = UIView()
    private let titleLabel = UILabel()
    private let stack = UIStackView()
    private let cameraButton = UIButton(type: .system)
    private let findSpotButton = UIButton(type: .system)
    private let compositionButton = UIButton(type: .system)

    private var selectedMode: LMPreShootPlanMode = .findSpot

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /**
     Shows the sheet in `host`, anchoring the panel below `anchor`.

     - Parameters:
       - host: Parent view (typically the camera page view).
       - anchor: Mode chip frame in host coordinates.
       - selected: Currently selected mode.
     */
    func present(in host: UIView, below anchor: UIView, selected: LMPreShootPlanMode) {
        selectedMode = selected
        refreshSelection()
        frame = host.bounds
        host.addSubview(self)
        snp.makeConstraints { $0.edges.equalToSuperview() }

        let anchorFrame = anchor.convert(anchor.bounds, to: host)
        panel.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.width.equalTo(220)
            make.top.equalToSuperview().offset(anchorFrame.maxY + 8)
        }
        alpha = 0
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
    }

    /// Compatibility: older call sites anchored “above” the shutter-area button.
    func present(in host: UIView, above anchor: UIView, selected: LMPreShootPlanMode) {
        present(in: host, below: anchor, selected: selected)
    }

    func dismiss() {
        UIView.animate(withDuration: 0.15, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
            self.delegate?.preShootPlanModeSheetDidDismiss()
        }
    }
}

private extension LMPreShootPlanModeSheet {

    func setup() {
        addSubview(dimView)
        addSubview(panel)
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimView.addTarget(self, action: #selector(handleDim), for: .touchUpInside)
        dimView.snp.makeConstraints { $0.edges.equalToSuperview() }

        panel.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        panel.layer.cornerRadius = 18
        panel.layer.borderWidth = 1
        panel.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor

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
        cameraButton.addTarget(self, action: #selector(handleCamera), for: .touchUpInside)
        findSpotButton.addTarget(self, action: #selector(handleFindSpot), for: .touchUpInside)
        compositionButton.addTarget(self, action: #selector(handleComposition), for: .touchUpInside)

        stack.axis = .vertical
        stack.spacing = 8
        stack.distribution = .fillEqually
        [cameraButton, findSpotButton, compositionButton].forEach { stack.addArrangedSubview($0) }

        panel.addSubview(titleLabel)
        panel.addSubview(stack)

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

    @objc func handleDim() { dismiss() }

    @objc func handleCamera() {
        delegate?.preShootPlanModeSheetDidSelect(.camera)
        dismiss()
    }

    @objc func handleFindSpot() {
        delegate?.preShootPlanModeSheetDidSelect(.findSpot)
        dismiss()
    }

    @objc func handleComposition() {
        delegate?.preShootPlanModeSheetDidSelect(.composition)
        dismiss()
    }
}
