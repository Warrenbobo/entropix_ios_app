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
    
    var iconName: String {
        switch self {
        case .auto: return "flash_auto_mode"
        case .on: return "flash_on_mode"
        case .off: return "flash_off"
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
    
    var iconName: String {
        switch self {
        case .off: return "camera_timer_off_state"
        case .three: return "backward_3_seconds"
        case .five: return "backward_5_seconds"
        case .ten: return "backward_10_seconds"
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
}

class LMCameraControlsView: UIView {
    
    // MARK: - UI Components
    private let controlsStackView = UIStackView()
    
    // 控制项容器
    private let flashContainer = UIView()
    private let ratioContainer = UIView()
    private let timerContainer = UIView()
    private let liveContainer = UIView()
    private let gridContainer = UIView()
    
    // 功能按钮
    private let flashControlButton = UIButton()
    private let ratioControlButton = UIButton()
    private let timerControlButton = UIButton()
    private let liveControlButton = UIButton()
    private let gridControlButton = UIButton()
    
    // 图标视图
    private let flashIconView = UIImageView()
    private let ratioIconView = UIImageView()
    private let timerIconView = UIImageView()
    private let liveIconView = UIImageView()
    private let gridIconView = UIImageView()
    
    // 功能标签
    private let flashLabel = UILabel()
    private let ratioLabel = UILabel()
    private let timerLabel = UILabel()
    private let liveLabel = UILabel()
    private let gridLabel = UILabel()
    
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
        
        setupFlashControlComponents()
        setupRatioControlComponents()
        setupTimerControlComponents()
        setupLiveControlComponents()
        setupGridControlComponents()
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
        flashLabel.text = "Flash"
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
        ratioLabel.text = "Ratio"
        configureControlLabel(ratioLabel)
        
        configureControlItemLayout(container: ratioContainer, button: ratioControlButton, 
                                 iconView: ratioIconView, label: ratioLabel)
        controlsStackView.addArrangedSubview(ratioContainer)
    }
    
    private func setupTimerControlComponents() {
        timerContainer.addSubview(timerControlButton)
        timerContainer.addSubview(timerIconView)
        timerContainer.addSubview(timerLabel)
        
        // 配置按钮
        timerControlButton.backgroundColor = UIColor.clear
        timerControlButton.addTarget(self, action: #selector(handleTimerControlButtonTapped), for: .touchUpInside)
        
        // 配置图标
        timerIconView.contentMode = .scaleAspectFit
        
        // 配置标签
        timerLabel.text = "Timer"
        configureControlLabel(timerLabel)
        
        configureControlItemLayout(container: timerContainer, button: timerControlButton, 
                                 iconView: timerIconView, label: timerLabel)
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
        liveLabel.text = "Live"
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
        gridLabel.text = "Grid"
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
        let iconName = currentFlashMode.iconName
        flashIconView.image = UIImage(named: iconName)
        
        // 根据HTML设计，图标默认为白色，添加阴影
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
        let iconName = currentTimerDuration.iconName
        timerIconView.image = UIImage(named: iconName)
        timerIconView.tintColor = UIColor.white
        addIconShadow(to: timerIconView)
    }
    
    private func updateLivePhotoAppearance() {
        let iconName = isLivePhotoEnabled ? "live_photo_on" : "live_photo_off"
        liveIconView.image = UIImage(named: iconName)
        liveIconView.tintColor = UIColor.white
        addIconShadow(to: liveIconView)
    }
    
    private func updateGridAppearance() {
        let iconName = isGridEnabled ? "grid_on" : "grid_off"
        gridIconView.image = UIImage(named: iconName)
        
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
