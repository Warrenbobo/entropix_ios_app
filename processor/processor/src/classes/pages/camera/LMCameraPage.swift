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
        startCameraSession()
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
    private func checkCameraPermissionAndSetup() {
        let cameraAuthStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch cameraAuthStatus {
        case .authorized:
            setupCameraSession()
            setDefaultCameraParameters()
            LMLogger.log("✅ Camera permission already granted")
            
        case .notDetermined:
            LMLogger.log("📱 Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        LMLogger.log("✅ Camera permission granted")
                        self?.setupCameraSession()
                        self?.setDefaultCameraParameters()
                    } else {
                        LMLogger.log("❌ Camera permission denied by user")
                        self?.showCameraPermissionDeniedAlert()
                    }
                }
            }
            
        case .denied, .restricted:
            LMLogger.log("❌ Camera permission denied or restricted")
            showCameraPermissionDeniedAlert()
            
        @unknown default:
            LMLogger.log("⚠️ Unknown camera permission status")
            showCameraPermissionDeniedAlert()
        }
    }
    
    private func showCameraPermissionDeniedAlert() {
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
            self?.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    func handleCameraPermissionDenied(status: AVAuthorizationStatus) {
        var message: String
        var showSettings = false
        
        switch status {
        case .notDetermined:
            message = "Camera permission not requested yet. Please restart the app."
        case .restricted:
            message = "Camera access is restricted. This may be due to parental controls or device management."
        case .denied:
            message = "Camera permission denied. Please enable camera access in Settings to take photos."
            showSettings = true
        case .authorized:
            message = "Camera permission granted but capture failed."
        @unknown default:
            message = "Unknown camera permission status."
        }
        
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: message,
            preferredStyle: .alert
        )
        
        if showSettings {
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            })
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        
        present(alert, animated: true)
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

