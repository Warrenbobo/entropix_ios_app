//
//  LMCameraBottomControlsView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

protocol LMCameraBottomControlsViewDelegate: AnyObject {
    // 拍照按钮
    func cameraBottomControlsViewDidTapCaptureButton()
    // 翻转相机
    func cameraBottomControlsViewDidTapFlipCameraButton()
    // AR Guidance按钮点击
    func cameraBottomControlsViewDidTapARGuidanceButton()
}

class LMCameraBottomControlsView: UIView {
    
    // 拍照按钮
    private let captureButton = UIButton()
    
    // 左侧翻转相机按钮
    private let flipCameraContainer = UIView()
    private let flipCameraButton = UIButton()
    private let flipCameraLabel = UILabel()
    
    // 右侧 AR Guidance 按钮
    private let arGuidanceContainer = UIView()
    private let arGuidanceButton = UIButton()
    private let arGuidanceLabel = UILabel()
    
    weak var delegate: LMCameraBottomControlsViewDelegate?
    private var isARGuidanceEnabled = false
    
    // 约束引用，用于动态调整
    private var captureButtonSizeConstraint: Constraint?
    private var captureButtonBottomConstraint: Constraint?
    private var flipContainerHeightConstraint: Constraint?
    private var arContainerHeightConstraint: Constraint?
    
    // 布局模式
    enum LayoutMode {
        case normal   // 高度 90，按钮正常大小
        case compact  // 高度 44，按钮缩小
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
        setupFlipCameraComponents()
        setupARGuidanceComponents()
    }
    
    private func setupCaptureButtonComponents() {
        addSubview(captureButton)
        
        // 拍照按钮设置
        captureButton.backgroundColor = UIColor.white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 4
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTapped), for: .touchUpInside)
        
        // 添加触摸反馈
        addTouchFeedbackEffectToCaptureButton()
    }
    
    private func setupFlipCameraComponents() {
        addSubview(flipCameraContainer)
        flipCameraContainer.addSubview(flipCameraButton)
        flipCameraContainer.addSubview(flipCameraLabel)
        
        // 翻转相机按钮 - 仅用于显示图标，不处理点击
        flipCameraButton.setImage(UIImage(named: "flip_camera"), for: .normal)
        flipCameraButton.tintColor = UIColor.white
        flipCameraButton.isUserInteractionEnabled = false // 禁用按钮交互
        
        // 翻转相机标签
        flipCameraLabel.text = LMLaunageManager.shared.camera.flipCamera
        flipCameraLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        flipCameraLabel.textColor = UIColor.white
        flipCameraLabel.textAlignment = .center
        flipCameraLabel.shadowColor = UIColor.black.withAlphaComponent(0.7)
        flipCameraLabel.shadowOffset = CGSize(width: 0, height: 1)
        
        // 在容器上添加点击手势
        let flipTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleFlipCameraButtonTapped))
        flipCameraContainer.addGestureRecognizer(flipTapGesture)
        flipCameraContainer.isUserInteractionEnabled = true
    }
    
    private func setupARGuidanceComponents() {
        addSubview(arGuidanceContainer)
        arGuidanceContainer.addSubview(arGuidanceButton)
        arGuidanceContainer.addSubview(arGuidanceLabel)
        
        // AR Guidance 按钮 - 仅用于显示图标，不处理点击
        arGuidanceButton.setImage(UIImage(named: "users_viewfinder_off_white"), for: .normal)
        arGuidanceButton.setImage(UIImage(named: "users_viewfinder_white"), for: .selected)
        arGuidanceButton.isUserInteractionEnabled = false // 禁用按钮交互
        
        // AR Guidance 标签
        arGuidanceLabel.text = LMLaunageManager.shared.camera.arGuidance
        arGuidanceLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        arGuidanceLabel.textColor = UIColor.white
        arGuidanceLabel.textAlignment = .center
        arGuidanceLabel.shadowColor = UIColor.black.withAlphaComponent(0.7)
        arGuidanceLabel.shadowOffset = CGSize(width: 0, height: 1)
        
        // 在容器上添加点击手势
        let arTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleARGuidanceButtonTapped))
        arGuidanceContainer.addGestureRecognizer(arTapGesture)
        arGuidanceContainer.isUserInteractionEnabled = true
        
        updateARGuidanceAppearance()
    }
    
    private func addTouchFeedbackEffectToCaptureButton() {
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTouchDown), for: .touchDown)
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
}

extension LMCameraBottomControlsView {
    
    private func configureLayoutConstraints() {
        // 拍照按钮 - 放在 View 底部
        captureButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            captureButtonBottomConstraint = make.bottom.equalToSuperview().offset(-10).constraint
            captureButtonSizeConstraint = make.size.equalTo(70).constraint
        }
        
