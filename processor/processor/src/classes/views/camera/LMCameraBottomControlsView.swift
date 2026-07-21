//
//  LMCameraBottomControlsView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

protocol LMCameraBottomControlsViewDelegate: AnyObject {
    func cameraBottomControlsViewDidTapCaptureButton()
    func cameraBottomControlsViewDidTapMyReference()
}

class LMCameraBottomControlsView: UIView {
    
    private let captureButton = UIButton()
    
    private let myReferenceContainer = UIView()
    private let myReferenceButton = UIButton()
    private let myReferenceLabel = UILabel()
    
    weak var delegate: LMCameraBottomControlsViewDelegate?
    
    private var captureButtonSizeConstraint: Constraint?
    private var captureButtonBottomConstraint: Constraint?
    private var myReferenceContainerHeightConstraint: Constraint?
    
    enum LayoutMode {
        case normal
        case compact
    }
    
    private var currentLayoutMode: LayoutMode = .normal
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBottomControlsComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LMCameraBottomControlsView {
    
    private func setupBottomControlsComponents() {
        setupCaptureButtonComponents()
        setupMyReferenceComponents()
    }
    
    private func setupCaptureButtonComponents() {
        addSubview(captureButton)
        
        captureButton.backgroundColor = UIColor.white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 4
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTapped), for: .touchUpInside)
        
        addTouchFeedbackEffectToCaptureButton()
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
    
    private func addTouchFeedbackEffectToCaptureButton() {
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTouchDown), for: .touchDown)
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
}

extension LMCameraBottomControlsView {
    
    private func configureLayoutConstraints() {
        captureButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            captureButtonBottomConstraint = make.bottom.equalToSuperview().offset(-10).constraint
            captureButtonSizeConstraint = make.size.equalTo(70).constraint
        }
        
        myReferenceContainer.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
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
    }
}

extension LMCameraBottomControlsView {
    
    private func configureDefaultContentAndStyles() {
        backgroundColor = UIColor.clear
    }

    func setARGuidanceContainerHidden(_ hidden: Bool) {
        myReferenceContainer.isHidden = hidden
    }

    func setShutterRole(_ role: LMShutterRole) {
        captureButton.subviews.forEach { $0.removeFromSuperview() }
        captureButton.setImage(nil, for: .normal)

        switch role {
        case .captureDefault:
            captureButton.layer.borderColor = UIColor.white.cgColor
            captureButton.layer.borderWidth = 4
            captureButton.backgroundColor = .white
        case .instructReady:
            captureButton.layer.borderColor = UIColor.white.cgColor
            captureButton.layer.borderWidth = 4
            captureButton.backgroundColor = .white
            addInstructIcon(to: captureButton, dimmed: false)
        case .instructRunning:
            captureButton.layer.borderColor = UIColor.white.cgColor
            captureButton.backgroundColor = UIColor.white.withAlphaComponent(0.45)
            addInstructIcon(to: captureButton, dimmed: true)
        case .captureReady:
            captureButton.layer.borderColor = UIColor(red: 76/255, green: 217/255, blue: 100/255, alpha: 1).cgColor
            captureButton.layer.borderWidth = 4
            captureButton.backgroundColor = .white
        }
    }

    private func addInstructIcon(to button: UIButton, dimmed: Bool) {
        guard let icon = LMAgentIconProvider.instructIcon(dimmed: dimmed) else { return }
        let iconSize = LMAgentIconProvider.instructIconPointSize
        let buttonSize: CGFloat = currentLayoutMode == .compact ? 44 : 70
        let origin = (buttonSize - iconSize) / 2
        let iv = UIImageView(image: icon)
        iv.contentMode = .scaleAspectFit
        iv.frame = CGRect(x: origin, y: origin, width: iconSize, height: iconSize)
        iv.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        button.addSubview(iv)
    }
}

extension LMCameraBottomControlsView {
    
    @objc private func handleCaptureButtonTapped() {
        delegate?.cameraBottomControlsViewDidTapCaptureButton()
    }
    
    @objc private func handleMyReferenceButtonTapped() {
        delegate?.cameraBottomControlsViewDidTapMyReference()
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
            captureButtonBottomConstraint?.update(offset: -10)
            myReferenceContainerHeightConstraint?.update(offset: 50)
            
        case .compact:
            captureButtonSizeConstraint?.update(offset: 44)
            captureButtonBottomConstraint?.update(offset: 0)
            myReferenceContainerHeightConstraint?.update(offset: 44)
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
