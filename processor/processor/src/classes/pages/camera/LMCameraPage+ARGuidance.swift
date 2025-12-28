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
        // 创建AR引导视图
        if arGuidanceView == nil {
            arGuidanceView = LMARGuidanceView(frame: .zero)
            previewCanvasView.addSubview(arGuidanceView)
            
            LMLogger.log("✅ AR Guidance View已添加到 previewCanvasView")
        }
        
        // 创建检测管理器（每个管理器使用独立的 PersonDetectionManager 实例）
        if referenceImageDetectionManager == nil {
            let referenceDetector = LMPersonDetectionManager()
            referenceImageDetectionManager = LMReferenceImageDetectionManager(personDetectionManager: referenceDetector)
            LMLogger.log("✅ Reference Image Detection Manager 已创建（独立实例）")
        }
        
        if cameraStreamDetectionManager == nil {
            let streamDetector = LMPersonDetectionManager()
            cameraStreamDetectionManager = LMCameraStreamDetectionManager(personDetectionManager: streamDetector)
            
            // 设置检测结果回调
            cameraStreamDetectionManager.onDetectionResult = { [weak self] bbox, confidence in
                self?.handleRealtimeDetectionResult(bbox: bbox, confidence: confidence)
            }
            LMLogger.log("✅ Camera Stream Detection Manager 已创建（独立实例）")
        }
        
        // 监听设备方向变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: .devicePhysicalOrientationDidChange,
            object: nil
        )
        
        LMLogger.log("✅ AR引导功能初始化完成")
    }
    
    // MARK: - Configuration
    
    func configureARGuidanceFeatures(_ enabled: Bool) {
        if enabled {
            LMLogger.log("📱 AR Guidance features enabled")
            startARGuidanceSession()
        } else {
            LMLogger.log("📱 AR Guidance features disabled")
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
        
        LMLogger.log("📐 [AR Guidance] Updated ARGuidanceView frame to: \(arGuidanceView.frame)")
        LMLogger.log("📐 [AR Guidance] Canvas size: \(canvasSize)")
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
        arGuidanceState = .disabled
        stopRealtimePersonDetection()
        arGuidanceView.hideOrShowAllGuidance(true)
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
        referenceImageDetectionManager.detectPersonInReferenceImage(image) { [weak self] bbox in
            guard let self = self else { return }

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
        cameraStreamDetectionManager.stopRealtimeDetection()
        arGuidanceView.hideLiveBox()
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
            if !arGuidanceView.livePersonBox.isHidden && !isInInitialDelay {
                arGuidanceView.hideLiveBox()
                LMLogger.log("🔵 [Live Detection] No person detected, hiding blue box")
            }
            // 如果当前是对齐状态但检测不到人物，恢复到非对齐状态
            if isCurrentlyAligned {
                restoreToNonAlignedState()
            }
            return
        }
        
        // 详细的坐标转换日志
        let maxCanvasSize = getMaxCanvasSize()
        var canvasBbox = convertBboxToCanvas(bbox: bbox, imageSize: CGSize.zero)
        
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
            let referenceCanvasBbox = convertBboxToCanvas(bbox: referenceBbox, imageSize: referenceImage.size)
            
            // 使用2%容差判断对齐（基于取景框宽高）
            let canvasSize = getMaxCanvasSize()
            let horizontalTolerance = canvasSize.width * 0.02
            let verticalTolerance = canvasSize.height * 0.02
            
            let horizontalDistance = abs(referenceCanvasBbox.midX - canvasBbox.midX)
            let verticalDistance = abs(referenceCanvasBbox.midY - canvasBbox.midY)
            
            let isAligned = horizontalDistance <= horizontalTolerance && verticalDistance <= verticalTolerance
            
            if isAligned {
                // 对齐状态
                if !isCurrentlyAligned {
                    // 首次进入对齐状态，显示绿色框
                    showAlignmentSuccessWithGreenFrame()
                    isCurrentlyAligned = true
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
                    if arGuidanceView.livePersonBox.isHidden {
                        arGuidanceView.setLiveBoxBounds(bbox: adjustedBbox)
                        arGuidanceView.showLiveBox()
                        LMLogger.log("🔵 [Live Detection] Blue box shown for first time with bounds: \(adjustedBbox)")
                    } else {
                        arGuidanceView.updateLiveBoxBounds(bbox: adjustedBbox)
                    }
                } else {
                    // 初始延迟期间，只保存位置，不显示
                    lastLiveBoxBounds = adjustedBbox
                }
            }
        } else {
            // 没有参考框，正常显示蓝色框（但在初始延迟期间不显示）
            if !isInInitialDelay {
                if arGuidanceView.livePersonBox.isHidden {
                    arGuidanceView.setLiveBoxBounds(bbox: adjustedBbox)
                    arGuidanceView.showLiveBox()
                    LMLogger.log("🔵 [Live Detection] Blue box shown for first time with bounds: \(adjustedBbox)")
                } else {
                    arGuidanceView.updateLiveBoxBounds(bbox: adjustedBbox)
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
            arGuidanceView.setLiveBoxBounds(bbox: lastBounds)
            arGuidanceView.showLiveBox()
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
    
    // MARK: - Face Detection Helper (已禁用 - 仅使用人体检测)
    
    // 人脸检测已禁用 - 不再检测人脸
    // /// 检测图像中的人脸并返回人脸 bbox
    // /// - Parameter image: 待检测的图像
    // /// - Returns: 人脸 bbox（归一化坐标），如果未检测到则返回 nil
    // private func detectFaceInCurrentImage(_ image: UIImage) -> CGRect? {
    //     guard let cgImage = image.cgImage else {
    //         return nil
    //     }
    //     
    //     // 创建人脸检测请求
    //     let faceDetectionRequest = VNDetectFaceRectanglesRequest()
    //     
    //     // 获取设备方向
    //     let deviceOrientation = UIDevice.current.orientation
    //     let imageOrientation: CGImagePropertyOrientation
    //     switch deviceOrientation {
    //     case .portrait:
    //         imageOrientation = .right
    //     case .portraitUpsideDown:
    //         imageOrientation = .left
    //     case .landscapeLeft:
    //         imageOrientation = .up
    //     case .landscapeRight:
    //         imageOrientation = .down
    //     default:
    //         imageOrientation = .right
    //     }
    //     
    //     // 创建请求处理器
    //     let handler = VNImageRequestHandler(cgImage: cgImage, orientation: imageOrientation, options: [:])
    //     
    //     do {
    //         try handler.perform([faceDetectionRequest])
    //         
    //         // 获取检测结果
    //         guard let faceObservations = faceDetectionRequest.results as? [VNFaceObservation],
    //               let firstFace = faceObservations.first else {
    //             return nil
    //         }
    //         
    //         // 保持 Vision 原始坐标（归一化坐标 0-1）
    //         // 不进行坐标转换，保持与 PersonDetectionManager 一致
    //         let visionBox = firstFace.boundingBox
    //         let faceBbox = CGRect(
    //             x: visionBox.origin.x,
    //             y: visionBox.origin.y,
    //             width: visionBox.size.width,
    //             height: visionBox.size.height
    //         )
    //         
    //         return faceBbox
    //     } catch {
    //         LMLogger.log("❌ Face detection failed: \(error.localizedDescription)")
    //         return nil
    //     }
    // }
    
    // MARK: - Coordinate Conversion
    
    /// 计算最大画布尺寸（基于 reference image 的宽高比）
    /// 返回画布尺寸（始终以屏幕宽度为基准）
    /// 注意：横向图片已在识别前旋转到竖屏方向，因此这里的宽高比已经是旋转后的
    private func getMaxCanvasSize() -> CGSize {
        let topOffset = AppTheme.Screen.safeAreaTop + LMCameraConstants.topStatusBarHeight
        let bottomOffset = LMCameraConstants.bottomControlsHeight
        let availableHeight = AppTheme.Screen.height - topOffset - bottomOffset - AppTheme.Screen.safeAreaBottom
        let screenWidth = AppTheme.Screen.width
        
        // 根据 reference image 计算画布尺寸
        if let referenceImage = currentReferenceImage {
            let imageWidth = referenceImage.size.width
            let imageHeight = referenceImage.size.height
            
            // 统一逻辑：以图片宽度对齐屏幕宽度，等比拉伸
            let scale = screenWidth / imageWidth
            let canvasWidth = screenWidth
            let canvasHeight = imageHeight * scale
            
            // 确保高度不超过可用高度
            if canvasHeight > availableHeight {
                // 如果高度超出，以可用高度为基准重新计算
                let adjustedScale = availableHeight / imageHeight
                return CGSize(width: imageWidth * adjustedScale, height: availableHeight)
            }
            
            return CGSize(width: canvasWidth, height: canvasHeight)
        } else {
            // 默认使用 3:4 竖向比例
            let canvasWidth = screenWidth
            let aspectRatio: CGFloat = 3.0 / 4.0
            let canvasHeight = canvasWidth / aspectRatio
            
            if canvasHeight > availableHeight {
                return CGSize(width: availableHeight * aspectRatio, height: availableHeight)
            }
            return CGSize(width: canvasWidth, height: canvasHeight)
        }
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
        guard arGuidanceState == .activeGuidance else { return }
        
        // 检查方向是否与图片方向类型匹配
        let isMatched = isCurrentOrientationMatched()
        
        // 仅在方向匹配时进行检测
        if isMatched {
            cameraStreamDetectionManager.startRealtimeDetection(from: sampleBuffer)
        }
    }
}
