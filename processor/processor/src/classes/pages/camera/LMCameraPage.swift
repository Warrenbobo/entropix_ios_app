//
//  LMCameraPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import AVFoundation
import SnapKit

class LMCameraPage: LMPageWrapper {
    
    private let topStatusBarView = UIView()
    private let userProfileButton = UIButton()
    
    private var cameraPreviewView: LMCameraPreviewView!
    private var cameraControlsView: LMCameraControlsView!
    private var cameraBottomControlsView: LMCameraBottomControlsView!
    
    private var captureSession: AVCaptureSession?
    private var currentCameraDevice: AVCaptureDevice?
    private var photoOutput: AVCapturePhotoOutput?
    private var isUsingFrontCamera = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraPageComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        setupCameraSession()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        startCameraSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCameraSession()
    }
}

extension LMCameraPage {
    
    private func setupCameraPageComponents() {
        setupTopStatusBarComponents()
        setupCameraPreviewComponent()
        setupCameraControlsComponent()
        setupCameraBottomControlsComponent()
    }
    
    private func setupTopStatusBarComponents() {
        view.addSubview(topStatusBarView)
        topStatusBarView.addSubview(userProfileButton)
        
        topStatusBarView.backgroundColor = UIColor.clear
        
        userProfileButton.setImage(UIImage(systemName: "person.circle"), for: .normal)
        userProfileButton.tintColor = UIColor.white
        userProfileButton.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        userProfileButton.layer.cornerRadius = 20
        userProfileButton.addTarget(self, action: #selector(handleUserProfileButtonTapped), for: .touchUpInside)
    }
    
    private func setupCameraPreviewComponent() {
        cameraPreviewView = LMCameraPreviewView()
        cameraPreviewView.delegate = self
        view.addSubview(cameraPreviewView)
    }
    
    private func setupCameraControlsComponent() {
        cameraControlsView = LMCameraControlsView()
        cameraControlsView.delegate = self
        view.addSubview(cameraControlsView)
    }
    
    private func setupCameraBottomControlsComponent() {
        cameraBottomControlsView = LMCameraBottomControlsView()
        cameraBottomControlsView.delegate = self
        view.addSubview(cameraBottomControlsView)
    }
}

extension LMCameraPage {
    
    private func configureLayoutConstraints() {
        // 顶部状态栏
        topStatusBarView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(AppTheme.Screen.safeAreaTop + 60)
        }
        
        userProfileButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-10)
            make.size.equalTo(40)
        }
        
        // 相机预览
        cameraPreviewView.snp.makeConstraints { make in
            make.top.equalTo(topStatusBarView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(cameraBottomControlsView.snp.top)
        }
        
        // 右侧控制
        cameraControlsView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalTo(cameraPreviewView)
            make.width.equalTo(80)
        }
        
        // 底部控制
        cameraBottomControlsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(120)
        }
    }
}

extension LMCameraPage {
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = UIColor.black
        
        // 设置状态栏样式
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .dark
        }
    }
}

extension LMCameraPage {
    
