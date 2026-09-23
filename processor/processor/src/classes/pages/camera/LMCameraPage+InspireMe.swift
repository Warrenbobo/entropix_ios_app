//
//  LMCameraPage+InspireMe.swift
//  processor
//
//  Inspire Me feature implementation
//

import UIKit
import CoreML
import AVFoundation
import CoreImage

private enum LMProcessingOverlayViewTag {
    static let sceneryImageView = 10_001
    static let blurImageView = 10_002
    static let dimmingView = 10_003
    static let spinnerView = 10_004
    static let label = 10_005
}

private final class LMProcessingSpinnerView: UIView {

    private let trackLayer = CAShapeLayer()
    private let indicatorLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear

        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        trackLayer.lineWidth = 4
        layer.addSublayer(trackLayer)

        indicatorLayer.fillColor = UIColor.clear.cgColor
        indicatorLayer.strokeColor = UIColor.white.cgColor
        indicatorLayer.lineWidth = 4
        indicatorLayer.lineCap = .round
        indicatorLayer.strokeStart = 0.0
        indicatorLayer.strokeEnd = 0.24
        layer.addSublayer(indicatorLayer)

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = Double.pi * 2
        rotation.duration = 1.0
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        layer.add(rotation, forKey: "lm.processing.spinner.rotation")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let inset: CGFloat = 2
        let path = UIBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset)).cgPath
        trackLayer.frame = bounds
        trackLayer.path = path

        indicatorLayer.frame = bounds
        indicatorLayer.path = path
    }
}

#if DEBUG
private extension LMProcessingSpinnerView {
    var debugStrokeWidth: CGFloat {
        indicatorLayer.lineWidth
    }
}

struct LMProcessingRuntimeSnapshot {
    let overlayVisible: Bool
    let sceneryImageVisible: Bool
    let blurImageVisible: Bool
    let dimmingAlpha: CGFloat
    let spinnerSize: CGSize
    let spinnerStrokeWidth: CGFloat
    let labelText: String
    let labelFontSize: CGFloat
    let labelKerning: CGFloat
    let overlayFrame: CGRect
    let previewCanvasFrame: CGRect
}
#endif

// MARK: - Inspire Me Feature
extension LMCameraPage {
    
    /// 验证相机状态是否可以使用 Inspire Me 功能
    private func validateCameraState() -> Bool {
        // NORMAL Get Template or Path B Go-to-Spot shutter.
        switch currentCameraState {
        case .normal, .exploreGoToSpot:
            break
        default:
            LMLogger.log("⚠️ Cannot use Inspire Me - current state is \(currentCameraState)")
            return false
        }
        
        // 检查是否正在使用后置摄像头
        guard !isUsingFrontCamera else {
            LMLogger.log("⚠️ Cannot use Inspire Me with front camera")
            AppTheme.Toast.showText(LMText.camera.inspireMeOnlyBackCamera)
            return false
        }
        
        // 检查相机会话是否正在运行
        let isCaptureSessionRunning: Bool
#if DEBUG
        if debugShouldTreatInspireMeCaptureSessionAsRunning {
            isCaptureSessionRunning = true
        } else {
            isCaptureSessionRunning = captureSession?.isRunning == true
        }
#else
        isCaptureSessionRunning = captureSession?.isRunning == true
#endif

        guard isCaptureSessionRunning else {
            LMLogger.log("⚠️ Camera session is not running")
            AppTheme.Toast.showText(LMText.camera.cameraNotReady)
            return false
        }
        
        // 检查是否已经在处理中
        guard !isInspireMeCapture else {
            LMLogger.log("⚠️ Inspire Me is already processing")
            return false
        }
        
        return true
    }
    
