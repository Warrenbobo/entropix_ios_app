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
    // AR Guidance按钮点击
    func cameraBottomControlsViewDidTapARGuidanceButton()
}

class LMCameraBottomControlsView: UIView {
    
    // Inspire Me 按钮区域
    private let inspireButtonContainer = UIView()
    private let inspireButton = UIButton()
    private let inspirePointsContainer = UIView()
    private let starImageView = UIImageView()
    private let inspirePointsLabel = UILabel()
    private let questionButton = UIButton()
    
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
    private var inspirePoints = 1
    private var isARGuidanceEnabled = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBottomControlsComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 设置渐变背景
        setupInspireButtonGradient()
    }
    
    private func setupInspireButtonGradient() {
        // 移除现有的渐变层
        inspireButton.layer.sublayers?.removeAll { $0 is CAGradientLayer }
        
        // 添加新的渐变背景
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 102/255, green: 126/255, blue: 234/255, alpha: 1).cgColor,
            UIColor(red: 118/255, green: 75/255, blue: 162/255, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = 20
        gradientLayer.frame = inspireButton.bounds
        inspireButton.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LMCameraBottomControlsView {
    
    private func setupBottomControlsComponents() {
        setupInspireButtonComponents()
        setupCaptureButtonComponents()
        setupFlipCameraComponents()
        setupARGuidanceComponents()
    }
    
    private func setupInspireButtonComponents() {
        addSubview(inspireButtonContainer)
        inspireButtonContainer.addSubview(inspireButton)
        inspireButtonContainer.addSubview(inspirePointsContainer)
        
        // Inspire按钮设置 - 渐变背景
        inspireButton.setTitle("Inspire Me", for: .normal)
        inspireButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        inspireButton.setTitleColor(UIColor.white, for: .normal)
        inspireButton.layer.cornerRadius = 20
        inspireButton.clipsToBounds = true
        inspireButton.addTarget(self, action: #selector(handleInspireButtonTapped), for: .touchUpInside)
        
        // 添加阴影效果
        inspireButton.layer.shadowColor = UIColor(red: 102/255, green: 126/255, blue: 234/255, alpha: 0.4).cgColor
        inspireButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        inspireButton.layer.shadowRadius = 15
        inspireButton.layer.shadowOpacity = 1.0
        
        // 点数容器设置
        inspirePointsContainer.addSubview(starImageView)
        inspirePointsContainer.addSubview(inspirePointsLabel)
        inspirePointsContainer.addSubview(questionButton)
        
        // 星星图标
        starImageView.image = UIImage(systemName: "star.fill")
        starImageView.tintColor = UIColor.systemYellow
        
        // 点数标签
        inspirePointsLabel.text = " -\(inspirePoints) "
        inspirePointsLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        inspirePointsLabel.textColor = UIColor.white
        inspirePointsLabel.textAlignment = .center
        
        // 问号按钮
        questionButton.setImage(UIImage(systemName: "questionmark.circle"), for: .normal)
        questionButton.tintColor = UIColor.white
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
        
        // 翻转相机按钮
        flipCameraButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        flipCameraButton.tintColor = UIColor.white
        flipCameraButton.addTarget(self, action: #selector(handleFlipCameraButtonTapped), for: .touchUpInside)
        
        // 翻转相机标签
        flipCameraLabel.text = "Flip Camera"
        flipCameraLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        flipCameraLabel.textColor = UIColor.white
        flipCameraLabel.textAlignment = .center
        flipCameraLabel.shadowColor = UIColor.black.withAlphaComponent(0.7)
        flipCameraLabel.shadowOffset = CGSize(width: 0, height: 1)
    }
    
    private func setupARGuidanceComponents() {
        addSubview(arGuidanceContainer)
        arGuidanceContainer.addSubview(arGuidanceButton)
        arGuidanceContainer.addSubview(arGuidanceLabel)
        
        // AR Guidance 按钮
        arGuidanceButton.setImage(UIImage(systemName: "person.2.crop.square.stack"), for: .normal)
        arGuidanceButton.tintColor = UIColor.lightGray
        arGuidanceButton.addTarget(self, action: #selector(handleARGuidanceButtonTapped), for: .touchUpInside)
        
        // AR Guidance 标签
        arGuidanceLabel.text = "AR Guidance"
        arGuidanceLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        arGuidanceLabel.textColor = UIColor.lightGray
        arGuidanceLabel.textAlignment = .center
        arGuidanceLabel.shadowColor = UIColor.black.withAlphaComponent(0.7)
        arGuidanceLabel.shadowOffset = CGSize(width: 0, height: 1)
        
        updateARGuidanceAppearance()
    }
    
    private func addTouchFeedbackEffectToCaptureButton() {
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTouchDown), for: .touchDown)
        captureButton.addTarget(self, action: #selector(handleCaptureButtonTouchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
}

extension LMCameraBottomControlsView {
    
    private func configureLayoutConstraints() {
        // Inspire按钮容器 - 在上方
        inspireButtonContainer.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-120) // 调整位置到上方
            make.width.equalTo(140)
            make.height.equalTo(60)
        }
        
        // Inspire按钮
        inspireButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        
        // 点数容器
        inspirePointsContainer.snp.makeConstraints { make in
            make.top.equalTo(inspireButton.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.height.equalTo(16)
        }
        
        // 星星图标
        starImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(12)
        }
        
        // 点数标签
        inspirePointsLabel.snp.makeConstraints { make in
            make.leading.equalTo(starImageView.snp.trailing)
            make.centerY.equalToSuperview()
        }
        
        // 问号按钮
        questionButton.snp.makeConstraints { make in
            make.leading.equalTo(inspirePointsLabel.snp.trailing)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.size.equalTo(12)
        }
        
        // 拍照按钮 - 在 Inspire Me 按钮下方
        captureButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-40)
            make.size.equalTo(70)
        }
        
        // 翻转相机容器 - 在拍照按钮左侧
        flipCameraContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(32)
            make.centerY.equalTo(captureButton)
            make.width.equalTo(80)
            make.height.equalTo(50)
        }
        
        // 翻转相机按钮
        flipCameraButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(30)
        }
        
        // 翻转相机标签
        flipCameraLabel.snp.makeConstraints { make in
            make.top.equalTo(flipCameraButton.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        // AR Guidance 容器 - 在拍照按钮右侧
        arGuidanceContainer.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(captureButton)
            make.width.equalTo(80)
            make.height.equalTo(50)
        }
        
        // AR Guidance 按钮
        arGuidanceButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(30)
        }
        
        // AR Guidance 标签
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
        updateInspireButtonAppearance()
    }
    
    private func updateInspireButtonAppearance() {
        inspirePointsLabel.text = " -\(inspirePoints) "
        
        // 根据点数更新按钮状态
        let hasPoints = inspirePoints > 0
        inspireButton.isEnabled = hasPoints
        inspireButton.alpha = hasPoints ? 1.0 : 0.6
    }
    
    private func updateARGuidanceAppearance() {
        if isARGuidanceEnabled {
            arGuidanceButton.tintColor = UIColor.white
            arGuidanceLabel.textColor = UIColor.white
        } else {
            arGuidanceButton.tintColor = UIColor.lightGray
            arGuidanceLabel.textColor = UIColor.lightGray
        }
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
    
    @objc private func handleARGuidanceButtonTapped() {
        isARGuidanceEnabled.toggle()
        updateARGuidanceAppearance()
        
        // 添加点击动画
        UIView.animate(withDuration: 0.1, animations: {
            self.arGuidanceButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.arGuidanceButton.transform = CGAffineTransform.identity
            }
        }
        
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
    
    func setARGuidanceEnabled(_ enabled: Bool) {
        isARGuidanceEnabled = enabled
        updateARGuidanceAppearance()
    }
    
    func getCurrentInspirePointsCount() -> Int {
        return inspirePoints
    }
    
    func getCurrentARGuidanceStatus() -> Bool {
        return isARGuidanceEnabled
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
    
    /// 设置 Inspire Me 按钮的启用/禁用状态
    /// - Parameter enabled: true 启用，false 禁用
    func setInspireMeButtonEnabled(_ enabled: Bool) {
        inspireButton.isEnabled = enabled
        inspireButton.alpha = enabled ? 1.0 : 0.5
        
        // 更新容器的交互状态
        inspireButtonContainer.isUserInteractionEnabled = enabled
        
        // 如果禁用，显示灰色样式
        if !enabled {
            inspireButton.backgroundColor = UIColor.gray.withAlphaComponent(0.5)
        } else {
            // 恢复渐变背景
            setupInspireButtonGradient()
        }
    }
    
    /// 获取当前 Inspire Points 数量
    func getCurrentInspirePoints() -> Int {
        return inspirePoints
    }
}
