//
//  LMCameraPage+ARGuidance.swift
//  processor
//
//  AR Guidance feature implementation with orientation matching
//

import UIKit
import AVFoundation
import Vision

// MARK: - AR Guidance State

/// AR引导状态
enum LMARGuidanceState: Equatable {
    case disabled                          // 未启用（未进入 compositionSelected 状态）
    case waitingForReferenceDetection      // 等待Reference Image检测
    case referenceDetected(bbox: CGRect)   // Reference Image检测完成
    case activeGuidance                    // AR引导激活中
    case paused                            // 暂停状态（用户进入预览页等场景，保留所有状态以便恢复）
    case orientationMismatch               // 方向不匹配
    case error(Error)                      // 错误状态
    
    // 实现Equatable协议
    static func == (lhs: LMARGuidanceState, rhs: LMARGuidanceState) -> Bool {
        switch (lhs, rhs) {
        case (.disabled, .disabled):
            return true
        case (.waitingForReferenceDetection, .waitingForReferenceDetection):
            return true
        case (.referenceDetected(let bbox1), .referenceDetected(let bbox2)):
            return bbox1 == bbox2
        case (.activeGuidance, .activeGuidance):
            return true
        case (.paused, .paused):
            return true
        case (.orientationMismatch, .orientationMismatch):
            return true
        case (.error(let error1), .error(let error2)):
            return error1.localizedDescription == error2.localizedDescription
        default:
            return false
        }
    }
}

/// AR引导错误
enum LMARGuidanceError: Error {
    case noPersonDetected                  // 未检测到人物
    case multiplePersonsDetected           // 检测到多个人物
    case detectionFailed                   // 检测失败
    case orientationMismatch               // 方向不匹配
    
    var localizedDescription: String {
        switch self {
        case .noPersonDetected:
            return "No person detected in the reference image"
        case .multiplePersonsDetected:
            return "Multiple persons detected"
        case .detectionFailed:
            return "Person detection failed"
        case .orientationMismatch:
            return "Device orientation does not match reference image"
        }
    }
}

// MARK: - AR Guidance Extension
extension LMCameraPage {
    
    // MARK: - Setup
    