    func handleInspireMeFeature() {
        LMLogger.log("🎯 Starting Inspire Me feature...")
        
        // 隐藏 Step 1 引导（用户点击了 Inspire Me 按钮）
        hideInspireMeGuide()
        
        // FRAMAIST_BACKEND_DISABLED — no FramAist login gate for Inspire Me.
        /*
        if !LMFeatureFlagsManager.inspireMeDirectGeminiEnabled {
            guard requireLogin(action: "use Inspire Me feature") else {
                return
            }
        }
        */
        
        guard validateCameraState() else {
            return
        }

        isInspireMeCapture = true
        pendingInspireSpot = nil
        inspireTapDate = Date()
        LMLogger.log("inspire.tap mode=FREE_COMPOSITION")

        // 记录点击瞬间的设备方向（后续用于把帧旋转到竖屏“home键在下方”的预览样式）
        inspireMeCaptureDeviceOrientation = LMOrientationMatcher.orientationForCapture()

        if captureCurrentPreviewFrameAndStartProcessing() {
            LMLogger.log("📸 Inspire Me froze the current preview frame immediately")
        } else {
            captureFrameFromVideoStream()
            LMLogger.log("📸 Inspire Me fallback: waiting for next video frame")
        }
    }
    
    /// 从视频流中捕获当前帧
    private func captureFrameFromVideoStream() {
        // 设置标志，让视频流代理捕获下一帧
        shouldCaptureNextFrame = true
    }

    @discardableResult
    private func captureCurrentPreviewFrameAndStartProcessing() -> Bool {
        guard let image = makeInspireMeImageFromLatestPreviewFrame() else {
            return false
        }

        // Direct Gemini: skip long Inspiring freeze — placeholders appear ASAP in processAndGenerateDirectGemini.
        if !LMFeatureFlagsManager.inspireMeDirectGeminiEnabled {
            showProcessingOverlay(with: image)
        }
        processInspireMeImage(image)
        inspireMeCaptureDeviceOrientation = nil
        return true
    }

