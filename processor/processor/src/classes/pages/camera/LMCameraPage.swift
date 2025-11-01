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
    private let backButton = UIButton()
    
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
        topStatusBarView.addSubview(backButton)
        
        backButton.setImage(UIImage(named: "left_arrow_white"), for: .normal)
        backButton.imageEdgeInsets = UIEdgeInsets(top: 0,
                                                  left: 0,
                                                  bottom: 0,
                                                  right: 10)
        backButton.addTarget(self, action: #selector(handleUserProfileButtonTapped), for: .touchUpInside)
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
            make.top.equalTo(AppTheme.Screen.safeAreaTop)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(44)
        }
        
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(44)
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
        
        // 根据当前闪光灯模式设置
        let currentFlashMode = cameraControlsView.getCurrentFlashMode()
        switch currentFlashMode {
        case .auto:
            photoSettings.flashMode = .auto
        case .on:
            photoSettings.flashMode = .on
        case .off:
            photoSettings.flashMode = .off
        }
        
        // 设置Live Photos
        if cameraControlsView.getCurrentLivePhotoStatus() && photoOutput.isLivePhotoCaptureSupported {
            photoSettings.livePhotoMovieFileURL = createLivePhotoMovieURL()
        }
        
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
        
        // 显示拍照动画
        cameraBottomControlsView.showCaptureAnimation()
    }
    
    private func createLivePhotoMovieURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileName = "LivePhoto_\(Date().timeIntervalSince1970).mov"
        return documentsDirectory.appendingPathComponent(fileName)
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
    
    func cameraControlsView(_ view: LMCameraControlsView, didChangeFlashMode mode: LMFlashMode) {
        print("Flash mode changed to: \(mode.displayName)")
        configureFlashMode(mode)
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didChangeAspectRatio ratio: LMAspectRatio) {
        print("Aspect ratio changed to: \(ratio.displayName)")
        updateCameraPreviewAspectRatio(ratio)
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didChangeTimer duration: LMTimerDuration) {
        print("Timer duration changed to: \(duration.displayName)")
        configureTimerDuration(duration)
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didToggleLivePhoto enabled: Bool) {
        print("Live Photo toggled: \(enabled)")
        configureLivePhotosMode(enabled)
    }
    
    func cameraControlsView(_ view: LMCameraControlsView, didToggleGrid enabled: Bool) {
        print("Grid toggled: \(enabled)")
        configureGridDisplay(enabled)
    }
    
    // MARK: - Private Configuration Methods
    
    private func configureFlashMode(_ mode: LMFlashMode) {
        guard let device = currentCameraDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            switch mode {
            case .auto:
                if device.hasFlash {
                    // 设置自动闪光灯模式
                    print("Flash set to auto mode")
                }
            case .on:
                if device.hasFlash {
                    // 设置强制开启闪光灯
                    print("Flash set to on")
                }
            case .off:
                // 关闭闪光灯
                print("Flash set to off")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error configuring flash mode: \(error)")
        }
    }
    
    private func updateCameraPreviewAspectRatio(_ ratio: LMAspectRatio) {
        // 根据选择的比例更新预览视图和相机会话
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        switch ratio {
        case .ratio3_4:
            // 设置 3:4 比例
            if captureSession.canSetSessionPreset(.photo) {
                captureSession.sessionPreset = .photo
            }
            print("Camera set to 3:4 ratio")
            
        case .ratio1_1:
            // 设置 1:1 比例 (正方形)
            if captureSession.canSetSessionPreset(.photo) {
                captureSession.sessionPreset = .photo
            }
            print("Camera set to 1:1 ratio")
            
        case .ratio9_16:
            // 设置 9:16 比例 (竖屏视频比例)
            if captureSession.canSetSessionPreset(.hd1920x1080) {
                captureSession.sessionPreset = .hd1920x1080
            }
            print("Camera set to 9:16 ratio")
        }
        
        captureSession.commitConfiguration()
        
        // 更新预览视图的显示比例
        updatePreviewViewAspectRatio(ratio)
    }
    
    private func updatePreviewViewAspectRatio(_ ratio: LMAspectRatio) {
        // 这里可以添加预览视图的比例调整逻辑
        // 例如：添加遮罩层来显示不同的宽高比
        print("Updating preview view for ratio: \(ratio.displayName)")
    }
    
    private func configureTimerDuration(_ duration: LMTimerDuration) {
        // 定时器配置已在控件内部管理，这里可以添加额外的逻辑
        print("Timer configured for \(duration.seconds) seconds")
    }
    
    private func configureLivePhotosMode(_ enabled: Bool) {
        guard let photoOutput = photoOutput else { return }
        
        if enabled {
            if photoOutput.isLivePhotoCaptureSupported {
                photoOutput.isLivePhotoCaptureEnabled = true
                print("Live Photos enabled")
            } else {
                print("Live Photos not supported on this device")
                // 可以显示提示信息给用户
                showLivePhotosNotSupportedAlert()
            }
        } else {
            photoOutput.isLivePhotoCaptureEnabled = false
            print("Live Photos disabled")
        }
    }
    
    private func configureGridDisplay(_ enabled: Bool) {
        // 切换网格显示
        cameraPreviewView.setGridVisibility(enabled)
        print("Grid display \(enabled ? "enabled" : "disabled")")
    }
    
    private func showLivePhotosNotSupportedAlert() {
        let alertController = UIAlertController(
            title: "Live Photos",
            message: "Live Photos is not supported on this device.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            // 重置Live Photo状态
            self.cameraControlsView.updateLivePhotoStatus(false)
        }
        alertController.addAction(okAction)
        
        present(alertController, animated: true)
    }
}

