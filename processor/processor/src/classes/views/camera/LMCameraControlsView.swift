//
//  LMCameraControlsView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

enum LMFlashMode {
    case auto
    case on
    case off

    /// SF Symbol name for the camera sidebar flash control.
    var symbolName: String {
        switch self {
        case .auto: return "bolt.badge.automatic.fill"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .on: return "On"
        case .off: return "Off"
        }
    }
}

enum LMAspectRatio {
    case ratio3_4
    case ratio1_1
    case ratio9_16
    
    var iconName: String {
        switch self {
        case .ratio3_4: return "aspect_ratio_3_4"
        case .ratio1_1: return "aspect_ratio_1_1"
        case .ratio9_16: return "aspect_ratio_9_16"
        }
    }
    
    var displayName: String {
        switch self {
        case .ratio3_4: return "3:4"
        case .ratio1_1: return "1:1"
        case .ratio9_16: return "9:16"
        }
    }
}

enum LMTimerDuration {
    case off
    case three
    case five
    case ten

    /// Overlay digit for `timer` + label stack; `nil` when off.
    var badgeText: String? {
        switch self {
        case .off: return nil
        case .three: return "3"
        case .five: return "5"
        case .ten: return "10"
        }
    }
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .three: return "3s"
        case .five: return "5s"
        case .ten: return "10s"
        }
    }
    
    var seconds: Int {
        switch self {
        case .off: return 0
        case .three: return 3
        case .five: return 5
        case .ten: return 10
        }
    }
}

protocol LMCameraControlsViewDelegate: AnyObject {
    func cameraControlsView(_ view: LMCameraControlsView, didChangeFlashMode mode: LMFlashMode)
    func cameraControlsView(_ view: LMCameraControlsView, didChangeAspectRatio ratio: LMAspectRatio)
    func cameraControlsView(_ view: LMCameraControlsView, didChangeTimer duration: LMTimerDuration)
    func cameraControlsView(_ view: LMCameraControlsView, didToggleLivePhoto enabled: Bool)
    func cameraControlsView(_ view: LMCameraControlsView, didToggleGrid enabled: Bool)
    func cameraControlsViewDidTapAgentToggle(_ view: LMCameraControlsView)
    func cameraControlsViewDidTapFlipCamera(_ view: LMCameraControlsView)
}

class LMCameraControlsView: UIView {
    
    // MARK: - UI Components
    private let controlsStackView = UIStackView()
    
    // 控制项容器
    private let agentContainer = UIView()
    private let flashContainer = UIView()
    private let ratioContainer = UIView()
    private let timerContainer = UIView()
    private let liveContainer = UIView()
    private let gridContainer = UIView()
    private let flipCameraContainer = UIView()
    
    // 功能按钮
    private let agentControlButton = UIButton()
    private let flashControlButton = UIButton()
    private let ratioControlButton = UIButton()
    private let timerControlButton = UIButton()
    private let liveControlButton = UIButton()
    private let gridControlButton = UIButton()
    private let flipCameraControlButton = UIButton()
    
    // 图标视图
    private let agentIconView = UIImageView()
    private let flashIconView = UIImageView()
    private let ratioIconView = UIImageView()
    private let timerIconView = UIImageView()
    /// Small digit overlaid on the timer SF Symbol (3 / 5 / 10).
    private let timerBadgeLabel = UILabel()
    private let liveIconView = UIImageView()
    private let gridIconView = UIImageView()
    private let flipCameraIconView = UIImageView()
    
    // 功能标签
    private let agentLabel = UILabel()
    private let flashLabel = UILabel()
    private let ratioLabel = UILabel()
    private let timerLabel = UILabel()
    private let liveLabel = UILabel()
    private let gridLabel = UILabel()
    private let flipCameraLabel = UILabel()
    
    private let agentGlassPanel = UIVisualEffectView()
    
    // MARK: - Properties
    weak var delegate: LMCameraControlsViewDelegate?
    