        // 翻转相机按钮 - 与拍照按钮垂直对齐
        flipCameraContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(32)
            make.centerY.equalTo(captureButton)
            make.width.equalTo(80)
            flipContainerHeightConstraint = make.height.equalTo(50).constraint
        }
        flipCameraButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(30)
        }
        flipCameraLabel.snp.makeConstraints { make in
            make.top.equalTo(flipCameraButton.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        // AR Guidance 按钮 - 与拍照按钮垂直对齐
        arGuidanceContainer.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(captureButton)
            make.width.equalTo(80)
            arContainerHeightConstraint = make.height.equalTo(50).constraint
        }
        arGuidanceButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(30)
        }
        arGuidanceLabel.snp.makeConstraints { make in
            make.top.equalTo(arGuidanceButton.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
}

extension LMCameraBottomControlsView {
    
    private func configureDefaultContentAndStyles() {
        backgroundColor = UIColor.clear
    }
    
    private func updateARGuidanceAppearance() {
        if isARGuidanceEnabled {
            arGuidanceButton.isSelected = true
        } else {
            arGuidanceButton.isSelected = false
        }
    }
}

extension LMCameraBottomControlsView {
    
    @objc private func handleCaptureButtonTapped() {
        delegate?.cameraBottomControlsViewDidTapCaptureButton()
    }
    
    @objc private func handleFlipCameraButtonTapped() {
        delegate?.cameraBottomControlsViewDidTapFlipCameraButton()
    }
    
    @objc private func handleARGuidanceButtonTapped() {
        isARGuidanceEnabled.toggle()
        updateARGuidanceAppearance()
        delegate?.cameraBottomControlsViewDidTapARGuidanceButton()
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
    
    /// 设置AR Guidance的启用状态
    /// - Parameter enabled: 是否启用
    /// - Note: 此方法会同步更新内部状态和视觉外观
    func setARGuidanceEnabled(_ enabled: Bool) {
        // 确保状态同步
        isARGuidanceEnabled = enabled
        updateARGuidanceAppearance()
        
        LMLogger.log("🎯 AR Guidance button state set to: \(enabled ? "ON" : "OFF")")
    }
    
    func getCurrentARGuidanceStatus() -> Bool {
        return isARGuidanceEnabled
    }
    
    /// 切换布局模式
    /// - Parameters:
    ///   - mode: 布局模式（normal 或 compact）
    ///   - animated: 是否使用动画
    func setLayoutMode(_ mode: LayoutMode, animated: Bool = true) {
        guard mode != currentLayoutMode else { return }
        
        currentLayoutMode = mode
        
        switch mode {
        case .normal:
            // 恢复正常大小：拍照按钮 70，容器高度 50，底部间距 10
            captureButtonSizeConstraint?.update(offset: 70)
            captureButtonBottomConstraint?.update(offset: -10)
            flipContainerHeightConstraint?.update(offset: 50)
            arContainerHeightConstraint?.update(offset: 50)
            
        case .compact:
            // 缩小尺寸：拍照按钮 44，容器高度 44，垂直居中
            captureButtonSizeConstraint?.update(offset: 44)
            captureButtonBottomConstraint?.update(offset: 0)
            flipContainerHeightConstraint?.update(offset: 44)
            arContainerHeightConstraint?.update(offset: 44)
        }
        
        // 应用布局变化和圆角动画
        if animated {
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.5,
                options: [.curveEaseInOut, .allowUserInteraction]
            ) {
                self.layoutIfNeeded()
                // 在动画块中更新圆角，使其平滑过渡
                self.updateCaptureButtonCornerRadius(for: mode)
            }
        } else {
            layoutIfNeeded()
            updateCaptureButtonCornerRadius(for: mode)
        }
        
        LMLogger.log("📐 Bottom controls layout mode changed to: \(mode == .normal ? "Normal" : "Compact")")
    }
    
    /// 更新拍摄按钮的圆角半径
    /// - Parameter mode: 布局模式
    private func updateCaptureButtonCornerRadius(for mode: LayoutMode) {
        switch mode {
        case .normal:
            // 70x70 按钮，圆角半径 35（保持圆形）
            captureButton.layer.cornerRadius = 35
        case .compact:
            // 44x44 按钮，圆角半径 22（保持圆形）
            captureButton.layer.cornerRadius = 22
        }
    }
    
    /// 恢复快门按钮到正常尺寸
    func restoreShutterButtonSize() {
        setLayoutMode(.normal, animated: true)
    }
    
    /// 恢复底部控制栏高度（通过恢复布局模式实现）
    func restoreBottomControlsHeight() {
        setLayoutMode(.normal, animated: true)
    }
}
