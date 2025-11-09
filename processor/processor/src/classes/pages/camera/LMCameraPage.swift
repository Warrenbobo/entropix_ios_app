//
//  LMCameraPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import AVFoundation
import SnapKit
import MetalPerformanceShaders
import CoreML

class LMCameraPage: LMPageWrapper {
    
    // MARK: - UI Components
    let topStatusBarView = UIView()
    let backButton = UIButton()
    
    var cameraPreviewView: LMCameraPreviewView!
    var cameraControlsView: LMCameraControlsView!
    var cameraBottomControlsView: LMCameraBottomControlsView!
    
    // MARK: - Camera Properties
    var captureSession: AVCaptureSession?
    var currentCameraDevice: AVCaptureDevice?
    var photoOutput: AVCapturePhotoOutput?
    var videoDataOutput: AVCaptureVideoDataOutput?
    var isUsingFrontCamera = false
    
    // MARK: - Feature Flags
    var isInspireMeCapture = false
    var isARGuidanceActive = false
    
    // MARK: - AR Guidance
    var personDetectionManager: LMPersonDetectionManager?
    var currentSuggestion: LMSuggestion?
    
    // MARK: - View Tags
    enum ViewTag: Int {
        case processingOverlay = 9999
        case arGuidanceFrame = 8888
        case arHintLabel = 8889
        case personDetectionFrame = 8890
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraPageComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        checkCameraPermissionAndSetup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        // 只有在已授权的情况下才启动相机会话
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            startCameraSession()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCameraSession()
    }
    
    // MARK: - Setup
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
        backButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
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
    
    // MARK: - Layout
    private func configureLayoutConstraints() {
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
        
        cameraPreviewView.snp.makeConstraints { make in
            make.top.equalTo(topStatusBarView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(cameraBottomControlsView.snp.top)
        }
        
        cameraControlsView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalTo(cameraPreviewView)
            make.width.equalTo(80)
        }
        
        cameraBottomControlsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(120)
        }
    }
    
    // MARK: - Styling
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = UIColor.black
        
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .dark
        }
    }
    
    // MARK: - Permissions
    
    /// 检查相机权限并设置
    private func checkCameraPermissionAndSetup() {
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthStatus {
        case .authorized:
            // 已授权，直接设置相机
            setupCameraSession()
            setDefaultCameraParameters()
            startCameraSession()
            LMLogger.log("✅ Camera permission already granted")
            
        case .notDetermined:
            // 首次请求权限
            LMLogger.log("📱 Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        LMLogger.log("✅ Camera permission granted by user")
                        // 用户同意授权，设置并启动相机避免黑屏
                        self?.setupCameraSession()
                        self?.setDefaultCameraParameters()
                        self?.startCameraSession()
                    } else {
                        LMLogger.log("❌ Camera permission denied by user")
                        // 用户拒绝授权，返回上一页
                        self?.handlePermissionDenied()
                    }
                }
            }
            
        case .denied, .restricted:
            // 权限被拒绝或受限，提示用户前往设置
            LMLogger.log("❌ Camera permission denied or restricted")
            showPermissionSettingsAlert()
            
        @unknown default:
            LMLogger.log("⚠️ Unknown camera permission status")
            showPermissionSettingsAlert()
        }
    }
    
    /// 处理权限被拒绝的情况
    private func handlePermissionDenied() {
        let alert = UIAlertController(
            title: "Camera Access Denied",
            message: "Camera access is required to use this feature.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            // 返回上一页
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    /// 显示前往设置的提示
    func showPermissionSettingsAlert() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "FramAist needs camera access to take photos. Please enable camera access in Settings.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            // 返回上一页
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    /// 公开方法：检查相机权限状态（供外部调用）
    static func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            completion(true)
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
            
        case .denied, .restricted:
            completion(false)
            
        @unknown default:
            completion(false)
        }
    }
    

    
    // MARK: - Actions
    @objc func handleUserProfileButtonTapped() {
        LMLogger.log("🔙 Back button tapped")
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Utilities
    func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

