//
//  LMCameraBottomControlsView.swift
//  processor
//
//  Shutter + Album (left) + Get Tips (right) + reserved mode hint.
//

import UIKit
import SnapKit

protocol LMCameraBottomControlsViewDelegate: AnyObject {
    func cameraBottomControlsViewDidTapCaptureButton()
    func cameraBottomControlsViewDidTapMyReference()
    func cameraBottomControlsViewDidTapGetTips()
}

class LMCameraBottomControlsView: UIView {

    private let captureButton = UIButton()
    private let dashedRingLayer = CAShapeLayer()
    private let dashedGradientLayer = CAGradientLayer()
    private let shutterIconView = UIImageView()

    private let modeHintLabel = UILabel()

    private let myReferenceContainer = UIView()
    private let myReferenceButton = UIButton()
    private let myReferenceLabel = UILabel()

    private let getTipsContainer = UIView()
    private let getTipsButton = UIButton()
    private let getTipsLabel = UILabel()
    private let getTipsIconView = UIImageView()

    weak var delegate: LMCameraBottomControlsViewDelegate?

    private var captureButtonSizeConstraint: Constraint?
    private var captureButtonBottomConstraint: Constraint?
    private var myReferenceContainerHeightConstraint: Constraint?
    private var getTipsContainerHeightConstraint: Constraint?

    enum LayoutMode {
        case normal
        case compact
    }

    private var currentLayoutMode: LayoutMode = .normal
    private var currentPreShootMode: LMPreShootPlanMode = .findSpot
    private var getTipsRunning = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBottomControlsComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        applyPreShootShutterAppearance(.findSpot)
        setGetTipsVisible(false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateDashedRingPath()
    }
}

extension LMCameraBottomControlsView {

    private func setupBottomControlsComponents() {
        setupCaptureButtonComponents()
        setupModeHint()
        setupMyReferenceComponents()
        setupGetTipsComponents()
    }

    private func setupCaptureButtonComponents() {
        addSubview(captureButton)

        captureButton.backgroundColor = UIColor.white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 4
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTapped), for: .touchUpInside)

        shutterIconView.contentMode = .scaleAspectFit
        shutterIconView.tintColor = UIColor.black.withAlphaComponent(0.75)
        shutterIconView.isUserInteractionEnabled = false
        captureButton.addSubview(shutterIconView)

        dashedGradientLayer.colors = LMLiquidGlassHUDTokens.agentAccentBorderColors.map { $0.cgColor }
        dashedGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        dashedGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        dashedRingLayer.fillColor = UIColor.clear.cgColor
        dashedRingLayer.strokeColor = UIColor.white.cgColor
        dashedRingLayer.lineWidth = 3
        dashedRingLayer.lineDashPattern = [6, 4]
        dashedGradientLayer.mask = dashedRingLayer
        dashedGradientLayer.isHidden = true
        captureButton.layer.addSublayer(dashedGradientLayer)

        addTouchFeedbackEffectToCaptureButton()
    }

    private func setupModeHint() {
        addSubview(modeHintLabel)
        modeHintLabel.font = .systemFont(ofSize: 11, weight: .medium)
        modeHintLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        modeHintLabel.textAlignment = .center
        modeHintLabel.numberOfLines = 1
        // Always reserve height so shutter Y does not jump (§2).
        modeHintLabel.text = " "
    }

    private func setupMyReferenceComponents() {
        addSubview(myReferenceContainer)
        myReferenceContainer.addSubview(myReferenceButton)
        myReferenceContainer.addSubview(myReferenceLabel)
        myReferenceContainer.isUserInteractionEnabled = true
        myReferenceButton.isUserInteractionEnabled = false
        myReferenceButton.imageView?.contentMode = .scaleAspectFit

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let icon = UIImage(systemName: "photo.on.rectangle.angled", withConfiguration: symbolConfig)
        myReferenceButton.setImage(icon, for: .normal)
        myReferenceButton.tintColor = .white

        myReferenceLabel.text = LMLaunageManager.shared.camera.myReference
        myReferenceLabel.textColor = .white
        myReferenceLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        myReferenceLabel.textAlignment = .center

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMyReferenceButtonTapped))
        myReferenceContainer.addGestureRecognizer(tapGesture)
    }

    private func setupGetTipsComponents() {
        addSubview(getTipsContainer)
        getTipsContainer.addSubview(getTipsButton)
        getTipsContainer.addSubview(getTipsLabel)
        getTipsContainer.isUserInteractionEnabled = true
        getTipsButton.isUserInteractionEnabled = false

        getTipsIconView.contentMode = .scaleAspectFit
        getTipsIconView.tintColor = .white
        getTipsIconView.image = LMAgentIconProvider.instructIcon(
            preferGradient: false,
            pointSize: 22
        )
        getTipsButton.addSubview(getTipsIconView)

        getTipsLabel.text = LMLaunageManager.shared.camera.getTips
        getTipsLabel.textColor = .white
        getTipsLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        getTipsLabel.textAlignment = .center

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleGetTipsTapped))
        getTipsContainer.addGestureRecognizer(tapGesture)
    }

    private func addTouchFeedbackEffectToCaptureButton() {
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTouchDown), for: .touchDown)
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
}