    /// 设置AR引导功能（在viewDidLoad中调用）
    func setupARGuidance() {
        // 创建AR引导视图（包含白色框、绿色框）
        if arGuidanceView == nil {
            arGuidanceView = LMARGuidanceView(frame: .zero)
            previewCanvasView.addSubview(arGuidanceView)
        }
        
        // 创建独立的蓝色框（不在arGuidanceView内，不跟随旋转）
        if livePersonBox == nil {
            livePersonBox = UIView()
            livePersonBox.backgroundColor = .clear
            livePersonBox.isHidden = true
            // 添加到previewCanvasView，在arGuidanceView之后（层级在上面）
            previewCanvasView.addSubview(livePersonBox)
            
            // 初始化蓝色框的尺寸和图层
            let liveSize = getLiveBoxDefaultSize()
            livePersonBox.bounds = CGRect(origin: .zero, size: liveSize)
            livePersonBox.center = CGPoint(x: -1000, y: -1000)
            createLiveBoxFrameLayers()
            
            LMLogger.log("🔵 [AR Guidance] 独立蓝色框已创建，尺寸: \(liveSize)")
        }
        
        // 创建引导线（在previewCanvasView的layer上，不在arGuidanceView内）
        if guidanceLine == nil {
            guidanceLine = CAShapeLayer()
            guidanceLine.strokeColor = UIColor.systemBlue.cgColor
            guidanceLine.lineWidth = 1.5
            guidanceLine.lineDashPattern = [6, 4]
            guidanceLine.fillColor = UIColor.clear.cgColor
            guidanceLine.isHidden = true
            // 添加到previewCanvasView的layer上
            previewCanvasView.layer.addSublayer(guidanceLine)
            
            LMLogger.log("📏 [AR Guidance] 引导线已创建在previewCanvasView.layer上")
        }
        
        // 创建检测管理器（每个管理器使用独立的 PersonDetectionManager 实例）
        if referenceImageDetectionManager == nil {
            let referenceDetector = LMPersonDetectionManager()
            referenceImageDetectionManager = LMReferenceImageDetectionManager(personDetectionManager: referenceDetector)
        }
        
        if cameraStreamDetectionManager == nil {
            let streamDetector = LMPersonDetectionManager()
            cameraStreamDetectionManager = LMCameraStreamDetectionManager(personDetectionManager: streamDetector)
            
            // 设置检测结果回调
            cameraStreamDetectionManager.onDetectionResult = { [weak self] bbox, confidence in
                self?.handleRealtimeDetectionResult(bbox: bbox, confidence: confidence)
            }
        }
        
        // 监听设备方向变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: .devicePhysicalOrientationDidChange,
            object: nil
        )
    }
    
    // MARK: - Live Box (蓝色框) Helper Methods
    
    /// 获取蓝色框默认尺寸
    private func getLiveBoxDefaultSize() -> CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let width = screenWidth * 2.0 / 5.0
        let height = width * 1.1
        return CGSize(width: width, height: height)
    }
    
    /// 框的最小尺寸（防止圆角重叠）
    private var liveBoxMinimumSize: CGFloat { 60 }
    
    /// 创建蓝色框的图层
    private func createLiveBoxFrameLayers() {
        guard let livePersonBox = livePersonBox else { return }
        
        // 清除之前的图层
        livePersonBox.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        let bounds = livePersonBox.bounds
        let color = UIColor.systemBlue
        let lineWidth: CGFloat = 2.0
        let crosshairLength: CGFloat = 6
        let crosshairWidth: CGFloat = 2
        
        // 1. 创建并设置四个圆角图层（仅描边，不填充）
        let cornerLayer = CAShapeLayer()
        cornerLayer.name = "cornerLayer"
        cornerLayer.fillColor = UIColor.clear.cgColor
        cornerLayer.strokeColor = color.withAlphaComponent(0.9).cgColor
        cornerLayer.lineWidth = lineWidth
        cornerLayer.path = createCornerPath(in: bounds).cgPath
        livePersonBox.layer.addSublayer(cornerLayer)
        
        // 2. 创建并设置中心准星图层（实心填充）
        let crosshairLayer = CAShapeLayer()
        crosshairLayer.name = "crosshairLayer"
        crosshairLayer.fillColor = color.cgColor
        crosshairLayer.strokeColor = UIColor.clear.cgColor
        crosshairLayer.path = createCrosshairPath(in: bounds, length: crosshairLength, width: crosshairWidth).cgPath
        livePersonBox.layer.addSublayer(crosshairLayer)
    }
    
    /// 创建四个圆角路径
    private func createCornerPath(in bounds: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        let cornerLength: CGFloat = 24
        let cornerRadius: CGFloat = 18
        
        // 左上角
        path.move(to: CGPoint(x: 0, y: cornerLength))
        path.addArc(withCenter: CGPoint(x: cornerRadius, y: cornerRadius),
                    radius: cornerRadius, startAngle: .pi, endAngle: .pi * 1.5, clockwise: true)
        path.addLine(to: CGPoint(x: cornerLength, y: 0))
        
        // 右上角
        path.move(to: CGPoint(x: bounds.width - cornerLength, y: 0))
        path.addArc(withCenter: CGPoint(x: bounds.width - cornerRadius, y: cornerRadius),
                    radius: cornerRadius, startAngle: .pi * 1.5, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: bounds.width, y: cornerLength))
        
        // 右下角
        path.move(to: CGPoint(x: bounds.width, y: bounds.height - cornerLength))
        path.addArc(withCenter: CGPoint(x: bounds.width - cornerRadius, y: bounds.height - cornerRadius),
                    radius: cornerRadius, startAngle: 0, endAngle: .pi * 0.5, clockwise: true)
        path.addLine(to: CGPoint(x: bounds.width - cornerLength, y: bounds.height))
        
        // 左下角
        path.move(to: CGPoint(x: cornerLength, y: bounds.height))
        path.addArc(withCenter: CGPoint(x: cornerRadius, y: bounds.height - cornerRadius),
                    radius: cornerRadius, startAngle: .pi * 0.5, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: bounds.height - cornerLength))
        
        return path
    }
    
    /// 创建十字准星路径
    private func createCrosshairPath(in bounds: CGRect, length: CGFloat, width: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2
        
        // 水平线
        path.append(UIBezierPath(rect: CGRect(x: centerX - length, y: centerY - width / 2, width: length * 2, height: width)))
        // 垂直线
        path.append(UIBezierPath(rect: CGRect(x: centerX - width / 2, y: centerY - length, width: width, height: length * 2)))
        
        return path
    }
    
    /// 设置蓝色框的bounds
    func setLiveBoxBounds(bbox: CGRect) {
        guard let livePersonBox = livePersonBox else { return }
        
        // 应用最小尺寸限制
        let constrainedWidth = max(bbox.size.width, liveBoxMinimumSize)
        let constrainedHeight = max(bbox.size.height, liveBoxMinimumSize)
        let constrainedSize = CGSize(width: constrainedWidth, height: constrainedHeight)
        
        // 设置新的 bounds 和 center
        livePersonBox.bounds = CGRect(origin: .zero, size: constrainedSize)
        livePersonBox.center = CGPoint(x: bbox.midX, y: bbox.midY)
        livePersonBox.transform = .identity
        
        // 重新创建图层
        createLiveBoxFrameLayers()
        
        // 更新引导线
        updateGuidanceLineForLiveBox()
        
        LMLogger.log("🔵 [Live Box] 设置 bbox - size: \(constrainedSize), center: (\(bbox.midX), \(bbox.midY))")
    }
    
    /// 更新蓝色框的bounds（高频调用）
    func updateLiveBoxBounds(bbox: CGRect) {
        guard let livePersonBox = livePersonBox else { return }
        
        // 应用最小尺寸限制
        let constrainedWidth = max(bbox.size.width, liveBoxMinimumSize)
        let constrainedHeight = max(bbox.size.height, liveBoxMinimumSize)
        
        let constrainedFrame = CGRect(
            x: bbox.midX - constrainedWidth / 2,
            y: bbox.midY - constrainedHeight / 2,
            width: constrainedWidth,
            height: constrainedHeight
        )
        
        // 直接设置 frame（蓝色框不旋转，所以不需要处理 transform）
        livePersonBox.frame = constrainedFrame
        
        // 更新引导线
        updateGuidanceLineForLiveBox()
    }
    
    /// 显示蓝色框
    func showLiveBox() {
        livePersonBox?.isHidden = false
    }
    
    /// 隐藏蓝色框和引导线
    func hideLiveBox() {
        livePersonBox?.isHidden = true
        guidanceLine?.isHidden = true
    }
    
    /// 更新引导线（连接白色框和蓝色框的中心点）
    /// 引导线在previewCanvasView.layer上绘制，因此两个框的坐标都需要转换到previewCanvasView坐标系
    private func updateGuidanceLineForLiveBox() {
        guard let livePersonBox = livePersonBox,
              let arGuidanceView = arGuidanceView,
              let guidanceLine = guidanceLine else { return }
        
        // 蓝色框的中心点（已经在previewCanvasView坐标系中）
        let liveBoxFrame = livePersonBox.frame
        let liveBoxCenterInCanvas = CGPoint(
            x: liveBoxFrame.midX,
            y: liveBoxFrame.midY
        )
        
        // 白色框的中心点（在arGuidanceView坐标系中）
        let whiteBoxCenterInARView = arGuidanceView.getReferenceBoxCenter()
        
        // 将白色框中心点从arGuidanceView坐标系转换到previewCanvasView坐标系
        let whiteBoxCenterInCanvas = arGuidanceView.convert(whiteBoxCenterInARView, to: previewCanvasView)
        
        // 现在两个点都在previewCanvasView坐标系中了，直接绘制引导线
        let path = UIBezierPath()
        path.move(to: whiteBoxCenterInCanvas)
        path.addLine(to: liveBoxCenterInCanvas)
        guidanceLine.path = path.cgPath
        guidanceLine.isHidden = livePersonBox.isHidden || arGuidanceView.isReferenceBoxHidden()
        
        LMLogger.log("🔵 [Guidance Line] 白色框中心(Canvas): \(whiteBoxCenterInCanvas)")
        LMLogger.log("🔵 [Guidance Line] 蓝色框中心(Canvas): \(liveBoxCenterInCanvas)")
    }
    
    // MARK: - Configuration
    
    func configureARGuidanceFeatures(_ enabled: Bool) {
        if enabled {
            startARGuidanceSession()
        } else {
            stopARGuidanceSession()
        }
    }
    
    /// 更新 ARGuidanceView 的尺寸以匹配 reference image
    private func updateARGuidanceViewSize() {
        let canvasSize = getMaxCanvasSize()
        
        // 计算中心点位置（在 previewCanvasView 中居中）
        let centerX = previewCanvasView.bounds.width / 2
        let centerY = previewCanvasView.bounds.height / 2
        
        // 使用 frame 方式设置尺寸和位置
        arGuidanceView.frame = CGRect(
            x: centerX - canvasSize.width / 2,
            y: centerY - canvasSize.height / 2,
            width: canvasSize.width,
            height: canvasSize.height
        )
    }
    
    /// 当画布比例变化时更新 AR Guidance 的位置
    /// 此方法在 updatePreviewCanvasAspectRatio 完成后调用
    func updateARGuidanceForAspectRatioChange() {
        // 检查是否有参考图和 bbox
        guard let referenceImage = currentReferenceImage,
              let referenceBbox = currentReferenceBbox else {
            LMLogger.log("📐 [AR Guidance] No reference image or bbox, skipping aspect ratio update")
            return
        }
        
        // 检查 AR Guidance 是否激活
        guard arGuidanceState == .activeGuidance || arGuidanceState == .referenceDetected(bbox: referenceBbox) else {
            LMLogger.log("📐 [AR Guidance] AR Guidance not active, skipping aspect ratio update")
            return
        }
        
        LMLogger.log("📐 [AR Guidance] Updating AR Guidance for aspect ratio change")
        LMLogger.log("📐 [AR Guidance] previewCanvasView bounds: \(previewCanvasView.bounds)")
        
        // 1. 更新 ARGuidanceView 的尺寸
        updateARGuidanceViewSize()
        
        // 2. 重新计算白色框的位置
        let canvasBbox = convertBboxToCanvas(bbox: referenceBbox, imageSize: referenceImage.size)
        
        // 3. 更新白色框位置
        arGuidanceView.setReferenceBoxBounds(bbox: canvasBbox)
        
        // 4. 如果白色框是显示状态，确保它仍然显示
        if let livePersonBox = livePersonBox, !livePersonBox.isHidden || isCurrentlyAligned {
            // 如果是对齐状态，更新绿色框位置
            if isCurrentlyAligned {
                arGuidanceView.showSuccessBox()
            } else {
                arGuidanceView.showReferenceBox()
            }
        } else {
            arGuidanceView.showReferenceBox()
        }
        
        LMLogger.log("📐 [AR Guidance] Updated reference box for new canvas size: \(canvasBbox)")
    }
    
    func startARGuidanceSession() {
        LMLogger.log("🎯 [AR Guidance] startARGuidanceSession called")
        LMLogger.log("🎯 [AR Guidance] Current state: \(currentCameraState)")
        LMLogger.log("🎯 [AR Guidance] Current arGuidanceState: \(arGuidanceState)")
        LMLogger.log("🎯 [AR Guidance] isARGuidanceActive: \(isARGuidanceActive)")
        LMLogger.log("🎯 [AR Guidance] referenceImageInitialOrientation: \(String(describing: referenceImageInitialOrientation))")
        LMLogger.log("🎯 [AR Guidance] currentReferenceBbox: \(String(describing: currentReferenceBbox))")
        
        // 重置对齐状态
        isCurrentlyAligned = false
        lastLiveBoxBounds = nil
        
        // 记录AR引导开始时间，用于延迟显示蓝框
        arGuidanceStartTime = Date()
        
        // 更新相机流检测管理器的摄像头位置
        let cameraPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .front : .back
        cameraStreamDetectionManager.setCameraPosition(cameraPosition)
        LMLogger.log("📷 [AR Guidance] Camera position set to: \(cameraPosition == .front ? "front" : "back")")
        
        // 检查AR Guidance View是否存在
        guard let arGuidanceView = arGuidanceView else {
            LMLogger.log("❌ [AR Guidance] arGuidanceView is nil!")
            return
        }
        LMLogger.log("✅ [AR Guidance] arGuidanceView exists, frame: \(arGuidanceView.frame), isHidden: \(arGuidanceView.isHidden)")
        
        // 检查是否有Reference Image
        guard let referenceImage = currentReferenceImage else {
            LMLogger.log("⚠️ [AR Guidance] No reference image for AR guidance")
            return
        }
        LMLogger.log("✅ [AR Guidance] Reference image exists, size: \(referenceImage.size)")
        
        // 根据图片宽高比判断初始方向（仅在未设置时计算）
        if referenceImageInitialOrientation == nil {
            let imageWidth = referenceImage.size.width
            let imageHeight = referenceImage.size.height
            let isImagePortrait = imageHeight >= imageWidth
            
            // 保存referenceImage的初始方向（基于图片宽高比）
            if isImagePortrait {
                // 图片是竖向的（高>宽），初始方向为竖屏
                referenceImageInitialOrientation = .portrait
                LMLogger.log("📱 [AR Guidance] Image is portrait (H:\(imageHeight) > W:\(imageWidth)), saved initial orientation: portrait")
            } else {
                // 图片是横向的（宽>高），初始方向为横屏
                referenceImageInitialOrientation = .landscapeRight
                LMLogger.log("📱 [AR Guidance] Image is landscape (W:\(imageWidth) > H:\(imageHeight)), saved initial orientation: landscapeRight")
            }
        } else {
            LMLogger.log("📱 [AR Guidance] Using existing referenceImageInitialOrientation: \(referenceImageInitialOrientation!.rawValue)")
        }
        
        // 检查当前设备方向是否匹配图片方向
        let isMatched = isCurrentOrientationMatched()
        let currentOrientation = LMOrientationMatcher.getCurrentDeviceOrientation()
        
        LMLogger.log("📱 [AR Guidance] Current device orientation: \(currentOrientation.rawValue), matched: \(isMatched)")
        
        if !isMatched {
            // 方向不匹配：不显示校准框，不启动检测
            arGuidanceState = .orientationMismatch
            arGuidanceView.setOrientationMatched(false)
            isARGuidanceActive = true // 仍然标记为激活，等待方向匹配后恢复
            LMLogger.log("⚠️ [AR Guidance] Orientation mismatch - AR guidance waiting for correct orientation")
            return
        }
        
        // 方向匹配：检测人物并显示引导
        arGuidanceView.setOrientationMatched(true)
        
        // 🔧 修复：在启动 AR Guidance 时，根据当前设备方向初始化 arGuidanceView 的 transform
        // 这确保了即使设备在进入 AR Guidance 时已经处于非 portrait 方向，transform 也能正确设置
        updateARGuidanceViewRotation(for: currentOrientation, isMatched: true)
        LMLogger.log("📐 [AR Guidance] Initial transform set for orientation: \(currentOrientation.rawValue), transform: \(arGuidanceView.transform)")
        
        // 检查是否已有检测结果（用户关闭后重新开启的情况）
        if let existingBbox = currentReferenceBbox {
            LMLogger.log("✅ [AR Guidance] Restoring from existing bbox: \(existingBbox)")
            
            // 更新 ARGuidanceView 的尺寸
            updateARGuidanceViewSize()
            
            // 转换bbox坐标到画布坐标
            let canvasBbox = convertBboxToCanvas(bbox: existingBbox, imageSize: referenceImage.size)
            
            // 恢复白色框
            arGuidanceView.setReferenceBoxBounds(bbox: canvasBbox)
            arGuidanceView.showReferenceBox()
            
            // 更新状态并启动实时检测
            arGuidanceState = .activeGuidance
            isARGuidanceActive = true
            
            LMLogger.log("✅ [AR Guidance] Session restored with existing bbox, isARGuidanceActive: \(isARGuidanceActive)")
        } else {
            LMLogger.log("✅ [AR Guidance] Orientation matched, starting person detection...")
            detectPersonAndShowGuidance(in: referenceImage)
            isARGuidanceActive = true
            LMLogger.log("✅ [AR Guidance] Session started, isARGuidanceActive: \(isARGuidanceActive)")
        }
    }
    
    func stopARGuidanceSession() {
        // 防止 Reference Image 检测的异步回调在 AR Guidance 关闭后回写旧状态
        arGuidanceReferenceDetectionRequestId &+= 1
        referenceImageDetectionManager?.cancelCurrentDetection()
        
        arGuidanceState = .disabled
        stopRealtimePersonDetection()
        arGuidanceView.hideOrShowAllGuidance(true)
        hideLiveBox() // 隐藏独立的蓝色框
        isARGuidanceActive = false
        isCurrentlyAligned = false // 重置对齐状态
        lastLiveBoxBounds = nil // 清除保存的蓝框位置
        arGuidanceStartTime = nil // 清除开始时间
        // 注意：不清除 referenceImageInitialOrientation，以便用户重新开启时可以恢复
        // referenceImageInitialOrientation 只在退出 compositionSelected 状态时清除
        
        LMLogger.log("✅ AR guidance session stopped (referenceImageInitialOrientation preserved)")
    }
    
    // MARK: - State Management
    
    /// 处理AR引导状态变化
    func handleARGuidanceStateChange(from oldState: LMARGuidanceState, to newState: LMARGuidanceState) {
        LMLogger.log("📊 AR Guidance状态变化: \(oldState) -> \(newState)")
        switch newState {
        case .disabled:
            stopRealtimePersonDetection()
            arGuidanceView.hideOrShowAllGuidance(true)
            // 注意：不在这里清除 currentReferenceImage 和 currentReferenceBbox
            // 这些只在退出 compositionSelected 状态时清除（closeReferenceImage 方法中）
            // 这样用户关闭 AR Guidance 后重新开启时可以恢复
            
        case .waitingForReferenceDetection:
            // TODO: 显示检测中的提示（使用Toast或加载动画）
            LMLogger.log("🔍 正在检测Reference Image中的人物...")
            
        case .referenceDetected(let bbox):
            currentReferenceBbox = bbox
            LMLogger.log("✅ Reference检测完成，bbox: \(bbox)")
            
        case .activeGuidance:
            guard currentCameraState == .compositionSelected,
                  currentReferenceImage != nil,
                  referenceImageInitialOrientation != nil else {
                LMLogger.log("⚠️ [AR Guidance] activeGuidance entered without valid reference context, stopping session")
                stopARGuidanceSession()
                return
            }
            isARGuidanceActive = true
            startRealtimePersonDetection()
            arGuidanceView.hideOrShowAllGuidance(false)
            
        case .paused:
            // 暂停状态：隐藏UI，但保留所有状态和检测器
            stopRealtimePersonDetection()
            arGuidanceView.hideOrShowAllGuidance(true)
            LMLogger.log("⏸️ AR引导已暂停（保留所有状态）")
            
        case .orientationMismatch:
            stopRealtimePersonDetection()
            arGuidanceView.hideOrShowAllGuidance(true)
            // TODO: 显示Toast提示 "请旋转设备以匹配参考图方向"
            LMLogger.log("⚠️ 方向不匹配，请旋转设备")
            
        case .error(let error):
            stopRealtimePersonDetection()
            arGuidanceView.hideOrShowAllGuidance(true)
            // TODO: 显示错误Toast
            LMLogger.log("❌ AR Guidance错误: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Reference Image Detection
    
    /// 检测Reference Image中的人物并显示引导
    func detectPersonAndShowGuidance(in image: UIImage) {
        LMLogger.log("🔍 [AR Guidance] detectPersonAndShowGuidance called, image size: \(image.size)")
        
        currentReferenceImage = image
        
        // 根据图片宽高比判断初始方向（如果还没有设置）
        if referenceImageInitialOrientation == nil {
            let imageWidth = image.size.width
            let imageHeight = image.size.height
            let isImagePortrait = imageHeight >= imageWidth
            
            if isImagePortrait {
                referenceImageInitialOrientation = .portrait
                LMLogger.log("📱 [AR Guidance] detectPersonAndShowGuidance - Image is portrait, saved initial orientation: portrait")
            } else {
                referenceImageInitialOrientation = .landscapeRight
                LMLogger.log("📱 [AR Guidance] detectPersonAndShowGuidance - Image is landscape, saved initial orientation: landscapeRight")
            }
        }
        
        // 检查方向是否与图片方向类型匹配
        let isMatched = isCurrentOrientationMatched()
        let currentOrientation = LMOrientationMatcher.getCurrentDeviceOrientation()
        
        if !isMatched {
            LMLogger.log("📱 [AR Guidance] detectPersonAndShowGuidance - 当前: \(currentOrientation.rawValue), 匹配: \(isMatched)")
            arGuidanceState = .orientationMismatch
            arGuidanceView.setOrientationMatched(false)
            LMLogger.log("⚠️ [AR Guidance] Orientation mismatch in detectPersonAndShowGuidance")
            return
        }
        
        // 🔧 修复：在检测人物之前，确保 arGuidanceView 的 transform 正确设置
        // 这确保了即使直接调用 detectPersonAndShowGuidance（而不是通过 startARGuidanceSession），transform 也能正确设置
        updateARGuidanceViewRotation(for: currentOrientation, isMatched: true)
        LMLogger.log("📐 [AR Guidance] detectPersonAndShowGuidance - transform set for orientation: \(currentOrientation.rawValue)")

        // 方向匹配：检测人物
        arGuidanceState = .waitingForReferenceDetection
        arGuidanceView.setOrientationMatched(true)
        LMLogger.log("✅ [AR Guidance] Starting person detection in reference image...")

        // 每次都执行新的检测，不使用缓存
        arGuidanceReferenceDetectionRequestId &+= 1
        let requestId = arGuidanceReferenceDetectionRequestId
        
        referenceImageDetectionManager.detectPersonInReferenceImage(image) { [weak self] bbox in
            guard let self = self else { return }

            // 忽略已过期的检测回调（例如用户已关闭 reference image / 已退出 compositionSelected）
            guard requestId == self.arGuidanceReferenceDetectionRequestId else {
                LMLogger.log("🧯 [AR Guidance] Ignoring stale reference detection callback (requestId=\(requestId))")
                return
            }
            
            guard self.currentCameraState == .compositionSelected else {
                LMLogger.log("🧯 [AR Guidance] Ignoring reference detection callback - not in compositionSelected state")
                return
            }
            
            guard case .waitingForReferenceDetection = self.arGuidanceState else {
                LMLogger.log("🧯 [AR Guidance] Ignoring reference detection callback - state changed: \(self.arGuidanceState)")
                return
            }
            
            LMLogger.log("📦 [AR Guidance] Detection callback received, bbox: \(String(describing: bbox))")

            guard let bbox = bbox else {
                self.arGuidanceState = .error(LMARGuidanceError.noPersonDetected)
                LMLogger.log("❌ [AR Guidance] No person detected in reference image")
//                AppTheme.Toast.showText("No person detected in reference image")
                return
            }

            LMLogger.log("✅ [AR Guidance] Person detected! bbox: \(bbox)")
            LMLogger.log("📏 [AR Guidance] Reference image size: \(image.size)")
            LMLogger.log("📏 [AR Guidance] Canvas frame: \(self.cameraPreviewView.frame)")
            LMLogger.log("📏 [AR Guidance] Canvas bounds: \(self.cameraPreviewView.bounds)")
            LMLogger.log("📏 [AR Guidance] Screen width: \(UIScreen.main.bounds.width)")
            
            // 更新 ARGuidanceView 的尺寸以匹配 reference image
            self.updateARGuidanceViewSize()
            
            // 获取最大画布尺寸
            let maxCanvasSize = self.getMaxCanvasSize()
            LMLogger.log("📏 [AR Guidance] Max canvas size: \(maxCanvasSize)")
            
            // 转换bbox坐标到画布坐标
            // 注意：横向图片已在识别前旋转到竖屏方向，bbox坐标直接对应竖屏显示
            let canvasBbox = self.convertBboxToCanvas(bbox: bbox, imageSize: image.size)
            LMLogger.log("📐 [AR Guidance] Canvas bbox (body): \(canvasBbox)")
            
            // 使用完整的 bbox 设置白色框（位置和尺寸）
            self.arGuidanceView.setReferenceBoxBounds(bbox: canvasBbox)
            
            // 显示白色框
            self.arGuidanceView.showReferenceBox()
            
            LMLogger.log("📍 [AR Guidance] Reference box set with bbox: \(canvasBbox)")
            LMLogger.log("📍 [AR Guidance] Center: (\(canvasBbox.midX), \(canvasBbox.midY))")
            LMLogger.log("📍 [AR Guidance] Size: (\(canvasBbox.width), \(canvasBbox.height))")
            
            LMLogger.log("✅ [AR Guidance] White reference box should now be visible")
            
            // 更新状态并启动实时检测
            self.arGuidanceState = .referenceDetected(bbox: bbox)
            self.arGuidanceState = .activeGuidance
            
            LMLogger.log("✅ [AR Guidance] State updated to activeGuidance, starting realtime detection")
        }
    }
    
    // MARK: - Realtime Detection
    
    /// 开始实时人物检测
    func startRealtimePersonDetection() {
        guard arGuidanceState == .activeGuidance else {
            LMLogger.log("⚠️ 状态不正确，无法启动实时检测")
            return
        }
        
        // 检查方向是否与图片方向类型匹配
        let isMatched = isCurrentOrientationMatched()
        cameraStreamDetectionManager.setOrientationMatched(isMatched)
        
        let currentOrientation = LMOrientationMatcher.getCurrentDeviceOrientation()
        LMLogger.log("✅ 开始实时人物检测，方向匹配: \(isMatched) (当前: \(currentOrientation.rawValue)")
    }
    
    /// 停止实时人物检测
    func stopRealtimePersonDetection() {
        // 关闭检测时同时重置方向匹配状态，避免后续误触发恢复检测
        cameraStreamDetectionManager?.setOrientationMatched(false)
        hideLiveBox() // 使用新的方法隐藏独立的蓝色框
        LMLogger.log("⏹️ 停止实时人物检测")
    }
    
    /// 处理实时检测结果
    /// - Parameters:
    ///   - bbox: 检测到的bbox（归一化坐标，Vision 坐标系统）
    ///   - confidence: 置信度
    private func handleRealtimeDetectionResult(bbox: CGRect?, confidence: Float) {
        // 检查是否在初始延迟期间（1秒内不显示蓝框）
        let isInInitialDelay: Bool
        if let startTime = arGuidanceStartTime {
            isInInitialDelay = Date().timeIntervalSince(startTime) < 1.0
        } else {
            isInInitialDelay = false
        }
        
        guard let bbox = bbox else {
            // 没有检测到人物，隐藏蓝色框（但在初始延迟期间本来就不显示）
            if let livePersonBox = livePersonBox, !livePersonBox.isHidden && !isInInitialDelay {
                hideLiveBox()
                LMLogger.log("🔵 [Live Detection] No person detected, hiding blue box")
            }
            // 如果当前是对齐状态但检测不到人物，恢复到非对齐状态
            if isCurrentlyAligned {
                restoreToNonAlignedState()
            }
            return
        }
        
        // 详细的坐标转换日志
        let canvasBbox = convertBboxToCanvas(bbox: bbox, imageSize: CGSize.zero)
        
        // 应用最小尺寸限制，防止蓝色框变形
        let minSize: CGFloat = 30.0
        var adjustedBbox = canvasBbox
        
        if canvasBbox.width < minSize {
            // 宽度小于最小值，调整宽度并居中
            let widthDiff = minSize - canvasBbox.width
            adjustedBbox.origin.x = max(0, canvasBbox.origin.x - widthDiff / 2)
            adjustedBbox.size.width = minSize
            LMLogger.log("🔵 [Live Detection] Width adjusted: \(canvasBbox.width) -> \(minSize)")
        }
        
        if canvasBbox.height < minSize {
            // 高度小于最小值，调整高度并居中
            let heightDiff = minSize - canvasBbox.height
            adjustedBbox.origin.y = max(0, canvasBbox.origin.y - heightDiff / 2)
            adjustedBbox.size.height = minSize
            LMLogger.log("🔵 [Live Detection] Height adjusted: \(canvasBbox.height) -> \(minSize)")
        }
        
        // 检查对齐状态
        if let referenceBbox = currentReferenceBbox,
           let referenceImage = currentReferenceImage {
            // 获取白色框在 arGuidanceView 坐标系中的 bbox
            let referenceCanvasBboxInARView = convertBboxToCanvas(bbox: referenceBbox, imageSize: referenceImage.size)
            
            // 将白色框的中心点从 arGuidanceView 坐标系转换到 previewCanvasView 坐标系
            let whiteBoxCenterInARView = CGPoint(
                x: referenceCanvasBboxInARView.midX,
                y: referenceCanvasBboxInARView.midY
            )
            let whiteBoxCenterInCanvas = arGuidanceView.convert(whiteBoxCenterInARView, to: previewCanvasView)
            
            // 蓝色框的中心点（已经在 previewCanvasView 坐标系中）
            let blueBoxCenterInCanvas = CGPoint(
                x: canvasBbox.midX,
                y: canvasBbox.midY
            )
            
            // 使用2%容差判断对齐（基于取景框宽高）
            let canvasSize = getMaxCanvasSize()
            let horizontalTolerance = canvasSize.width * 0.02
            let verticalTolerance = canvasSize.height * 0.02
            
            let horizontalDistance = abs(whiteBoxCenterInCanvas.x - blueBoxCenterInCanvas.x)
            let verticalDistance = abs(whiteBoxCenterInCanvas.y - blueBoxCenterInCanvas.y)
            
            let isAligned = horizontalDistance <= horizontalTolerance && verticalDistance <= verticalTolerance
            
            LMLogger.log("🎯 [Alignment Check] 白色框中心(Canvas): \(whiteBoxCenterInCanvas), 蓝色框中心(Canvas): \(blueBoxCenterInCanvas)")
            LMLogger.log("🎯 [Alignment Check] 水平距离: \(String(format: "%.1f", horizontalDistance))px (容差: \(String(format: "%.1f", horizontalTolerance))px)")
            LMLogger.log("🎯 [Alignment Check] 垂直距离: \(String(format: "%.1f", verticalDistance))px (容差: \(String(format: "%.1f", verticalTolerance))px)")
            LMLogger.log("🎯 [Alignment Check] 对齐状态: \(isAligned)")
            
            if isAligned {
                // 对齐状态
                if !isCurrentlyAligned {
                    // 首次进入对齐状态，显示绿色框
                    showAlignmentSuccessWithGreenFrame()
                    isCurrentlyAligned = true
                    // 隐藏蓝色框
                    hideLiveBox()
                    LMLogger.log("✅ 对齐成功！水平距离: \(String(format: "%.1f", horizontalDistance))px, 垂直距离: \(String(format: "%.1f", verticalDistance))px")
                }
                // 对齐状态下，继续更新蓝框位置（但蓝框是隐藏的，只是保持计算）
                // 这样当超出阈值时可以立即显示
                lastLiveBoxBounds = adjustedBbox
            } else {
                // 非对齐状态
                if isCurrentlyAligned {
                    // 从对齐状态变为非对齐状态，恢复蓝白框显示
                    restoreToNonAlignedState()
                    LMLogger.log("⚠️ 超出对齐阈值！水平距离: \(String(format: "%.1f", horizontalDistance))px, 垂直距离: \(String(format: "%.1f", verticalDistance))px")
                }
                
                // 非对齐状态下，正常显示和更新蓝色框（但在初始延迟期间不显示）
                if !isInInitialDelay {
                    if let livePersonBox = livePersonBox, livePersonBox.isHidden {
                        setLiveBoxBounds(bbox: adjustedBbox)
                        showLiveBox()
                        LMLogger.log("🔵 [Live Detection] Blue box shown for first time with bounds: \(adjustedBbox)")
                    } else {
                        updateLiveBoxBounds(bbox: adjustedBbox)
                    }
                } else {
                    // 初始延迟期间，只保存位置，不显示
                    lastLiveBoxBounds = adjustedBbox
                }
            }
        } else {
            // 没有参考框，正常显示蓝色框（但在初始延迟期间不显示）
            if !isInInitialDelay {
                if let livePersonBox = livePersonBox, livePersonBox.isHidden {
                    setLiveBoxBounds(bbox: adjustedBbox)
                    showLiveBox()
                    LMLogger.log("🔵 [Live Detection] Blue box shown for first time with bounds: \(adjustedBbox)")
                } else {
                    updateLiveBoxBounds(bbox: adjustedBbox)
                }
            } else {
                // 初始延迟期间，只保存位置，不显示
                lastLiveBoxBounds = adjustedBbox
            }
        }
    }
    
    /// 从对齐状态恢复到非对齐状态（显示蓝白框+引导线）
    private func restoreToNonAlignedState() {
        isCurrentlyAligned = false
        
        // 隐藏绿色框
        arGuidanceView.hideSuccessBox()
        
        // 显示白色框
        arGuidanceView.showReferenceBox()
        
        // 如果有保存的蓝框位置，恢复显示
        if let lastBounds = lastLiveBoxBounds {
            setLiveBoxBounds(bbox: lastBounds)
            showLiveBox()
        }
        
        LMLogger.log("🔄 恢复到非对齐状态，显示蓝白框+引导线")
    }
    
    // MARK: - Orientation Handling
    
    /// 设备方向变化处理
    @objc func deviceOrientationDidChange() {
        guard currentReferenceImage != nil else { return }
        guard arGuidanceState != .disabled else { return }
        
        let isMatched = isCurrentOrientationMatched()
        let currentOrientation = LMOrientationMatcher.getCurrentDeviceOrientation()
        
        LMLogger.log("📱 设备方向变化 - 当前: \(currentOrientation.rawValue), 匹配: \(isMatched)")
        
        // 更新 ARGuidanceView 的旋转
        updateARGuidanceViewRotation(for: currentOrientation, isMatched: isMatched)
        
        handleOrientationMatchChange(isMatched: isMatched)
    }
    
    /// 根据设备方向更新 ARGuidanceView 的旋转
    private func updateARGuidanceViewRotation(for orientation: UIDeviceOrientation, isMatched: Bool) {
        guard isMatched else {
            return
        }
        switch orientation {
        case .landscapeRight:
            arGuidanceView.transform = CGAffineTransform(rotationAngle: -.pi)
        case .landscapeLeft:
            arGuidanceView.transform = .identity
        case .portraitUpsideDown:
            arGuidanceView.transform = CGAffineTransform(rotationAngle: .pi)
        case .portrait:
            arGuidanceView.transform = .identity
        default:
            break
        }
    }
    
    /// 处理相机切换时的AR引导状态
    func handleARGuidanceOnCameraSwitch() {
        // 检查是否处于AR引导状态
        guard arGuidanceState == .activeGuidance || arGuidanceState == .orientationMismatch else {
            return
        }
        
        if isUsingFrontCamera {
            // 切换到前置摄像头：立即隐藏AR引导
            arGuidanceState = .orientationMismatch
            arGuidanceView.setOrientationMatched(false)
            stopRealtimePersonDetection()
            arGuidanceView.hideOrShowAllGuidance(true)
            LMLogger.log("📷 [AR Guidance] Switched to front camera - hiding AR guidance")
        } else {
            // 切换回后置摄像头：延迟1秒后恢复AR引导（复用方向匹配逻辑）
            LMLogger.log("📷 [AR Guidance] Switched to back camera - will restore AR guidance in 1s")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                
                // 检查是否仍然处于后置摄像头
                guard !self.isUsingFrontCamera else {
                    LMLogger.log("⚠️ Camera switched again, canceling AR guidance restore")
                    return
                }
                
                // 检查方向是否匹配
                let isMatched = self.isCurrentOrientationMatched()
                guard isMatched else {
                    LMLogger.log("⚠️ Orientation mismatch, not restoring AR guidance")
                    return
                }
                
                // 恢复AR引导
                if self.currentReferenceBbox != nil {
                    // 已经检测到人物，恢复到activeGuidance状态
                    self.arGuidanceState = .activeGuidance
                    self.arGuidanceView.setOrientationMatched(true)
                    
                    // 🔧 修复：恢复时也需要设置正确的 transform
                    let currentOrientation = LMOrientationMatcher.getCurrentDeviceOrientation()
                    self.updateARGuidanceViewRotation(for: currentOrientation, isMatched: true)
                    
                    self.arGuidanceView.hideOrShowAllGuidance(false)
                    LMLogger.log("✅ [AR Guidance] Restored AR guidance after camera switch")
                } else {
                    // 还没有检测到人物，需要触发人物检测
                    self.arGuidanceView.setOrientationMatched(true)
                    LMLogger.log("✅ [AR Guidance] Starting person detection after camera switch")
                    if let referenceImage = self.currentReferenceImage {
                        self.detectPersonAndShowGuidance(in: referenceImage)
                    }
                }
            }
        }
    }
    
    /// 处理方向匹配状态变化
    private func handleOrientationMatchChange(isMatched: Bool) {
        if isMatched {
            // 方向匹配：延迟1秒后恢复检测，避免频繁切换
            if arGuidanceState == .orientationMismatch {
                LMLogger.log("✅ 方向匹配 - 将在1秒后恢复AR引导")
                
                // 延迟1秒后恢复
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // 再次检查方向是否仍然匹配（避免快速旋转导致的误恢复）
                    let stillMatched = self.isCurrentOrientationMatched()
                    guard stillMatched else {
                        LMLogger.log("⚠️ 延迟恢复时发现方向已不匹配，取消恢复")
                        return
                    }
                    
                    // 从方向不匹配状态恢复
                    if self.currentReferenceBbox != nil {
                        // 已经检测到人物，恢复到activeGuidance状态
                        self.arGuidanceState = .activeGuidance
                        self.arGuidanceView.setOrientationMatched(true)
                        
                        // 🔧 修复：恢复时重新设置 transform（因为延迟 1 秒后方向可能已变化）
                        let currentOrientation = LMOrientationMatcher.getCurrentDeviceOrientation()
                        self.updateARGuidanceViewRotation(for: currentOrientation, isMatched: true)
                        
                        self.arGuidanceView.hideOrShowAllGuidance(false)
                        LMLogger.log("✅ 方向匹配恢复 - 恢复AR引导")
                    } else {
                        // 还没有检测到人物，需要触发人物检测
                        self.arGuidanceView.setOrientationMatched(true)
                        LMLogger.log("✅ 方向匹配恢复 - 开始人物检测")
                        // 触发人物检测
                        if let referenceImage = self.currentReferenceImage {
                            self.detectPersonAndShowGuidance(in: referenceImage)
                        }
                    }
                }
            }
        } else {
            // 方向不匹配：立即隐藏所有引导框，停止检测
            if case .activeGuidance = arGuidanceState {
                arGuidanceState = .orientationMismatch
                arGuidanceView.setOrientationMatched(false)
                stopRealtimePersonDetection()
                // 立即隐藏所有引导框
                arGuidanceView.hideOrShowAllGuidance(true)
                LMLogger.log("⚠️ 方向不匹配 - 立即暂停AR引导并隐藏所有引导框")
            } else if case .referenceDetected = arGuidanceState {
                arGuidanceState = .orientationMismatch
                arGuidanceView.setOrientationMatched(false)
                // 立即隐藏所有引导框
                arGuidanceView.hideOrShowAllGuidance(true)
                LMLogger.log("⚠️ 方向不匹配 - 立即暂停AR引导并隐藏所有引导框")
            }
        }
    }
    
    // MARK: - Coordinate Conversion
    
    /// 计算最大画布尺寸（基于当前画布比例和 reference image）
    /// 返回画布尺寸（始终以屏幕宽度为基准）
    /// 注意：横向图片已在识别前旋转到竖屏方向，因此这里需要使用旋转后的宽高比
    /// 当画布比例变化时，AR Guidance 的画布尺寸也会相应变化
    private func getMaxCanvasSize() -> CGSize {
        let topOffset = AppTheme.Screen.safeAreaTop + LMCameraConstants.topStatusBarHeight
        let bottomOffset = LMCameraConstants.bottomControlsHeight
        let availableHeight = AppTheme.Screen.height - topOffset - bottomOffset - AppTheme.Screen.safeAreaBottom
        let screenWidth = AppTheme.Screen.width
        
        // 使用当前画布比例计算尺寸（与 updatePreviewCanvasAspectRatio 保持一致）
        let canvasWidth = screenWidth
        var canvasHeight: CGFloat
        
        switch currentAspectRatio {
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
        }
        
        LMLogger.log("📐 [Canvas] getMaxCanvasSize - ratio: \(currentAspectRatio.displayName), size: \(canvasWidth)x\(canvasHeight)")
        
        return CGSize(width: canvasWidth, height: canvasHeight)
    }
    
    /// 将bbox坐标转换到画布坐标
    /// 注意：横向图片已在识别前旋转到竖屏方向，因此bbox坐标无需旋转，直接转换即可
    /// 输入的 bbox 使用 Vision 坐标系统（原点在左下角，Y轴向上）
    private func convertBboxToCanvas(bbox: CGRect, imageSize: CGSize) -> CGRect {
        // 使用实际画布尺寸（已根据图片宽高比计算）
        let canvasSize = getMaxCanvasSize()
        
        LMLogger.log("📐 [Coordinate] Converting bbox")
        LMLogger.log("  - Canvas size: \(canvasSize)")
        LMLogger.log("  - Input bbox (Vision coords): \(bbox)")
        
        // Vision 坐标系统：原点在左下角，Y轴向上
        // UIKit 坐标系统：原点在左上角，Y轴向下
        
        // 1. 翻转 Y 坐标（Vision -> UIKit）
        let flippedY = 1.0 - bbox.origin.y - bbox.height
        
        // 2. 转换到画布坐标（归一化坐标 -> 像素坐标）
        let canvasX = bbox.origin.x * canvasSize.width
        let canvasY = flippedY * canvasSize.height
        let canvasBboxWidth = bbox.width * canvasSize.width
        let canvasBboxHeight = bbox.height * canvasSize.height
        
        // 横向图片已在识别前旋转，bbox坐标直接对应竖屏显示，无需旋转
        let result = CGRect(x: canvasX, y: canvasY, width: canvasBboxWidth, height: canvasBboxHeight)
        LMLogger.log("📐 [Coordinate] Canvas bbox: \(result)")
        
        return result
    }

    
    // MARK: - Helper Methods
    
    /// 检查当前设备方向是否与初始方向匹配（竖屏 vs 横屏）
    /// - Returns: true 表示方向类型匹配，false 表示不匹配
    private func isCurrentOrientationMatched() -> Bool {
        guard let initialOrientation = referenceImageInitialOrientation else {
            LMLogger.log("⚠️ [Orientation Check] No initial orientation saved")
            return false
        }
        
        let currentOrientation = LMOrientationMatcher.getCurrentDeviceOrientation()
        let isCurrentPortrait = (currentOrientation == .portrait || currentOrientation == .portraitUpsideDown)
        let isInitialPortrait = (initialOrientation == .portrait || initialOrientation == .portraitUpsideDown)
        let isMatched = (isCurrentPortrait == isInitialPortrait)
        
        LMLogger.log("📱 [Orientation Check] Initial: \(initialOrientation.rawValue) (portrait: \(isInitialPortrait)), Current: \(currentOrientation.rawValue) (portrait: \(isCurrentPortrait)), Matched: \(isMatched)")
        
        return isMatched
    }
    
    /// 计算两个矩形的重叠比例
    func calculateOverlapRatio(rect1: CGRect, rect2: CGRect) -> Double {
        let intersection = rect1.intersection(rect2)
        
        guard !intersection.isNull else {
            return 0.0
        }
        
        let intersectionArea = intersection.width * intersection.height
        let smallerArea = min(rect1.width * rect1.height, rect2.width * rect2.height)
        
        return Double(intersectionArea / smallerArea)
    }
    
    /// 显示对齐成功指示器（使用绿色校准框）
    /// 注意：不再停止AR引导，而是保持检测以便在超出阈值时恢复
    func showAlignmentSuccessWithGreenFrame() {
        // 检查是否已经显示绿色框
        guard arGuidanceView.successBox.isHidden else {
            return
        }
        
        // 隐藏 Step 4 引导（用户第一次 AR Guidance 校准成功）
        hideAlignBoxesGuide()
        
        // 不再停止AR引导检测，保持实时检测以便在超出阈值时恢复
        // stopARGuidanceSession() // 移除这行
        
        // 不再更新AR Guidance按钮状态，因为AR引导仍然激活
        // cameraBottomControlsView.setARGuidanceActive(false) // 移除这行
        
        // 显示绿色成功框（在白色框位置，绿框常驻，对号3秒后消失）
        arGuidanceView.showSuccessBox()
        
        // 触觉反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        LMLogger.log("✅ 显示绿色成功框（AR引导保持激活，继续检测）")
    }
    
    // MARK: - Cleanup
    
    /// 暂停AR引导资源
    func pauseARGuidance() {
        if arGuidanceState == .activeGuidance || arGuidanceState == .orientationMismatch {
            arGuidanceState = .paused
            LMLogger.log("⏸️ AR引导状态从 referenceDetected 切换到 paused")
        } else if case .referenceDetected = arGuidanceState {
            arGuidanceState = .paused
            LMLogger.log("⏸️ AR引导状态从 referenceDetected 切换到 paused")
        }
        // 隐藏所有UI元素
        arGuidanceView.hideOrShowAllGuidance(true)
        hideLiveBox() // 隐藏独立的蓝色框
        stopRealtimePersonDetection()
       
        // - reset()（会清除回调）
        // - stopARGuidanceSession()（会清除 isARGuidanceActive）
        
        // 保留以下内容：
        // - currentReferenceImage（参考图）
        // - currentReferenceBbox（参考框位置）
        // - arGuidanceState（AR引导状态，设置为 .paused）
        // - isARGuidanceActive（AR激活标志，保持 true）
        // - referenceImageInitialOrientation（初始方向）
        // - onDetectionResult 回调
        // - 设备方向监听器
        // - 实时检测状态（会随相机会话自动恢复）
        
        LMLogger.log("🧹 AR引导资源已暂停（仅隐藏UI，保留所有状态，isARGuidanceActive: \(isARGuidanceActive), arGuidanceState: \(arGuidanceState)）")
    }
    
    /// 完全清理AR引导资源（用于真正退出相机页面）
    func fullCleanupARGuidance() {
        arGuidanceState = .disabled
        stopRealtimePersonDetection()
        cameraStreamDetectionManager?.reset()
        referenceImageInitialOrientation = nil
        currentReferenceImage = nil
        currentReferenceBbox = nil
        isCurrentlyAligned = false // 重置对齐状态
        lastLiveBoxBounds = nil // 清除保存的蓝框位置
        arGuidanceStartTime = nil // 清除开始时间
        
        arGuidanceView.hideOrShowAllGuidance(true)
        hideLiveBox() // 隐藏独立的蓝色框
        
        NotificationCenter.default.removeObserver(
            self,
            name: .devicePhysicalOrientationDidChange,
            object: nil
        )
        
        LMLogger.log("🧹 AR引导资源已完全清理")
    }
}

// MARK: - Video Frame Processing
extension LMCameraPage {
    
    /// 处理AR引导的视频帧
    func processARGuidanceFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isARGuidanceActive else { return }
        guard currentCameraState == .compositionSelected else { return }
        guard currentReferenceImage != nil, referenceImageInitialOrientation != nil else { return }
        guard arGuidanceState == .activeGuidance else { return }
        
        // 检查方向是否与图片方向类型匹配
        let isMatched = isCurrentOrientationMatched()
        
        // 仅在方向匹配时进行检测
        if isMatched {
            cameraStreamDetectionManager.startRealtimeDetection(from: sampleBuffer)
        }
    }
}