    private var currentFlashMode: LMFlashMode = .auto
    private var currentAspectRatio: LMAspectRatio = .ratio3_4
    private var currentTimerDuration: LMTimerDuration = .off
    private var isLivePhotoEnabled = false
    private var isGridEnabled = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCameraControlsComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LMCameraControlsView {
    
    private func setupCameraControlsComponents() {
        addSubview(controlsStackView)
        
        // 配置堆栈视图 - 根据HTML设计，控件间距较小
        controlsStackView.axis = .vertical
        controlsStackView.spacing = 6
        controlsStackView.alignment = .center
        controlsStackView.distribution = .equalSpacing
        
        setupAgentControlComponents()
        setupFlashControlComponents()
        setupRatioControlComponents()
        setupTimerControlComponents()
        setupLiveControlComponents()
        setupGridControlComponents()
        setupFlipCameraControlComponents()
    }
    
    private func setupAgentControlComponents() {
        agentContainer.addSubview(agentGlassPanel)
        agentContainer.addSubview(agentControlButton)
        agentContainer.addSubview(agentIconView)
        agentContainer.addSubview(agentLabel)
        agentContainer.isHidden = true
        agentGlassPanel.isHidden = true
        agentGlassPanel.isUserInteractionEnabled = false
        agentGlassPanel.layer.cornerRadius = 18
        agentGlassPanel.clipsToBounds = true
        if #available(iOS 26.0, *) {
            agentGlassPanel.effect = UIGlassEffect(style: .regular)
        } else {
            agentGlassPanel.effect = UIBlurEffect(style: .systemThinMaterialDark)
        }

        agentControlButton.backgroundColor = .clear
        agentControlButton.addTarget(self, action: #selector(handleAgentControlButtonTapped), for: .touchUpInside)

        agentIconView.image = LMAgentIconProvider.agentToggleIcon
        agentIconView.tintColor = .white
        agentIconView.contentMode = .scaleAspectFit

        agentLabel.text = LMLaunageManager.shared.camera.agentToggleLabel
        agentLabel.font = .systemFont(ofSize: 9, weight: .medium)
        agentLabel.textColor = .white
        agentLabel.textAlignment = .center

        controlsStackView.addArrangedSubview(agentContainer)
        agentContainer.snp.makeConstraints { make in
            make.width.equalTo(48)
            make.height.equalTo(58)
        }
        agentGlassPanel.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        agentIconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(20)
        }
        agentControlButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        agentLabel.snp.makeConstraints { make in
            make.top.equalTo(agentIconView.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(2)
            make.bottom.equalToSuperview().offset(-4)
        }
    }

    @objc private func handleAgentControlButtonTapped() {
        delegate?.cameraControlsViewDidTapAgentToggle(self)
    }

    func setAgentToggleVisible(_ visible: Bool) {
        agentContainer.isHidden = !visible
    }

    func setAgentToggleState(_ state: LMARGuidanceButtonState) {
        switch state {
        case .agent:
            agentIconView.alpha = 1
            agentLabel.alpha = 1
            agentGlassPanel.isHidden = false
            agentContainer.layer.borderWidth = 1
            agentContainer.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor
            agentContainer.layer.cornerRadius = 18
        case .off:
            agentIconView.alpha = 0.45
            agentLabel.alpha = 0.45
            agentGlassPanel.isHidden = true
            agentContainer.layer.borderWidth = 0
        case .unavailable:
            agentContainer.isHidden = true
        }
    }

    private func setupFlipCameraControlComponents() {
        flipCameraContainer.addSubview(flipCameraControlButton)
        flipCameraContainer.addSubview(flipCameraIconView)
        flipCameraContainer.addSubview(flipCameraLabel)

        flipCameraControlButton.backgroundColor = .clear
        flipCameraControlButton.addTarget(self, action: #selector(handleFlipCameraControlButtonTapped), for: .touchUpInside)

        flipCameraIconView.image = UIImage.lmSymbol("arrow.triangle.2.circlepath.camera", pointSize: 18)
        flipCameraIconView.tintColor = .white
        flipCameraIconView.contentMode = .scaleAspectFit

        flipCameraLabel.text = LMLaunageManager.shared.camera.flipCamera
        configureControlLabel(flipCameraLabel)

        configureControlItemLayout(
            container: flipCameraContainer,
            button: flipCameraControlButton,
            iconView: flipCameraIconView,
            label: flipCameraLabel
        )
        controlsStackView.addArrangedSubview(flipCameraContainer)
    }

    @objc private func handleFlipCameraControlButtonTapped() {
        addTapAnimation(to: flipCameraContainer)
        delegate?.cameraControlsViewDidTapFlipCamera(self)
    }

    private func setupFlashControlComponents() {
        flashContainer.addSubview(flashControlButton)
        flashContainer.addSubview(flashIconView)
        flashContainer.addSubview(flashLabel)
        
        // 配置按钮
        flashControlButton.backgroundColor = UIColor.clear
        flashControlButton.addTarget(self, action: #selector(handleFlashControlButtonTapped), for: .touchUpInside)
        
        // 配置图标
        flashIconView.contentMode = .scaleAspectFit
        
        // 配置标签
        flashLabel.text = LMText.camera.flash
        configureControlLabel(flashLabel)
        
        configureControlItemLayout(container: flashContainer, button: flashControlButton, 
                                 iconView: flashIconView, label: flashLabel)
        controlsStackView.addArrangedSubview(flashContainer)
    }
    
    private func setupRatioControlComponents() {
        ratioContainer.addSubview(ratioControlButton)
        ratioContainer.addSubview(ratioIconView)
        ratioContainer.addSubview(ratioLabel)
        
        // 配置按钮
        ratioControlButton.backgroundColor = UIColor.clear
        ratioControlButton.addTarget(self, action: #selector(handleRatioControlButtonTapped), for: .touchUpInside)
        
        // 配置图标
        ratioIconView.contentMode = .scaleAspectFit
        
        // 配置标签
        ratioLabel.text = LMText.camera.ratio
        configureControlLabel(ratioLabel)
        
        configureControlItemLayout(container: ratioContainer, button: ratioControlButton, 
                                 iconView: ratioIconView, label: ratioLabel)
        controlsStackView.addArrangedSubview(ratioContainer)
    }
    
    private func setupTimerControlComponents() {
        timerContainer.addSubview(timerControlButton)
        timerContainer.addSubview(timerIconView)
        timerContainer.addSubview(timerBadgeLabel)
        timerContainer.addSubview(timerLabel)
        
        // 配置按钮
        timerControlButton.backgroundColor = UIColor.clear
        timerControlButton.addTarget(self, action: #selector(handleTimerControlButtonTapped), for: .touchUpInside)
        
        // 配置图标
        timerIconView.contentMode = .scaleAspectFit

        timerBadgeLabel.font = UIFont.systemFont(ofSize: 8, weight: .bold)
        timerBadgeLabel.textColor = .white
        timerBadgeLabel.textAlignment = .center
        timerBadgeLabel.isHidden = true
        timerBadgeLabel.layer.shadowColor = UIColor.black.cgColor
        timerBadgeLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        timerBadgeLabel.layer.shadowRadius = 1
        timerBadgeLabel.layer.shadowOpacity = 0.8
        
        // 配置标签
        timerLabel.text = LMText.camera.timer
        configureControlLabel(timerLabel)
        
        configureControlItemLayout(container: timerContainer, button: timerControlButton, 
                                 iconView: timerIconView, label: timerLabel)
        timerBadgeLabel.snp.makeConstraints { make in
            make.centerX.equalTo(timerIconView)
            make.bottom.equalTo(timerIconView).offset(1)
        }
        controlsStackView.addArrangedSubview(timerContainer)
    }
    
    private func setupLiveControlComponents() {
        liveContainer.addSubview(liveControlButton)
        liveContainer.addSubview(liveIconView)
        liveContainer.addSubview(liveLabel)
        
        // 配置按钮
        liveControlButton.backgroundColor = UIColor.clear
        liveControlButton.addTarget(self, action: #selector(handleLiveControlButtonTapped), for: .touchUpInside)
        
        // 配置图标
        liveIconView.contentMode = .scaleAspectFit
        
        // 配置标签
        liveLabel.text = LMText.camera.live
        configureControlLabel(liveLabel)
        
        configureControlItemLayout(container: liveContainer, button: liveControlButton, 
                                 iconView: liveIconView, label: liveLabel)
        controlsStackView.addArrangedSubview(liveContainer)
    }
    
    private func setupGridControlComponents() {
        gridContainer.layer.cornerRadius = 6
        gridContainer.addSubview(gridControlButton)
        gridContainer.addSubview(gridIconView)
        gridContainer.addSubview(gridLabel)
        
        // 配置按钮
        gridControlButton.backgroundColor = UIColor.clear
        gridControlButton.addTarget(self, action: #selector(handleGridControlButtonTapped),
                                    for: .touchUpInside)
        
        // 配置图标
        gridIconView.contentMode = .scaleAspectFit
        
        // 配置标签
        gridLabel.text = LMText.camera.grid
        configureControlLabel(gridLabel)
        
        configureControlItemLayout(container: gridContainer, button: gridControlButton, 
                                 iconView: gridIconView, label: gridLabel)
        controlsStackView.addArrangedSubview(gridContainer)
    }
    
    private func configureControlLabel(_ label: UILabel) {
        // 根据HTML设计配置标签样式
        label.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.letterSpacing = 0.3
        
        // 添加文字阴影效果
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowRadius = 3
        label.layer.shadowOpacity = 0.7
    }
    
    private func configureControlItemLayout(container: UIView, button: UIButton, 
                                          iconView: UIImageView, label: UILabel) {
        // 按钮覆盖整个容器区域
        button.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 图标位置
        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(24) // 根据HTML中的图标大小
        }
        
        // 标签位置
        label.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-2)
            make.leading.trailing.equalToSuperview()
        }
        
        // 容器尺寸
        container.snp.makeConstraints { make in
            make.width.equalTo(44) // 根据HTML设计调整宽度
            make.height.equalTo(50)
        }
        
        // 添加点击效果
        addTouchEffectToContainer(container)
    }
    
    private func addTouchEffectToContainer(_ container: UIView) {
        container.layer.cornerRadius = 8
        container.backgroundColor = UIColor.clear
    }
}

extension LMCameraControlsView {
    
    private func configureLayoutConstraints() {
        // 根据HTML设计，右侧控制面板位于屏幕右侧中央
        controlsStackView.snp.makeConstraints { make in
            make.top.equalTo(8)
            make.trailing.equalToSuperview().offset(-8)
            make.leading.equalToSuperview().offset(8)
            make.bottom.equalTo(-8)
        }
    }
}

extension LMCameraControlsView {
    
    private func configureDefaultContentAndStyles() {
        backgroundColor = UIColor.clear
        updateControlButtonsAppearance()
    }
    
    private func updateControlButtonsAppearance() {
        updateFlashAppearance()
        updateRatioAppearance()
        updateTimerAppearance()
        updateLivePhotoAppearance()
        updateGridAppearance()
    }
    
    private func updateFlashAppearance() {
        flashIconView.image = UIImage.lmSymbol(currentFlashMode.symbolName, pointSize: 18)
        flashIconView.tintColor = UIColor.white
        addIconShadow(to: flashIconView)
    }
    
    private func updateRatioAppearance() {
        let iconName = currentAspectRatio.iconName
        ratioIconView.image = UIImage(named: iconName)
        ratioIconView.tintColor = UIColor.white
        addIconShadow(to: ratioIconView)
    }
    
    private func updateTimerAppearance() {
        timerIconView.image = UIImage.lmSymbol("timer", pointSize: 18)
        timerIconView.tintColor = UIColor.white
        timerIconView.alpha = currentTimerDuration == .off ? 0.55 : 1.0
        if let badge = currentTimerDuration.badgeText {
            timerBadgeLabel.text = badge
            timerBadgeLabel.isHidden = false
        } else {
            timerBadgeLabel.text = nil
            timerBadgeLabel.isHidden = true
        }
        addIconShadow(to: timerIconView)
    }
    
    private func updateLivePhotoAppearance() {
        let symbol = isLivePhotoEnabled ? "livephoto" : "livephoto.slash"
        liveIconView.image = UIImage.lmSymbol(symbol, pointSize: 18)
        liveIconView.tintColor = UIColor.white
        addIconShadow(to: liveIconView)
    }
    
    private func updateGridAppearance() {
        gridIconView.image = UIImage.lmSymbol("grid", pointSize: 18)
        gridIconView.tintColor = UIColor.white
        
        // 根据HTML设计，激活状态有特殊颜色
        if isGridEnabled {
            gridContainer.backgroundColor = .hexColor("667EEA", alpha: 0.3)
        } else {
            gridContainer.backgroundColor = UIColor.clear
        }
        
        addIconShadow(to: gridIconView)
    }
    
    private func addIconShadow(to imageView: UIImageView) {
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOffset = CGSize(width: 0, height: 1)
        imageView.layer.shadowRadius = 2
        imageView.layer.shadowOpacity = 0.5
    }
}

extension LMCameraControlsView {
    
    @objc private func handleFlashControlButtonTapped() {
        // 根据HTML逻辑循环切换闪光灯模式
        switch currentFlashMode {
        case .auto:
            currentFlashMode = .on
        case .on:
            currentFlashMode = .off
        case .off:
            currentFlashMode = .auto
        }
        
        addTapAnimation(to: flashContainer)
        updateFlashAppearance()
        delegate?.cameraControlsView(self, didChangeFlashMode: currentFlashMode)
    }
    
    @objc private func handleRatioControlButtonTapped() {
        // 根据HTML逻辑循环切换宽高比
        switch currentAspectRatio {
        case .ratio3_4:
            currentAspectRatio = .ratio1_1
        case .ratio1_1:
            currentAspectRatio = .ratio9_16
        case .ratio9_16:
            currentAspectRatio = .ratio3_4
        }
        
        addTapAnimation(to: ratioContainer)
        updateRatioAppearance()
        delegate?.cameraControlsView(self, didChangeAspectRatio: currentAspectRatio)
    }
    
    @objc private func handleTimerControlButtonTapped() {
        // 根据HTML逻辑循环切换定时器时间
        switch currentTimerDuration {
        case .off:
            currentTimerDuration = .three
        case .three:
            currentTimerDuration = .five
        case .five:
            currentTimerDuration = .ten
        case .ten:
            currentTimerDuration = .off
        }
        
        addTapAnimation(to: timerContainer)
        updateTimerAppearance()
        delegate?.cameraControlsView(self, didChangeTimer: currentTimerDuration)
    }
    
    @objc private func handleLiveControlButtonTapped() {
        isLivePhotoEnabled.toggle()
        
        addTapAnimation(to: liveContainer)
        updateLivePhotoAppearance()
        delegate?.cameraControlsView(self, didToggleLivePhoto: isLivePhotoEnabled)
    }
    
    @objc private func handleGridControlButtonTapped() {
        isGridEnabled.toggle()
        
        addTapAnimation(to: gridContainer)
        updateGridAppearance()
        delegate?.cameraControlsView(self, didToggleGrid: isGridEnabled)
    }
    
    private func addTapAnimation(to view: UIView) {
        // 添加点击动画效果
        UIView.animate(withDuration: 0.1, animations: {
            view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                view.transform = CGAffineTransform.identity
            }
        }
    }
}

// MARK: - Public Methods
extension LMCameraControlsView {
    
    /// 更新闪光灯模式
    func updateFlashMode(_ mode: LMFlashMode) {
        currentFlashMode = mode
        updateFlashAppearance()
    }
    
    /// 更新宽高比设置
    func updateAspectRatio(_ ratio: LMAspectRatio) {
        currentAspectRatio = ratio
        updateRatioAppearance()
    }
    
    /// 更新定时器设置
    func updateTimerDuration(_ duration: LMTimerDuration) {
        currentTimerDuration = duration
        updateTimerAppearance()
    }
    
    /// 更新Live Photo状态
    func updateLivePhotoStatus(_ enabled: Bool) {
        isLivePhotoEnabled = enabled
        updateLivePhotoAppearance()
    }
    
    /// 更新网格状态
    func updateGridStatus(_ enabled: Bool) {
        isGridEnabled = enabled
        updateGridAppearance()
    }
    
    /// 获取当前闪光灯模式
    func getCurrentFlashMode() -> LMFlashMode {
        return currentFlashMode
    }
    
    /// 获取当前宽高比
    func getCurrentAspectRatio() -> LMAspectRatio {
        return currentAspectRatio
    }
    
    /// 获取当前定时器设置
    func getCurrentTimerDuration() -> LMTimerDuration {
        return currentTimerDuration
    }
    
    /// 获取当前Live Photo状态
    func getCurrentLivePhotoStatus() -> Bool {
        return isLivePhotoEnabled
    }
    
    /// 获取当前网格状态
    func getCurrentGridStatus() -> Bool {
        return isGridEnabled
    }
    
    /// 根据宽高比设置控件状态（用于不同相机状态间的同步）
    func syncWithCameraState(aspectRatio: LMAspectRatio, flashMode: LMFlashMode, 
                            timerDuration: LMTimerDuration, livePhotoEnabled: Bool, 
                            gridEnabled: Bool) {
        currentAspectRatio = aspectRatio
        currentFlashMode = flashMode
        currentTimerDuration = timerDuration
        isLivePhotoEnabled = livePhotoEnabled
        isGridEnabled = gridEnabled
        
        updateControlButtonsAppearance()
    }
}

// MARK: - UILabel Extension for Letter Spacing
extension UILabel {
    var letterSpacing: CGFloat {
        get {
            return 0
        }
        set {
            let attributedString = NSMutableAttributedString(string: text ?? "")
            attributedString.addAttribute(.kern, value: newValue, range: NSRange(location: 0, length: attributedString.length))
            attributedText = attributedString
        }
    }
}