    func cacheLatestPreviewPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
        previewFrameAccessQueue.sync {
            latestPreviewPixelBuffer = pixelBuffer
        }
    }

    func clearLatestPreviewPixelBuffer() {
        previewFrameAccessQueue.sync {
            latestPreviewPixelBuffer = nil
        }
    }

    func makeInspireMeImage(
        from pixelBuffer: CVPixelBuffer,
        deviceOrientation: UIDeviceOrientation
    ) -> UIImage? {
        LMPreviewFramePipeline.makeUIImage(
            from: pixelBuffer,
            orientationPolicy: .locked(deviceOrientation),
            isFrontCamera: isUsingFrontCamera
        )
    }

    private func makeInspireMeImageFromLatestPreviewFrame() -> UIImage? {
        let latestPixelBuffer = previewFrameAccessQueue.sync { latestPreviewPixelBuffer }
        guard let latestPixelBuffer else {
            return nil
        }

        let deviceOrientation = inspireMeCaptureDeviceOrientation ?? LMOrientationMatcher.orientationForCapture()
        return makeInspireMeImage(from: latestPixelBuffer, deviceOrientation: deviceOrientation)
    }
    
    func processInspireMeImage(_ image: UIImage) {
        LMLogger.log("📸 Processing Inspire Me image...")
        let deviceOrientation = inspireMeCaptureDeviceOrientation ?? LMOrientationMatcher.orientationForCapture()
        LMAgentRequestLogRecorder.recordInspireMeFrame(
            image,
            orientationNote: "Inspire Me capture — deviceOrientation=\(deviceOrientation.rawValue), UIImage.orientation=\(image.imageOrientation.rawValue)"
        )
        currentProcessingSceneryImage = image
        syncInspirePointsToBackend()

        // Prefer BYOK Gemini even when Backend API flag is off (no FramAist session).
        if LMFeatureFlagsManager.inspireMeDirectGeminiEnabled {
            processDirectGeminiInspireMe(image)
            return
        }

        // Offline demo when Direct Gemini is off (FramAist upload path commented below).
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = self?.analyzeSceneWithFastVLM(image)
            self?.finishOfflineInspireMe()
        }
        // FRAMAIST_BACKEND_DISABLED — FramAist /analyze upload unreachable.
        /*
        if !LMFeatureFlagsManager.backendApiEnabled {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                _ = self?.analyzeSceneWithFastVLM(image)
                self?.finishOfflineInspireMe()
            }
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let sceneFeature = self.analyzeSceneWithFastVLM(image)
            self.processAndUploadImage(image, sceneFeature: sceneFeature)
        }
        */
    }

    /// Gates + starts the device → Gemini Inspire Me path (no EVA02 /analyze).
    private func processDirectGeminiInspireMe(_ image: UIImage) {
        guard LMGeminiModelSettingsStore.isConfigured else {
            DispatchQueue.main.async { [weak self] in
                self?.finishInspireProcessingFailed()
                AppTheme.Toast.showText(LMText.camera.geminiModelsNotConfigured)
            }
            return
        }
        guard LMLlmCallQuotaStore.hasRemaining(for: .ideaInspiration) else {
            DispatchQueue.main.async { [weak self] in
                self?.finishInspireProcessingFailed()
                self?.presentMissingModelConfig(for: .ideaInspiration)
            }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.processAndGenerateDirectGemini(image)
        }
    }
    
    func syncInspirePointsToBackend() {
        // FRAMAIST_BACKEND_DISABLED — no inspire-points sync / decrement.
        /*
        guard LMFeatureFlagsManager.backendApiEnabled,
              !LMFeatureFlagsManager.inspireMeDirectGeminiEnabled else { return }
        let subscriptionStatus = LMStoreManager.shared.currentSubscriptionStatus
        
        if subscriptionStatus == .free {
            LMLogger.log("📉 Decrementing Inspire Points for Free Plan user")
            preShootPlanButtonView.decrementInspirePointsCount()
        }
        */
    }
    
    func getUserInspirePoints() -> Int {
        return preShootPlanButtonView.getCurrentInspirePoints()
    }
    
    func showInsufficientPointsAlert() {
        // First show the main alert
        let config = LMAlertDialogConfig(
            title: LMText.camera.outOfInspirePoints,
            message: LMText.camera.subscribeOrWatchAds,
            cancelButtonText: LMText.common.cancel,
            confirmButtonText: LMText.profile.watchAds,
            confirmButtonStyle: .normal,
            onConfirm: { [weak self] in
                self?.navigateToProfile()
            }
        )
        let dialog = LMAlertDialog(config: config)
        
        // Add a custom action sheet for multiple options
        // For now, we'll use the simpler two-button approach
        // TODO: Consider creating a custom action sheet component for 3+ options
        dialog.show()
    }
    
    func navigateToProfile() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    func navigateToSubscription() {
        navigationController?.pushViewController(LMSubscriptionPage(), animated: true)
    }
}

// MARK: - Processing Overlay
extension LMCameraPage {

