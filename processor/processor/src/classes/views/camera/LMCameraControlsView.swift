//
//  LMCameraControlsView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

protocol LMCameraControlsViewDelegate: AnyObject {
    func cameraControlsViewDidTapFlashButton()
    func cameraControlsViewDidTapRatioButton()
    func cameraControlsViewDidTapTimerButton()
    func cameraControlsViewDidTapLiveButton()
    func cameraControlsViewDidTapGridButton()
}

class LMCameraControlsView: UIView {
    
    private let controlsStackView = UIStackView()
    
    // 功能按钮
    private let flashControlButton = UIButton()
    private let ratioControlButton = UIButton()
    private let timerControlButton = UIButton()
    private let liveControlButton = UIButton()
    private let gridControlButton = UIButton()
    
    // 功能标签
    private let flashLabel = UILabel()
    private let ratioLabel = UILabel()
    private let timerLabel = UILabel()
    private let liveLabel = UILabel()
    private let gridLabel = UILabel()
    
    weak var delegate: LMCameraControlsViewDelegate?
    
    private var isFlashEnabled = false
    private var currentRatio = "3:4"
    private var timerDuration = 0
    private var isLiveMode = false
    private var isGridEnabled = false
    
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
        
        controlsStackView.axis = .vertical
        controlsStackView.spacing = 32
        controlsStackView.alignment = .center
        controlsStackView.distribution = .equalSpacing
        
