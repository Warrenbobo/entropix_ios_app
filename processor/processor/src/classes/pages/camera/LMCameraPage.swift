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

struct LMCameraConstants {
    
    static let bottomControlsHeight: CGFloat = 90
    
    static let topStatusBarHeight: CGFloat = 44
    
    private init() {}
}

class LMCameraPage: LMPageWrapper {
    
    // MARK: - UI Components
    let topStatusBarView = UIView()
    let backButton = UIButton()
    
    var cameraPreviewView: LMCameraPreviewView!
    var cameraControlsView: LMCameraControlsView!
    var cameraBottomControlsView: LMCameraBottomControlsView!
    var inspireMeButtonView: LMInspireMeButtonView!
    
    // MARK: - Camera Properties
    var captureSession: AVCaptureSession?
    var currentCameraDevice: AVCaptureDevice?
    var photoOutput: AVCapturePhotoOutput?
    var videoDataOutput: AVCaptureVideoDataOutput?
    var isUsingFrontCamera = false
    
    // MARK: - Preview Canvas Properties
    var currentAspectRatio: LMAspectRatio = .ratio3_4
    var previewCanvasView: UIView!
    var previewCanvasHeightConstraint: Constraint? // 保存高度约束的引用
    
    // MARK: - Bottom Controls Properties
    var bottomControlsHeightConstraint: Constraint? // 保存底部控制栏高度约束
    
    // MARK: - Feature Flags
    var isInspireMeCapture = false
    var isARGuidanceActive = false
    var shouldCaptureNextFrame = false // 标志：是否应该捕获下一帧用于Inspire Me
    
    // MARK: - AR Guidance
    var personDetectionManager: LMPersonDetectionManager?
    var currentSuggestion: LMSuggestion?
    var lastARGuidanceProcessTime: TimeInterval? // 上次处理AR引导帧的时间戳
    
    // MARK: - Camera State
    enum CameraState {
        case normal              // 普通相机状态
        case inspireMeProcessing // Inspire Me 处理中
        case showingSuggestions  // 显示构图建议
        case compositionSelected // 已选择构图（AR 引导）
    }
    
    var currentCameraState: CameraState = .normal
    
    // MARK: - Show Suggestions Properties
    var suggestionsCarouselView: LMSuggestionsCarouselView?
    var suggestionsContainerView: UIView?
    var currentTaskId: String?
    var currentSuggestions: [LMCompositionSuggestion] = []
    var pollTimer: Timer?
    
    // MARK: - View Tags
    enum ViewTag: Int {
        case processingOverlay = 9999
        case arGuidanceFrame = 8888
        case arHintLabel = 8889
        case personDetectionFrame = 8890
        case arGuidanceLine = 8891 // 中点连线
        case suggestionsContainer = 8892 // Show Suggestions 容器
        case referenceImageView = 8893 // 参考图（左下角）
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
        setupInspireMeButtonComponent()
    }
    
    private func setupTopStatusBarComponents() {
        view.addSubview(topStatusBarView)
        topStatusBarView.addSubview(backButton)
        
        backButton.setImage(UIImage(named: "left_arrow_white"), for: .normal)
        backButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        backButton.addTarget(self, action: #selector(handleUserProfileButtonTapped), for: .touchUpInside)
    }
    
    private func setupCameraPreviewComponent() {
        previewCanvasView = UIView()
        previewCanvasView.backgroundColor = .black
        previewCanvasView.clipsToBounds = true
        
        view.addSubview(previewCanvasView)
        cameraPreviewView = LMCameraPreviewView()
        cameraPreviewView.delegate = self
        previewCanvasView.addSubview(cameraPreviewView)
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
    
    private func setupInspireMeButtonComponent() {
        inspireMeButtonView = LMInspireMeButtonView()
        inspireMeButtonView.delegate = self
        view.addSubview(inspireMeButtonView)
    }
    
    // MARK: - Layout
    private func configureLayoutConstraints() {
        topStatusBarView.snp.makeConstraints { make in
            make.top.equalTo(AppTheme.Screen.safeAreaTop)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(LMCameraConstants.topStatusBarHeight)
        }
        
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.bottom.equalToSuperview()
            make.width.equalTo(44)
        }
        
        cameraBottomControlsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            // 保存高度约束的引用
            self.bottomControlsHeightConstraint = make.height.equalTo(LMCameraConstants.bottomControlsHeight).constraint
        }
        inspireMeButtonView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(cameraBottomControlsView.snp.top).offset(-20)
            make.width.equalTo(240)
            make.height.equalTo(70)
        }
        