extension LMCameraBottomControlsView {

    private func configureLayoutConstraints() {
        // Hint reserved under shutter; shutter sits above it so Y stays stable.
        modeHintLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-2)
            make.height.equalTo(16)
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
        }

        captureButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            captureButtonBottomConstraint = make.bottom.equalTo(modeHintLabel.snp.top).offset(-6).constraint
            captureButtonSizeConstraint = make.size.equalTo(70).constraint
        }

        shutterIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(28)
        }

        // Album: horizontal center of left half (leading edge → shutter).
        myReferenceContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview().multipliedBy(0.5)
            make.centerY.equalTo(captureButton)
            make.width.equalTo(80)
            myReferenceContainerHeightConstraint = make.height.equalTo(50).constraint
        }
        myReferenceButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(30)
        }
        myReferenceLabel.snp.makeConstraints { make in
            make.top.equalTo(myReferenceButton.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }

        // Get Tips: horizontal center of right half (shutter → trailing).
        getTipsContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview().multipliedBy(1.5)
            make.centerY.equalTo(captureButton)
            make.width.equalTo(80)
            getTipsContainerHeightConstraint = make.height.equalTo(50).constraint
        }
        getTipsButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(30)
        }
        getTipsIconView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        getTipsLabel.snp.makeConstraints { make in
            make.top.equalTo(getTipsButton.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
}

extension LMCameraBottomControlsView {

    private func configureDefaultContentAndStyles() {
        backgroundColor = UIColor.clear
    }

    /**
     Shows or hides the Album (My Reference) control.

     - Parameter hidden: When true, Album is not interactive / visible.
     */
    func setARGuidanceContainerHidden(_ hidden: Bool) {
        myReferenceContainer.isHidden = hidden
    }

    /**
     Shows or hides Get Tips (composition-selected only).

     - Parameter visible: Whether Get Tips is shown.
     */
    func setGetTipsVisible(_ visible: Bool) {
        getTipsContainer.isHidden = !visible
        getTipsContainer.isUserInteractionEnabled = visible
    }

    /**
     Updates Get Tips idle / running chrome.

     - Parameter running: When true, shows gradient icon + brief rotation.
     */
    func setGetTipsRunning(_ running: Bool) {
        getTipsRunning = running
        getTipsIconView.tintColor = .white
        getTipsIconView.image = LMAgentIconProvider.instructIcon(
            preferGradient: running,
            pointSize: 22
        )
        getTipsIconView.layer.removeAnimation(forKey: "getTipsSpin")
        if running {
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.pi * 2
            spin.duration = 0.7
            spin.repeatCount = 2
            getTipsIconView.layer.add(spin, forKey: "getTipsSpin")
        }
    }

    /**
     Applies shutter chrome for the active pre-shoot plan mode.

     - Parameter mode: Camera / Find Spot / Get Template.
     */
    func applyPreShootShutterAppearance(_ mode: LMPreShootPlanMode) {
        currentPreShootMode = mode
        captureButton.subviews.filter { $0 !== shutterIconView }.forEach { $0.removeFromSuperview() }
        captureButton.setImage(nil, for: .normal)

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        switch mode {
        case .camera:
            dashedGradientLayer.isHidden = true
            captureButton.layer.borderColor = UIColor.white.cgColor
            captureButton.layer.borderWidth = 4
            captureButton.backgroundColor = .white
            shutterIconView.image = nil
            shutterIconView.isHidden = true
            modeHintLabel.text = " "
            modeHintLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        case .findSpot:
            dashedGradientLayer.isHidden = false
            captureButton.layer.borderWidth = 0
            captureButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
            shutterIconView.image = LMPreShootPlanSymbols.findSpot(configuration: symbolConfig)
            shutterIconView.tintColor = .white
            shutterIconView.isHidden = false
            modeHintLabel.text = LMText.camera.preShootPlanHintFindSpot
        case .composition:
            dashedGradientLayer.isHidden = false
            captureButton.layer.borderWidth = 0
            captureButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
            shutterIconView.image = LMPreShootPlanSymbols.composition(configuration: symbolConfig)
            shutterIconView.tintColor = .white
            shutterIconView.isHidden = false
            modeHintLabel.text = LMText.camera.preShootPlanHintGetTemplate
        }
        updateDashedRingPath()
    }

    /**
     Legacy Agent shutter role — composition-selected uses photo-only shutter;
     instruct chrome moves to Get Tips. Kept for transitional call sites.
     */
    func setShutterRole(_ role: LMShutterRole) {
        switch role {
        case .captureDefault, .captureReady, .instructReady, .instructRunning:
            // Composition-selected: always solid white photo shutter.
            dashedGradientLayer.isHidden = true
            captureButton.layer.borderColor = UIColor.white.cgColor
            captureButton.layer.borderWidth = 4
            captureButton.backgroundColor = .white
            shutterIconView.image = nil
            shutterIconView.isHidden = true
            modeHintLabel.text = " "
            if role == .instructRunning {
                setGetTipsRunning(true)
            } else if role == .instructReady || role == .captureReady || role == .captureDefault {
                setGetTipsRunning(false)
            }
        }
    }

    private func updateDashedRingPath() {
        let size = captureButton.bounds.size
        guard size.width > 0 else { return }
        dashedGradientLayer.frame = captureButton.bounds
        let inset: CGFloat = 2
        let path = UIBezierPath(
            ovalIn: CGRect(
                x: inset,
                y: inset,
                width: size.width - inset * 2,
                height: size.height - inset * 2
            )
        )
        dashedRingLayer.path = path.cgPath
        dashedRingLayer.frame = captureButton.bounds
    }
}

extension LMCameraBottomControlsView {

    @objc private func handleCaptureButtonTapped() {
        delegate?.cameraBottomControlsViewDidTapCaptureButton()
    }

    @objc private func handleMyReferenceButtonTapped() {
        delegate?.cameraBottomControlsViewDidTapMyReference()
    }

    @objc private func handleGetTipsTapped() {
        guard !getTipsContainer.isHidden else { return }
        delegate?.cameraBottomControlsViewDidTapGetTips()
    }

    @objc private func handleCaptureButtonTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    @objc private func handleCaptureButtonTouchUp() {
        UIView.animate(withDuration: 0.1) {
            self.captureButton.transform = CGAffineTransform.identity
        }
    }
}

extension LMCameraBottomControlsView {

    func setLayoutMode(_ mode: LayoutMode, animated: Bool = true) {
        guard mode != currentLayoutMode else { return }

        currentLayoutMode = mode

        switch mode {
        case .normal:
            captureButtonSizeConstraint?.update(offset: 70)
            myReferenceContainerHeightConstraint?.update(offset: 50)
            getTipsContainerHeightConstraint?.update(offset: 50)
        case .compact:
            captureButtonSizeConstraint?.update(offset: 44)
            myReferenceContainerHeightConstraint?.update(offset: 44)
            getTipsContainerHeightConstraint?.update(offset: 44)
        }

        if animated {
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.5,
                options: [.curveEaseInOut, .allowUserInteraction]
            ) {
                self.layoutIfNeeded()
                self.updateCaptureButtonCornerRadius(for: mode)
            }
        } else {
            layoutIfNeeded()
            updateCaptureButtonCornerRadius(for: mode)
        }

        LMLogger.log("📐 Bottom controls layout mode changed to: \(mode == .normal ? "Normal" : "Compact")")
    }

    private func updateCaptureButtonCornerRadius(for mode: LayoutMode) {
        switch mode {
        case .normal:
            captureButton.layer.cornerRadius = 35
        case .compact:
            captureButton.layer.cornerRadius = 22
        }
        updateDashedRingPath()
    }

    func restoreShutterButtonSize() {
        setLayoutMode(.normal, animated: true)
    }

    func restoreBottomControlsHeight() {
        setLayoutMode(.normal, animated: true)
    }

    func getARGuidanceContainerView() -> UIView {
        myReferenceContainer
    }
}