    private func makeProcessingBlurredImage(from image: UIImage?) -> UIImage? {
        guard let image else { return nil }

        let normalizedImage = image.lmNormalizedImage()
        guard let ciImage = CIImage(image: normalizedImage) else {
            return normalizedImage
        }

        let clampedImage = ciImage.clampedToExtent()
        let blurredImage = clampedImage
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 8.0])
            .cropped(to: ciImage.extent)

        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(blurredImage, from: ciImage.extent) else {
            return normalizedImage
        }

        return UIImage(cgImage: cgImage, scale: normalizedImage.scale, orientation: .up)
    }
    
    func showProcessingOverlay() {
        showProcessingOverlay(with: currentProcessingSceneryImage)
    }

    /**
     Shows the freeze / blur processing mask.
     - Parameter setInspireProcessingState: When `true` (default), enters `.inspireMeProcessing`.
       Scene Explore processing must pass `false` and set `.sceneExploreProcessing` itself.
     */
    func showProcessingOverlay(with image: UIImage?, setInspireProcessingState: Bool = true) {
        hideProcessingOverlay(resetInspireState: false)

        currentProcessingSceneryImage = image
        if setInspireProcessingState {
            currentCameraState = .inspireMeProcessing
        }

        let overlayView = UIView()
        overlayView.backgroundColor = .clear
        overlayView.tag = ViewTag.processingOverlay.rawValue
        overlayView.isUserInteractionEnabled = false
        overlayView.clipsToBounds = true
        previewCanvasView.addSubview(overlayView)

        let sceneryImageView = UIImageView()
        sceneryImageView.contentMode = .scaleAspectFill
        sceneryImageView.clipsToBounds = true
        sceneryImageView.tag = LMProcessingOverlayViewTag.sceneryImageView
        sceneryImageView.image = currentProcessingSceneryImage
        overlayView.addSubview(sceneryImageView)

        let blurImageView = UIImageView()
        blurImageView.contentMode = .scaleAspectFill
        blurImageView.clipsToBounds = true
        blurImageView.tag = LMProcessingOverlayViewTag.blurImageView
        blurImageView.image = makeProcessingBlurredImage(from: currentProcessingSceneryImage)
        blurImageView.alpha = 0.8
        overlayView.addSubview(blurImageView)

        let dimmingView = UIView()
        dimmingView.backgroundColor = UIColor(
            red: 64.0 / 255.0,
            green: 64.0 / 255.0,
            blue: 64.0 / 255.0,
            alpha: 0.6
        )
        dimmingView.tag = LMProcessingOverlayViewTag.dimmingView
        overlayView.addSubview(dimmingView)

        let contentStackView = UIStackView()
        contentStackView.axis = .vertical
        contentStackView.alignment = .center
        contentStackView.distribution = .fill
        contentStackView.spacing = 16

        let spinner = LMProcessingSpinnerView()
        spinner.tag = LMProcessingOverlayViewTag.spinnerView

        let label = UILabel()
        label.tag = LMProcessingOverlayViewTag.label
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.layer.shadowColor = UIColor.black.withAlphaComponent(0.8).cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 2)
        label.layer.shadowRadius = 4
        label.layer.shadowOpacity = 1
        label.attributedText = NSAttributedString(
            string: LMText.camera.processingInspiring,
            attributes: [
                .kern: 0.5,
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 18, weight: .medium)
            ]
        )

        contentStackView.addArrangedSubview(spinner)
        contentStackView.addArrangedSubview(label)
        overlayView.addSubview(contentStackView)

        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        sceneryImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        blurImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        dimmingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        contentStackView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        spinner.snp.makeConstraints { make in
            make.width.height.equalTo(40)
        }

        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        overlayView.alpha = 0
        UIView.animate(withDuration: 0.2) {
            overlayView.alpha = 1
        }
    }
    
    func updateProcessingOverlaySceneryImage(_ image: UIImage) {
        currentProcessingSceneryImage = image
        guard let overlayView = previewCanvasView.viewWithTag(ViewTag.processingOverlay.rawValue),
              let sceneryImageView = overlayView.viewWithTag(LMProcessingOverlayViewTag.sceneryImageView) as? UIImageView,
              let blurImageView = overlayView.viewWithTag(LMProcessingOverlayViewTag.blurImageView) as? UIImageView else {
            return
        }
        sceneryImageView.image = image
        blurImageView.image = makeProcessingBlurredImage(from: image)
    }
    
    func hideProcessingOverlay(resetInspireState: Bool = true) {
        currentProcessingSceneryImage = nil
        if let overlayView = previewCanvasView.viewWithTag(ViewTag.processingOverlay.rawValue) {
            UIView.animate(withDuration: 0.2, animations: {
                overlayView.alpha = 0
            }) { _ in
                overlayView.removeFromSuperview()
                // Only clear Inspire processing → NORMAL. Do not auto-restore Explore (IP-06
                // is handled explicitly at failure call sites to avoid racing successful enter).
                if resetInspireState, self.currentCameraState == .inspireMeProcessing {
                    self.currentCameraState = .normal
                    self.applyPageStateChrome()
                }
            }
        } else if resetInspireState, currentCameraState == .inspireMeProcessing {
            currentCameraState = .normal
            applyPageStateChrome()
        }
    }

    /// IP-05 / IP-06: leave Inspire processing after a hard failure.
    func finishInspireProcessingFailed() {
        hideProcessingOverlay(resetInspireState: false)
        isInspireMeCapture = false
        if suggestionsBoundToExploreSession, exploreSession != nil {
            exitShowSuggestionsStateReturningToExplore()
        } else {
            currentCameraState = .normal
            applyPageStateChrome()
        }
    }
}

