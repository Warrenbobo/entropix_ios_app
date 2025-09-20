//
//  LMCameraBottomControlsView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

protocol LMCameraBottomControlsViewDelegate: AnyObject {
    // Inspire按钮点击
    func cameraBottomControlsViewDidTapInspireButton()
    // 拍照按钮
    func cameraBottomControlsViewDidTapCaptureButton()
    // 翻转相机
    func cameraBottomControlsViewDidTapFlipCameraButton()
    // 打开或关闭PremiumMode
    func cameraBottomControlsViewDidTogglePremiumMode(_ enabled: Bool)
}

class LMCameraBottomControlsView: UIView {
    
    private let inspireButtonView = UIView()
    private let inspireButton = UIButton()
    private let inspirePointsLabel = UILabel()
    
    private let captureButton = UIButton()
    private let captureButtonInnerCircle = UIView()
    
    private let rightControlsStackView = UIStackView()
    private let flipCameraButton = UIButton()
    private let flipCameraLabel = UILabel()
    private let premiumModeToggle = UISwitch()
    private let premiumModeLabel = UILabel()
    
    weak var delegate: LMCameraBottomControlsViewDelegate?
    private var inspirePoints = 1
    private var isPremiumModeEnabled = false
    
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
        setupInspireButtonComponents()
        setupCaptureButtonComponents()
        setupRightControlsComponents()
    }
    
    private func setupInspireButtonComponents() {
        addSubview(inspireButtonView)
        inspireButtonView.addSubview(inspireButton)
        inspireButtonView.addSubview(inspirePointsLabel)
        
        // Inspire按钮设置
        inspireButton.backgroundColor = UIColor.systemPurple
        inspireButton.layer.cornerRadius = 25
        inspireButton.setTitle("Inspire Me", for: .normal)
        inspireButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        inspireButton.setTitleColor(UIColor.white, for: .normal)
        inspireButton.addTarget(self, action: #selector(handleInspireButtonTapped), for: .touchUpInside)
        
        // 添加星星图标
        let starImageView = UIImageView(image: UIImage(systemName: "star.fill"))
        starImageView.tintColor = UIColor.systemYellow
        inspireButton.addSubview(starImageView)
        
        starImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
        
        // 点数标签设置
        inspirePointsLabel.text = "-\(inspirePoints)"
        inspirePointsLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        inspirePointsLabel.textColor = UIColor.white
        inspirePointsLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        inspirePointsLabel.layer.cornerRadius = 10
        inspirePointsLabel.clipsToBounds = true
        inspirePointsLabel.textAlignment = .center
        
        // 添加信息图标
        let infoButton = UIButton()
        infoButton.setImage(UIImage(systemName: "info.circle"), for: .normal)
        infoButton.tintColor = UIColor.white.withAlphaComponent(0.8)
        inspirePointsLabel.addSubview(infoButton)
        
        infoButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
            make.size.equalTo(12)
        }
    }
    
    private func setupCaptureButtonComponents() {
        addSubview(captureButton)
        captureButton.addSubview(captureButtonInnerCircle)
        
        // 拍照按钮设置
        captureButton.backgroundColor = UIColor.white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 4
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTapped), for: .touchUpInside)
        
        // 内圆设置
        captureButtonInnerCircle.backgroundColor = UIColor.white
        captureButtonInnerCircle.layer.cornerRadius = 30
        captureButtonInnerCircle.isUserInteractionEnabled = false
        
        // 添加触摸反馈
        addTouchFeedbackEffectToCaptureButton()
    }
    
    private func setupRightControlsComponents() {
        addSubview(rightControlsStackView)
        
        rightControlsStackView.axis = .vertical
        rightControlsStackView.spacing = 16
        rightControlsStackView.alignment = .center
        rightControlsStackView.distribution = .equalSpacing
        
        setupFlipCameraComponents()
        setupPremiumModeComponents()
    }
    
    private func setupFlipCameraComponents() {
        let flipCameraContainer = UIView()
        flipCameraContainer.addSubview(flipCameraButton)
        flipCameraContainer.addSubview(flipCameraLabel)
        
        flipCameraButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        flipCameraButton.tintColor = UIColor.white
        flipCameraButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        flipCameraButton.layer.cornerRadius = 20
        flipCameraButton.addTarget(self, action: #selector(handleFlipCameraButtonTapped), for: .touchUpInside)
        
        flipCameraLabel.text = "Flip Camera"
        flipCameraLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        flipCameraLabel.textColor = UIColor.white
        flipCameraLabel.textAlignment = .center
        
        flipCameraButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(40)
        }
        
        flipCameraLabel.snp.makeConstraints { make in
            make.top.equalTo(flipCameraButton.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
            make.width.equalTo(80)
        }
        
        rightControlsStackView.addArrangedSubview(flipCameraContainer)
    }
    
    private func setupPremiumModeComponents() {
        let premiumModeContainer = UIView()
        premiumModeContainer.addSubview(premiumModeToggle)
        premiumModeContainer.addSubview(premiumModeLabel)
        
        premiumModeToggle.onTintColor = UIColor.systemPurple
        premiumModeToggle.addTarget(self, action: #selector(handlePremiumModeToggleChanged), for: .valueChanged)
        
        premiumModeLabel.text = "Premium Mode"
        premiumModeLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        premiumModeLabel.textColor = UIColor.white
        premiumModeLabel.textAlignment = .center
        
        premiumModeToggle.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        
        premiumModeLabel.snp.makeConstraints { make in
            make.top.equalTo(premiumModeToggle.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
            make.width.equalTo(80)
        }
        
        rightControlsStackView.addArrangedSubview(premiumModeContainer)
    }
    
    private func addTouchFeedbackEffectToCaptureButton() {
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTouchDown), for: .touchDown)
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
}

extension LMCameraBottomControlsView {
    
    private func configureLayoutConstraints() {
        // Inspire按钮区域
        inspireButtonView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.equalTo(120)
            make.height.equalTo(80)
        }
        
        inspireButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(50)
        }
        
        inspirePointsLabel.snp.makeConstraints { make in
            make.top.equalTo(inspireButton.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.width.equalTo(60)
            make.height.equalTo(20)
        }
        
        // 拍照按钮
        captureButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(70)
        }
        
        captureButtonInnerCircle.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(60)
        }
        
        // 右侧控制区域
        rightControlsStackView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.equalTo(80)
        }
    }
}

