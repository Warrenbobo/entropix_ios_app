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
import CoreMotion

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
    /// Inspire Me 点击瞬间的设备方向（用于把取到的帧统一旋转成“home键在下方”的竖屏图）
    var inspireMeCaptureDeviceOrientation: UIDeviceOrientation?
    
    // MARK: - AR Guidance (New Architecture)
    var arGuidanceView: LMARGuidanceView!
    var livePersonBox: UIView! // 蓝色校准框（独立于arGuidanceView，不跟随旋转）
    var guidanceLine: CAShapeLayer! // 引导线（在previewCanvasView.layer上，连接白色框和蓝色框）
    var referenceImageDetectionManager: LMReferenceImageDetectionManager!
    var cameraStreamDetectionManager: LMCameraStreamDetectionManager!
    var arGuidanceState: LMARGuidanceState = .disabled {
        didSet {
            handleARGuidanceStateChange(from: oldValue, to: arGuidanceState)
        }
    }
    var currentReferenceImage: UIImage?
    var currentReferenceBbox: CGRect?
    var referenceImageInitialOrientation: UIDeviceOrientation? // 保存referenceImage的初始方向
    var isCurrentlyAligned: Bool = false // 当前是否处于对齐状态
    var lastLiveBoxBounds: CGRect? // 保存最后的蓝框位置，用于从对齐状态恢复
    var arGuidanceStartTime: Date? // AR引导开始时间，用于延迟显示蓝框
    
    // MARK: - AR Guidance (Legacy - 保留兼容)
    var personDetectionManager: LMPersonDetectionManager?
    var currentSuggestion: LMCompositionSuggestion?
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
    var currentTaskId: String?
    var currentSuggestions: [LMCompositionSuggestion] = []
    var isPolling: Bool = false // 标志：是否正在执行轮询请求
    
    // MARK: - Reference Image Properties
    var referenceImageContainerView: UIView? // 持久化的参考图容器
    var referenceImageView: UIImageView? // 参考图
    var referenceCloseButton: UIButton? // 关闭按钮
    
    // MARK: - Navigation Source Tracking
    enum NavigationSource {
        case normal              // 从普通入口进入（Menu Bar）
        case savedIdea(GalleryItem) // 从 Saved Idea Detail 的 Go Shot 进入
    }
    var navigationSource: NavigationSource = .normal
    
    // MARK: - View Tags
    enum ViewTag: Int {
        case processingOverlay = 9999
        case arGuidanceFrame = 8888
        case arHintLabel = 8889
    }
    
    // MARK: - Initialization
    
    /// 便利初始化方法：从 Saved Idea 进入
    convenience init(fromSavedIdea item: GalleryItem) {
        self.init()
        self.navigationSource = .savedIdea(item)
        LMLogger.log("📸 Camera initialized from Saved Idea: \(item.id)")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCameraPageComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        
        // 初始化AR引导功能（必须在相机设置之前）
        setupARGuidance()
        
        // 初始化引导视图
        setupGuideView()
        
        checkCameraPermissionAndSetup()
        
        // 确保视图层级正确
        ensureCorrectViewHierarchy()
        
        // 如果是从 Saved Idea 进入，自动进入 Composition Selected 状态
        handleNavigationSource()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        
        // 启动设备方向检测
        LMDeviceOrientationManager.shared.startMonitoring()
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized {
            startCameraSession()
            
            // 注意：首次进入时的引导显示在 checkCameraPermissionAndSetup 中处理
            // 这里只处理从其他页面返回的情况（viewWillAppear 会被多次调用）
            // 引导的显示由 LMCameraGuideManager 控制，已显示过的不会重复显示
        }
        // 如果当前处于 compositionSelected 状态（有参考图），延迟1秒后恢复 AR 引导 UI
        if arGuidanceState == .paused {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.arGuidanceState = .activeGuidance
                LMLogger.log("🎯 Resuming AR guidance UI after preview return (already in activeGuidance)")
            }
            LMLogger.log("📸 Returning to camera with reference image")
            LMLogger.log("📸 Current reference image exists: \(currentReferenceImage != nil)")
            LMLogger.log("📸 AR button state: \(cameraBottomControlsView.isARGuidanceActive())")
            LMLogger.log("📸 isARGuidanceActive: \(isARGuidanceActive)")
            LMLogger.log("📸 arGuidanceState: \(arGuidanceState)")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCameraSession()
        
        // 只是临时暂停 AR 引导，不完全清理（用户可能从预览页返回）
        pauseARGuidance()
        
        // 停止设备方向检测
        LMDeviceOrientationManager.shared.stopMonitoring()
    }
    
    deinit {
        // 页面真正销毁时，完全清理 AR 引导资源
        fullCleanupARGuidance()
        LMLogger.log("🗑️ LMCameraPage deinit")
    }
    
    // MARK: - Setup
    private func setupCameraPageComponents() {
        setupTopStatusBarComponents()
        setupCameraPreviewComponent()
        setupCameraControlsComponent()
        setupCameraBottomControlsComponent()
        setupInspireMeButtonComponent()
        setupReferenceImageComponent() // 初始化参考图组件（长期持有，默认隐藏）
    }
    
    /// 确保视图层级正确
    /// 层级顺序（从下到上）：
    /// 1. previewCanvasView（相机画面）
    ///    - cameraPreviewView（对焦层，在previewCanvasView内部）
    ///    - arGuidanceView（AR白色/绿色校准框，在previewCanvasView内部）
    ///    - livePersonBox（AR蓝色校准框，独立于arGuidanceView，在previewCanvasView内部）
    /// 2. referenceImageContainerView（参考图，在主视图）
    /// 3. cameraControlsView（右侧按钮，始终最顶层）
    /// 4. guideView（引导视图，最顶层）
    func ensureCorrectViewHierarchy() {
        // 1. previewCanvasView 已经是最底层（在setupCameraPreviewComponent中添加）
        
        // 2. previewCanvasView 内部的视图层级
        if let arGuidanceView = arGuidanceView {
            // arGuidanceView 在 previewCanvasView 内部，确保在 cameraPreviewView 之上
            previewCanvasView.bringSubviewToFront(arGuidanceView)
        }
        
        // 蓝色框在 arGuidanceView 之上（因为蓝色框不跟随旋转，需要独立显示）
        if let livePersonBox = livePersonBox {
            previewCanvasView.bringSubviewToFront(livePersonBox)
        }
        
        // 3. 主视图层级
        // ✅ CRITICAL FIX: Suggestions Carousel 必须在 Reference Image 之下
        // 这样可以确保 Reference Image 关闭后，Carousel 的手势不会被遮挡
        if let suggestionsCarouselView = suggestionsCarouselView {
            view.bringSubviewToFront(suggestionsCarouselView)
        }
        
        // Reference Image Container（如果存在）
        if let referenceImageContainerView = referenceImageContainerView {
            view.bringSubviewToFront(referenceImageContainerView)
        }
        
        // Camera Controls View（右侧按钮，始终最顶层）
        view.bringSubviewToFront(cameraControlsView)
        
        // 其他顶层UI元素
        view.bringSubviewToFront(topStatusBarView)
        view.bringSubviewToFront(cameraBottomControlsView)
        view.bringSubviewToFront(inspireMeButtonView)
        
        // 引导视图（最顶层）
        bringGuideViewToFront()
        
        LMLogger.log("✅ 视图层级已调整：Preview(Camera + AR Guidance + LiveBox) → Suggestions Carousel → Reference Image → Controls → Guide")
    }
    
    private func setupTopStatusBarComponents() {
        view.addSubview(topStatusBarView)
        topStatusBarView.addSubview(backButton)
        
        backButton.setImage(UIImage(named: "left_arrow_white"), for: .normal)
        backButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 10)
        backButton.addTarget(self, action: #selector(handleGiveUpAndBackButtonTapped), for: .touchUpInside)
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
            make.bottom.equalTo(cameraBottomControlsView.snp.top).offset(-10)
            make.width.equalTo(130)
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
                completion: { [weak self] _ in
                    // 动画完成后更新 AR Guidance 位置
                    self?.updateARGuidanceForAspectRatioChange()
                }
            )
        } else {
            view.layoutIfNeeded()
            // 立即更新 AR Guidance 位置
            updateARGuidanceForAspectRatioChange()
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
            // 权限已授权，延迟显示引导（等待相机界面完全加载）
            showInspireMeGuideAfterCameraReady()
            
        case .notDetermined:
            LMLogger.log("📱 Requesting camera permission...")
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        LMLogger.log("✅ Camera permission granted by user")
                        self?.setupCameraSession()
                        self?.setDefaultCameraParameters()
                        self?.startCameraSession()
                        // 首次授权成功后，延迟显示引导（等待相机界面完全加载）
                        self?.showInspireMeGuideAfterCameraReady()
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
    
    /// 相机准备就绪后显示引导
    private func showInspireMeGuideAfterCameraReady() {
        // 延迟 0.5 秒，等待相机界面完全加载后再显示引导
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            // 只在普通状态下显示引导
            if self.currentCameraState == .normal {
                self.showInspireMeGuideIfNeeded()
            }
        }
    }
    
    /// 处理权限被拒绝的情况
    private func handlePermissionDenied() {
        LMAlertDialog.showAlert(title: LMText.camera.cameraAccessDenied,
                                message: LMText.camera.cameraAccessRequired,
                                confirmText: LMText.common.ok) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
    
    /// 显示前往设置的提示
    func showPermissionSettingsAlert() {
        LMAlertDialog.showAlert(
            title: LMText.camera.cameraAccessRequiredTitle,
            message: LMText.camera.cameraAccessRequiredMessage,
            cancelText: LMText.common.cancel,
            confirmText: LMText.common.openSettings,
            onConfirm: {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            },
            onCancel: { [weak self] in
                // 返回上一页
                self?.navigationController?.popViewController(animated: true)
            })
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
    @objc func handleGiveUpAndBackButtonTapped() {
        LMLogger.log("🔙 Back button tapped")
        
        // 根据当前状态决定返回行为
        switch currentCameraState {
        case .showingSuggestions:
            // 在 Show Suggestions 状态，点击返回需要确认是否退出
            showLeaveConfirmation { [weak self] shouldLeave in
                if shouldLeave {
                    self?.exitShowSuggestionsState()
                    self?.navigateBack()
                }
            }
            
        case .compositionSelected:
            // 隐藏 Step 3 和 Step 4 引导（用户点击返回按钮）
            hideCompositionSelectedGuides()
            
            // 判断导航来源
            switch navigationSource {
            case .savedIdea:
                // 从 Saved Idea 进入，点击返回应该返回到 Saved Idea Detail 页面
                navigateBack()
                LMLogger.log("🔙 Returned to Saved Idea Detail from Composition Selected")
                
            case .normal:
                // 从 Show Suggestions 进入，点击返回应该返回到 Show Suggestions 列表
                closeReferenceImage()
                LMLogger.log("🔙 Returned to Show Suggestions from Composition Selected")
            }
            
        default:
            navigateBack()
        }
    }
    
    // MARK: - Navigation Source Handling
    
    /// 处理导航来源，自动进入对应状态
    private func handleNavigationSource() {
        switch navigationSource {
        case .savedIdea(let item):
            // 从 Saved Idea 进入，自动进入 Composition Selected 状态
            // 延迟执行，确保相机会话已启动
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.enterCompositionSelectedStateFromSavedIdea(item: item)
            }
            
        case .normal:
            // 正常进入，不做特殊处理
            break
        }
    }
    
    // MARK: - Navigation
    func navigateBack() {
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Confirmation Dialogs
extension LMCameraPage {
    
    /// 显示离开 Show Suggestions 确认对话框
    func showLeaveConfirmation(completion: @escaping (Bool) -> Void) {
        let config = LMAlertDialogConfig(
            image: UIImage(named: "exclamation_triangle_orange"),
            title: LMText.camera.giveUpInspires,
            message: LMText.camera.giveUpInspiresMessage,
            cancelButtonText: LMText.common.cancel,
            confirmButtonText: LMText.common.leave,
            confirmButtonStyle: .destructive,
            onCancel: { completion(false) },
            onConfirm: { completion(true) }
        )
        let customDialog = LMAlertDialog(config: config)
        customDialog.show()
    }
}