#if DEBUG
extension LMCameraPage {

    @MainActor
    func debugShowProcessingOverlay(with image: UIImage) {
        loadViewIfNeeded()
        view.layoutIfNeeded()
        currentCameraState = .inspireMeProcessing
        showProcessingOverlay(with: image)
        view.layoutIfNeeded()
    }

    @MainActor
    func debugHideProcessingOverlayForRuntimeHarness() {
        hideProcessingOverlay()
        view.layoutIfNeeded()
    }

    @MainActor
    func debugProcessingSnapshot() -> LMProcessingRuntimeSnapshot {
        loadViewIfNeeded()
        view.layoutIfNeeded()

        guard let overlayView = previewCanvasView.viewWithTag(ViewTag.processingOverlay.rawValue) else {
            return LMProcessingRuntimeSnapshot(
                overlayVisible: false,
                sceneryImageVisible: false,
                blurImageVisible: false,
                dimmingAlpha: 0,
                spinnerSize: .zero,
                spinnerStrokeWidth: 0,
                labelText: "",
                labelFontSize: 0,
                labelKerning: 0,
                overlayFrame: .zero,
                previewCanvasFrame: previewCanvasView.frame
            )
        }

        overlayView.layoutIfNeeded()

        let sceneryImageView = overlayView.viewWithTag(LMProcessingOverlayViewTag.sceneryImageView) as? UIImageView
        let blurImageView = overlayView.viewWithTag(LMProcessingOverlayViewTag.blurImageView) as? UIImageView
        let dimmingView = overlayView.viewWithTag(LMProcessingOverlayViewTag.dimmingView)
        let spinnerView = overlayView.viewWithTag(LMProcessingOverlayViewTag.spinnerView) as? LMProcessingSpinnerView
        let label = overlayView.viewWithTag(LMProcessingOverlayViewTag.label) as? UILabel
        let labelKerning = (label?.attributedText?.attribute(.kern, at: 0, effectiveRange: nil) as? CGFloat) ?? 0

        return LMProcessingRuntimeSnapshot(
            overlayVisible: overlayView.superview != nil && !overlayView.isHidden && overlayView.alpha > 0.01,
            sceneryImageVisible: (sceneryImageView?.image != nil) && !(sceneryImageView?.isHidden ?? true),
            blurImageVisible: (blurImageView?.image != nil) && !(blurImageView?.isHidden ?? true),
            dimmingAlpha: dimmingView?.backgroundColor?.cgColor.alpha ?? 0,
            spinnerSize: spinnerView?.bounds.size ?? .zero,
            spinnerStrokeWidth: spinnerView?.debugStrokeWidth ?? 0,
            labelText: label?.text ?? label?.attributedText?.string ?? "",
            labelFontSize: label?.font.pointSize ?? 0,
            labelKerning: labelKerning,
            overlayFrame: overlayView.frame,
            previewCanvasFrame: previewCanvasView.frame
        )
    }

    @MainActor
    func debugSaveVisibleProcessingSnapshot(named fileName: String) -> URL? {
        loadViewIfNeeded()
        view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }

        guard let data = image.pngData() else { return nil }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
#endif