        setupFlashControlComponents()
        setupRatioControlComponents()
        setupTimerControlComponents()
        setupLiveControlComponents()
        setupGridControlComponents()
    }
    
    private func setupFlashControlComponents() {
        let flashContainer = createControlContainerView()
        flashContainer.addSubview(flashControlButton)
        flashContainer.addSubview(flashLabel)
        
        flashControlButton.setImage(UIImage(systemName: "bolt.slash"), for: .normal)
        flashControlButton.tintColor = UIColor.white
        flashControlButton.addTarget(self, action: #selector(handleFlashControlButtonTapped), for: .touchUpInside)
        
        flashLabel.text = "Flash"
        configureControlLabel(flashLabel)
        
        configureControlButtonAndLabelLayout(button: flashControlButton, label: flashLabel, in: flashContainer)
        controlsStackView.addArrangedSubview(flashContainer)
    }
    
    private func setupRatioControlComponents() {
        let ratioContainer = createControlContainerView()
        ratioContainer.addSubview(ratioControlButton)
        ratioContainer.addSubview(ratioLabel)
        
        ratioControlButton.setTitle("3:4", for: .normal)
        ratioControlButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        ratioControlButton.setTitleColor(UIColor.white, for: .normal)
        ratioControlButton.addTarget(self, action: #selector(handleRatioControlButtonTapped), for: .touchUpInside)
        
        ratioLabel.text = "Ratio"
        configureControlLabel(ratioLabel)
        
        configureControlButtonAndLabelLayout(button: ratioControlButton, label: ratioLabel, in: ratioContainer)
        controlsStackView.addArrangedSubview(ratioContainer)
    }
    
    private func setupTimerControlComponents() {
        let timerContainer = createControlContainerView()
        timerContainer.addSubview(timerControlButton)
        timerContainer.addSubview(timerLabel)
        
        timerControlButton.setImage(UIImage(systemName: "timer"), for: .normal)
        timerControlButton.tintColor = UIColor.white
        timerControlButton.addTarget(self, action: #selector(handleTimerControlButtonTapped), for: .touchUpInside)
        
        timerLabel.text = "Timer"
        configureControlLabel(timerLabel)
        
        configureControlButtonAndLabelLayout(button: timerControlButton, label: timerLabel, in: timerContainer)
        controlsStackView.addArrangedSubview(timerContainer)
    }
    
    private func setupLiveControlComponents() {
        let liveContainer = createControlContainerView()
        liveContainer.addSubview(liveControlButton)
        liveContainer.addSubview(liveLabel)
        
        liveControlButton.setImage(UIImage(systemName: "livephoto"), for: .normal)
        liveControlButton.tintColor = UIColor.white
        liveControlButton.addTarget(self, action: #selector(handleLiveControlButtonTapped), for: .touchUpInside)
        
        liveLabel.text = "Live"
        configureControlLabel(liveLabel)
        
        configureControlButtonAndLabelLayout(button: liveControlButton, label: liveLabel, in: liveContainer)
        controlsStackView.addArrangedSubview(liveContainer)
    }
    
    private func setupGridControlComponents() {
        let gridContainer = createControlContainerView()
        gridContainer.addSubview(gridControlButton)
        gridContainer.addSubview(gridLabel)
        
        gridControlButton.setImage(UIImage(systemName: "grid"), for: .normal)
        gridControlButton.tintColor = UIColor.white
        gridControlButton.addTarget(self, action: #selector(handleGridControlButtonTapped), for: .touchUpInside)
        
        gridLabel.text = "Grid"
        configureControlLabel(gridLabel)
        
        configureControlButtonAndLabelLayout(button: gridControlButton, label: gridLabel, in: gridContainer)
        controlsStackView.addArrangedSubview(gridContainer)
    }
    
    private func createControlContainerView() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.clear
        return container
    }
    
    private func configureControlLabel(_ label: UILabel) {
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.numberOfLines = 1
    }
    
    private func configureControlButtonAndLabelLayout(button: UIButton, label: UILabel, in container: UIView) {
        button.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(32)
        }
        
        label.snp.makeConstraints { make in
            make.top.equalTo(button.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
            make.width.equalTo(50)
        }
        
        container.snp.makeConstraints { make in
            make.width.equalTo(50)
        }
    }
}

extension LMCameraControlsView {
    
    private func configureLayoutConstraints() {
        controlsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }
}

extension LMCameraControlsView {
    
    private func configureDefaultContentAndStyles() {
        backgroundColor = UIColor.clear
        updateControlButtonsAppearance()
    }
    
    private func updateControlButtonsAppearance() {
        // 更新闪光灯按钮
        let flashImageName = isFlashEnabled ? "bolt" : "bolt.slash"
        flashControlButton.setImage(UIImage(systemName: flashImageName), for: .normal)
        flashControlButton.tintColor = isFlashEnabled ? UIColor.systemYellow : UIColor.white
        
        // 更新比例按钮
        ratioControlButton.setTitle(currentRatio, for: .normal)
        
        // 更新定时器按钮
        let timerImageName = timerDuration > 0 ? "timer.circle.fill" : "timer"
        timerControlButton.setImage(UIImage(systemName: timerImageName), for: .normal)
        timerControlButton.tintColor = timerDuration > 0 ? UIColor.systemYellow : UIColor.white
        
        // 更新Live按钮
        let liveImageName = isLiveMode ? "livephoto.play" : "livephoto"
        liveControlButton.setImage(UIImage(systemName: liveImageName), for: .normal)
        liveControlButton.tintColor = isLiveMode ? UIColor.systemYellow : UIColor.white
        
        // 更新网格按钮
        let gridImageName = isGridEnabled ? "grid.circle.fill" : "grid"
        gridControlButton.setImage(UIImage(systemName: gridImageName), for: .normal)
        gridControlButton.tintColor = isGridEnabled ? UIColor.systemYellow : UIColor.white
    }
}

extension LMCameraControlsView {
    
    @objc private func handleFlashControlButtonTapped() {
        isFlashEnabled.toggle()
        updateControlButtonsAppearance()
        delegate?.cameraControlsViewDidTapFlashButton()
    }
    
    @objc private func handleRatioControlButtonTapped() {
        // 循环切换比例
        switch currentRatio {
        case "3:4":
            currentRatio = "1:1"
        case "1:1":
            currentRatio = "16:9"
        case "16:9":
            currentRatio = "3:4"
        default:
            currentRatio = "3:4"
        }
        updateControlButtonsAppearance()
        delegate?.cameraControlsViewDidTapRatioButton()
    }
    
    @objc private func handleTimerControlButtonTapped() {
        // 循环切换定时器时间
        switch timerDuration {
        case 0:
            timerDuration = 3
        case 3:
            timerDuration = 10
        case 10:
            timerDuration = 0
        default:
            timerDuration = 0
        }
        updateControlButtonsAppearance()
        delegate?.cameraControlsViewDidTapTimerButton()
    }
    
    @objc private func handleLiveControlButtonTapped() {
        isLiveMode.toggle()
        updateControlButtonsAppearance()
        delegate?.cameraControlsViewDidTapLiveButton()
    }
    
    @objc private func handleGridControlButtonTapped() {
        isGridEnabled.toggle()
        updateControlButtonsAppearance()
        delegate?.cameraControlsViewDidTapGridButton()
    }
}

extension LMCameraControlsView {
    
    func updateFlashModeStatus(_ enabled: Bool) {
        isFlashEnabled = enabled
        updateControlButtonsAppearance()
    }
    
    func updateAspectRatioSetting(_ ratio: String) {
        currentRatio = ratio
        updateControlButtonsAppearance()
    }
    
    func updateTimerDurationSetting(_ duration: Int) {
        timerDuration = duration
        updateControlButtonsAppearance()
    }
    
    func updateLiveModeStatus(_ enabled: Bool) {
        isLiveMode = enabled
        updateControlButtonsAppearance()
    }
    
    func updateGridModeStatus(_ enabled: Bool) {
        isGridEnabled = enabled
        updateControlButtonsAppearance()
    }
    
    func getCurrentFlashModeStatus() -> Bool {
        return isFlashEnabled
    }
    
    func getCurrentAspectRatioSetting() -> String {
        return currentRatio
    }
    
    func getCurrentTimerDurationSetting() -> Int {
        return timerDuration
    }
    
    func getCurrentLiveModeStatus() -> Bool {
        return isLiveMode
    }
    
    func getCurrentGridModeStatus() -> Bool {
        return isGridEnabled
    }
}