        setupInitialPreviewCanvasLayout()
        cameraPreviewView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        cameraControlsView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalTo(previewCanvasView)
            make.width.equalTo(80)
        }
    }
    
    /// 初始化预览画布布局（无动画，避免首次进入时抖动）
    private func setupInitialPreviewCanvasLayout() {
        let topOffset = AppTheme.Screen.safeAreaTop + LMCameraConstants.topStatusBarHeight
        let bottomOffset = LMCameraConstants.bottomControlsHeight
        let availableHeight = AppTheme.Screen.height - topOffset - bottomOffset - AppTheme.Screen.safeAreaBottom
        let screenWidth = AppTheme.Screen.width
        
        // 默认3:4比例
        let canvasWidth = screenWidth
        var canvasHeight = canvasWidth * 4.0 / 3.0
        
        if canvasHeight > availableHeight {
            canvasHeight = availableHeight
        }
        
        previewCanvasView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalTo(topStatusBarView.snp.bottom).offset(availableHeight / 2)
            // 保存高度约束的引用，以便后续更新
            self.previewCanvasHeightConstraint = make.height.equalTo(canvasHeight).constraint
        }
        
        LMLogger.log("📐 Initial canvas setup - Size: \(canvasWidth)x\(canvasHeight)")
    }
    
    // MARK: - Preview Canvas Management
    
    /// 更新预览画布的宽高比（带动画）
    /// 以屏幕宽度为参照，只调整画布高度
    func updatePreviewCanvasAspectRatio(_ ratio: LMAspectRatio, animated: Bool = true) {
        // 如果比例没有变化，不需要更新
        guard ratio != currentAspectRatio else {
            LMLogger.log("📐 Aspect ratio unchanged, skipping update")
            return
        }
        
        currentAspectRatio = ratio
        
        // 计算可用空间
        let topOffset = AppTheme.Screen.safeAreaTop + LMCameraConstants.topStatusBarHeight
        let bottomOffset = LMCameraConstants.bottomControlsHeight
        let availableHeight = AppTheme.Screen.height - topOffset - bottomOffset - AppTheme.Screen.safeAreaBottom
        let screenWidth = AppTheme.Screen.width
        
        LMLogger.log("📐 Available space - Width: \(screenWidth), Height: \(availableHeight)")
        
        // 计算新的画布高度
        let canvasWidth = screenWidth
        var canvasHeight: CGFloat
        switch ratio {
        case .ratio3_4:
            canvasHeight = canvasWidth * 4.0 / 3.0
        case .ratio1_1:
            canvasHeight = canvasWidth
        case .ratio9_16:
            canvasHeight = canvasWidth * 16.0 / 9.0
        }
        
        // 限制最大高度
        if canvasHeight > availableHeight {
            canvasHeight = availableHeight
            LMLogger.log("⚠️ Canvas height capped to available height: \(availableHeight)")
        }
        
        // 更新高度约束（不移除其他约束，避免抖动）
        previewCanvasHeightConstraint?.update(offset: canvasHeight)
        
        // 根据参数决定是否使用动画
        if animated {
            // 使用弹簧动画，提供更平滑的过渡效果
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0.5,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: {
                    self.view.layoutIfNeeded()
                },
                completion: nil
            )
        } else {
            view.layoutIfNeeded()
        }
        
        LMLogger.log("📐 Updated preview canvas to \(ratio.displayName) - Canvas size: \(canvasWidth)x\(canvasHeight)")
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
            setupCameraSession()
            setDefaultCameraParameters()
            startCameraSession()
            LMLogger.log("✅ Camera permission already granted")
            
        case .notDetermined:
            LMLogger.log("📱 Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        LMLogger.log("✅ Camera permission granted by user")
                        self?.setupCameraSession()
                        self?.setDefaultCameraParameters()
                        self?.startCameraSession()
                    } else {
                        LMLogger.log("❌ Camera permission denied by user")
                        self?.handlePermissionDenied()
                    }
                }
            }
            
        case .denied, .restricted:
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
        
        // 根据当前状态决定返回行为
        switch currentCameraState {
        case .showingSuggestions:
            showLeaveConfirmation { [weak self] shouldLeave in
                if shouldLeave {
                    self?.exitShowSuggestionsState()
                    self?.navigateBack()
                }
            }
            
        case .compositionSelected:
            showLeaveCompositionConfirmation { [weak self] shouldLeave in
                if shouldLeave {
                    // TODO: 退出 Composition Selected 状态
                    self?.navigateBack()
                }
            }
            
        default:
            navigateBack()
        }
    }
    
    // MARK: - Navigation
    private func navigateBack() {
        navigationController?.popViewController(animated: true)
    }
}