    private func setupCameraSession() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        // 设置会话预设
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        }
        
        // 设置相机输入
        setupCameraInput()
        
        // 设置照片输出
        setupPhotoOutput()
        
        captureSession.commitConfiguration()
        
        // 配置预览视图
        cameraPreviewView.configureCaptureSession(captureSession)
    }
    
    private func setupCameraInput() {
        guard let captureSession = captureSession else { return }
        
        // 获取后置摄像头
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Unable to access back camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentCameraDevice = backCamera
            }
        } catch {
            print("Error setting up camera input: \(error)")
        }
    }
    
    private func setupPhotoOutput() {
        guard let captureSession = captureSession else { return }
        
        photoOutput = AVCapturePhotoOutput()
        
        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }
    
    private func startCameraSession() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.startRunning()
        }
    }
    
    private func stopCameraSession() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.stopRunning()
        }
    }
    
    private func switchCameraPosition() {
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        // 移除当前输入
        if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            captureSession.removeInput(currentInput)
        }
        
        // 切换摄像头位置
        let newPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .back : .front
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                currentCameraDevice = newCamera
                isUsingFrontCamera.toggle()
            }
        } catch {
            print("Error switching camera: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
}

extension LMCameraPage {
    
    @objc private func handleUserProfileButtonTapped() {
        print("User profile button tapped")
        // 导航到用户资料页面
        navigateToUserProfilePage()
    }
    
    private func navigateToUserProfilePage() {
        // 这里可以导航到用户资料页面
        navigationController?.popViewController(animated: true)
    }
    
    private func capturePhoto() {
        guard let photoOutput = photoOutput else { return }
        
        let photoSettings = AVCapturePhotoSettings()
        
        // 设置闪光灯模式
        if cameraControlsView.getCurrentFlashModeStatus() {
            photoSettings.flashMode = .on
        } else {
            photoSettings.flashMode = .off
        }
        
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
        
        // 显示拍照动画
        cameraBottomControlsView.showCaptureAnimation()
    }
    
    private func handleInspireMeFeature() {
        print("Inspire Me feature activated")
        
        // 减少Inspire点数
        cameraBottomControlsView.decrementInspirePointsCount()
        
        // 这里可以实现AI启发功能
        // 例如：显示拍摄建议、滤镜推荐等
        showInspireMeDialog()
    }
    
    private func showInspireMeDialog() {
        let alertController = UIAlertController(
            title: "Inspire Me",
            message: "AI suggests: Try capturing this scene with a lower angle for more dramatic effect!",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "Got it!", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
}

extension LMCameraPage: LMCameraPreviewViewDelegate {
    
    func cameraPreviewViewDidTapToFocus(at point: CGPoint) {
        guard let device = currentCameraDevice else { return }
        
        let devicePoint = cameraPreviewView.convertPointToDeviceCoordinates(point)
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting focus: \(error)")
        }
    }
    
    func cameraPreviewViewDidPinchToZoom(scale: CGFloat) {
        guard let device = currentCameraDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            let currentZoomFactor = device.videoZoomFactor
            let newZoomFactor = min(max(currentZoomFactor * scale, 1.0), device.activeFormat.videoMaxZoomFactor)
            
            device.videoZoomFactor = newZoomFactor
            device.unlockForConfiguration()
        } catch {
            print("Error setting zoom: \(error)")
        }
    }
}

// MARK: - Camera Controls View Delegate Methods
extension LMCameraPage: LMCameraControlsViewDelegate {
    
    func cameraControlsViewDidTapFlashButton() {
        print("Flash button tapped")
        // 闪光灯状态已在控件内部管理
    }
    
    func cameraControlsViewDidTapRatioButton() {
        print("Ratio button tapped - Current ratio: \(cameraControlsView.getCurrentAspectRatioSetting())")
        // 这里可以实现宽高比切换逻辑
        updateCameraPreviewAspectRatio()
    }
    
    func cameraControlsViewDidTapTimerButton() {
        print("Timer button tapped - Duration: \(cameraControlsView.getCurrentTimerDurationSetting())s")
        // 定时器功能已在控件内部管理
    }
    
    func cameraControlsViewDidTapLiveButton() {
        print("Live button tapped - Enabled: \(cameraControlsView.getCurrentLiveModeStatus())")
        // Live Photos功能
        configureLivePhotosMode()
    }
    
    func cameraControlsViewDidTapGridButton() {
        print("Grid button tapped - Enabled: \(cameraControlsView.getCurrentGridModeStatus())")
        // 切换网格显示
        cameraPreviewView.setGridVisibility(cameraControlsView.getCurrentGridModeStatus())
    }
    
    private func updateCameraPreviewAspectRatio() {
        // 根据选择的比例更新预览视图
        let currentRatio = cameraControlsView.getCurrentAspectRatioSetting()
        print("Updating camera preview to ratio: \(currentRatio)")
        // 这里可以实现具体的比例切换逻辑
    }
    
    private func configureLivePhotosMode() {
        guard let photoOutput = photoOutput else { return }
        
        if cameraControlsView.getCurrentLiveModeStatus() {
            if photoOutput.isLivePhotoCaptureSupported {
                photoOutput.isLivePhotoCaptureEnabled = true
                print("Live Photos enabled")
            }
        } else {
            photoOutput.isLivePhotoCaptureEnabled = false
            print("Live Photos disabled")
        }
    }
}

// MARK: - Camera Bottom Controls View Delegate Methods
extension LMCameraPage: LMCameraBottomControlsViewDelegate {
    
    func cameraBottomControlsViewDidTapInspireButton() {
        print("Inspire button tapped")
        handleInspireMeFeature()
    }
    
    func cameraBottomControlsViewDidTapCaptureButton() {
        print("Capture button tapped")
        
        let timerDuration = cameraControlsView.getCurrentTimerDurationSetting()
        
        if timerDuration > 0 {
            startTimerCapture(duration: timerDuration)
        } else {
            capturePhoto()
        }
    }
    
    func cameraBottomControlsViewDidTapFlipCameraButton() {
        print("Flip camera button tapped")
        switchCameraPosition()
    }
    
    func cameraBottomControlsViewDidTogglePremiumMode(_ enabled: Bool) {
        print("Premium mode toggled: \(enabled)")
        configurePremiumModeFeatures(enabled)
    }
    
    private func startTimerCapture(duration: Int) {
        print("Starting timer capture with \(duration) seconds")
        
        // 显示倒计时UI
        showCountdownTimer(duration: duration) {
            self.capturePhoto()
        }
    }
    
    private func showCountdownTimer(duration: Int, completion: @escaping () -> Void) {
        let countdownLabel = UILabel()
        countdownLabel.font = UIFont.systemFont(ofSize: 60, weight: .bold)
        countdownLabel.textColor = UIColor.white
        countdownLabel.textAlignment = .center
        countdownLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        countdownLabel.layer.cornerRadius = 50
        countdownLabel.clipsToBounds = true
        
        view.addSubview(countdownLabel)
        countdownLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(100)
        }
        
        var remainingTime = duration
        countdownLabel.text = "\(remainingTime)"
        
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            remainingTime -= 1
            
            if remainingTime > 0 {
                countdownLabel.text = "\(remainingTime)"
                
                // 添加缩放动画
                UIView.animate(withDuration: 0.3) {
                    countdownLabel.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                } completion: { _ in
                    UIView.animate(withDuration: 0.3) {
                        countdownLabel.transform = CGAffineTransform.identity
                    }
                }
            } else {
                timer.invalidate()
                countdownLabel.removeFromSuperview()
                completion()
            }
        }
    }
    
    private func configurePremiumModeFeatures(_ enabled: Bool) {
        if enabled {
            print("Premium mode features enabled")
            // 启用高级功能：更高分辨率、专业模式等
        } else {
            print("Premium mode features disabled")
            // 禁用高级功能
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate Methods
extension LMCameraPage: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let capturedImage = UIImage(data: imageData) else {
            print("Error processing photo data")
            return
        }
        
        // 保存照片到相册
        UIImageWriteToSavedPhotosAlbum(capturedImage, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
        
        print("Photo captured successfully")
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            print("Error saving photo: \(error)")
            showPhotoSaveErrorAlert()
        } else {
            print("Photo saved successfully")
            showPhotoSavedConfirmation()
        }
    }
    
    private func showPhotoSaveErrorAlert() {
        let alertController = UIAlertController(
            title: "Save Error",
            message: "Unable to save photo to your photo library.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
    
    private func showPhotoSavedConfirmation() {
        // 显示简单的确认动画
        let checkmarkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        checkmarkView.tintColor = UIColor.systemGreen
        checkmarkView.backgroundColor = UIColor.white
        checkmarkView.layer.cornerRadius = 25
        checkmarkView.clipsToBounds = true
        
        view.addSubview(checkmarkView)
        checkmarkView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(50)
        }
        
        checkmarkView.alpha = 0
        checkmarkView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        UIView.animate(withDuration: 0.3, animations: {
            checkmarkView.alpha = 1
            checkmarkView.transform = CGAffineTransform.identity
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.0, animations: {
                checkmarkView.alpha = 0
                checkmarkView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            }) { _ in
                checkmarkView.removeFromSuperview()
            }
        }
    }
}

extension LMCameraPage {
    
    func updateInspirePointsConfiguration(_ points: Int) {
        cameraBottomControlsView.updateInspirePointsCount(points)
    }
    
    func setPremiumModeConfiguration(_ enabled: Bool) {
        cameraBottomControlsView.setPremiumModeEnabled(enabled)
    }
}