// MARK: - Camera Bottom Controls View Delegate Methods
extension LMCameraPage: LMCameraBottomControlsViewDelegate {
    func cameraBottomControlsViewDidTapARGuidanceButton() {
        print("AR Guidance button tapped")
        let isEnabled = cameraBottomControlsView.getCurrentARGuidanceStatus()
        configureARGuidanceFeatures(isEnabled)
    }
    
    private func configureARGuidanceFeatures(_ enabled: Bool) {
        if enabled {
            print("AR Guidance features enabled")
            // 启用AR引导功能：人物检测、构图建议等
            startARGuidanceSession()
        } else {
            print("AR Guidance features disabled")
            // 禁用AR引导功能
            stopARGuidanceSession()
        }
    }
    
    private func startARGuidanceSession() {
        // 这里可以启动AR引导相关的功能
        // 例如：人脸检测、构图分析等
        print("Starting AR guidance session...")
    }
    
    private func stopARGuidanceSession() {
        // 停止AR引导功能
        print("Stopping AR guidance session...")
    }
    
    
    func cameraBottomControlsViewDidTapInspireButton() {
        print("Inspire button tapped")
        handleInspireMeFeature()
    }
    
    func cameraBottomControlsViewDidTapCaptureButton() {
        print("Capture button tapped")
        
        let timerDuration = cameraControlsView.getCurrentTimerDuration().seconds
        
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
    
    // 注意：这个方法已经被移除，因为底部控件现在使用AR Guidance而不是Premium Mode
    // func cameraBottomControlsViewDidTogglePremiumMode(_ enabled: Bool) {
    //     print("Premium mode toggled: \(enabled)")
    //     configurePremiumModeFeatures(enabled)
    // }
    
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
    
    // 移除了Premium Mode相关的方法，因为现在使用AR Guidance
    // private func configurePremiumModeFeatures(_ enabled: Bool) { ... }
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
    
    func setARGuidanceConfiguration(_ enabled: Bool) {
        cameraBottomControlsView.setARGuidanceEnabled(enabled)
    }
    
    func syncCameraControlsWithState() {
        // 同步相机控件状态，例如在切换不同相机模式时
        let currentFlashMode: LMFlashMode = .auto
        let currentRatio: LMAspectRatio = .ratio3_4
        let currentTimer: LMTimerDuration = .off
        let livePhotoEnabled = false
        let gridEnabled = true
        
        cameraControlsView.syncWithCameraState(
            aspectRatio: currentRatio,
            flashMode: currentFlashMode,
            timerDuration: currentTimer,
            livePhotoEnabled: livePhotoEnabled,
            gridEnabled: gridEnabled
        )
    }
}