extension LMCameraBottomControlsView {
    
    private func configureDefaultContentAndStyles() {
        backgroundColor = UIColor.clear
        updateInspireButtonAppearance()
    }
    
    private func updateInspireButtonAppearance() {
        inspirePointsLabel.text = "-\(inspirePoints)"
        
        // 根据点数更新按钮状态
        let hasPoints = inspirePoints > 0
        inspireButton.isEnabled = hasPoints
        inspireButton.alpha = hasPoints ? 1.0 : 0.6
    }
}

extension LMCameraBottomControlsView {
    
    @objc private func handleInspireButtonTapped() {
        guard inspirePoints > 0 else { return }
        
        // 添加点击动画
        UIView.animate(withDuration: 0.1, animations: {
            self.inspireButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.inspireButton.transform = CGAffineTransform.identity
            }
        }
        
        delegate?.cameraBottomControlsViewDidTapInspireButton()
    }
    
    @objc private func handleCaptureButtonTapped() {
        delegate?.cameraBottomControlsViewDidTapCaptureButton()
    }
    
    @objc private func handleFlipCameraButtonTapped() {
        // 添加旋转动画
        UIView.animate(withDuration: 0.3) {
            self.flipCameraButton.transform = CGAffineTransform(rotationAngle: .pi)
        } completion: { _ in
            self.flipCameraButton.transform = CGAffineTransform.identity
        }
        
        delegate?.cameraBottomControlsViewDidTapFlipCameraButton()
    }
    
    @objc private func handlePremiumModeToggleChanged() {
        isPremiumModeEnabled = premiumModeToggle.isOn
        delegate?.cameraBottomControlsViewDidTogglePremiumMode(isPremiumModeEnabled)
    }
    
    @objc private func handleCaptureButtonTouchDown() {
        UIView.animate(withDuration: 0.1) {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.captureButtonInnerCircle.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }
    }
    
    @objc private func handleCaptureButtonTouchUp() {
        UIView.animate(withDuration: 0.1) {
            self.captureButton.transform = CGAffineTransform.identity
            self.captureButtonInnerCircle.transform = CGAffineTransform.identity
        }
    }
}

extension LMCameraBottomControlsView {
    
    func updateInspirePointsCount(_ points: Int) {
        inspirePoints = max(0, points)
        updateInspireButtonAppearance()
    }
    
    func decrementInspirePointsCount() {
        if inspirePoints > 0 {
            inspirePoints -= 1
            updateInspireButtonAppearance()
        }
    }
    
    func setPremiumModeEnabled(_ enabled: Bool) {
        isPremiumModeEnabled = enabled
        premiumModeToggle.setOn(enabled, animated: true)
    }
    
    func getCurrentInspirePointsCount() -> Int {
        return inspirePoints
    }
    
    func getCurrentPremiumModeStatus() -> Bool {
        return isPremiumModeEnabled
    }
    
    func showCaptureAnimation() {
        // 拍照时的闪烁动画
        let flashView = UIView()
        flashView.backgroundColor = UIColor.white
        flashView.alpha = 0
        addSubview(flashView)
        
        flashView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        UIView.animate(withDuration: 0.1, animations: {
            flashView.alpha = 0.8
        }) { _ in
            UIView.animate(withDuration: 0.2, animations: {
                flashView.alpha = 0
            }) { _ in
                flashView.removeFromSuperview()
            }
        }
    }
}
