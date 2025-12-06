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
    case disabled                          // 未启用
    case waitingForReferenceDetection      // 等待Reference Image检测
    case referenceDetected(bbox: CGRect)   // Reference Image检测完成
    case activeGuidance                    // AR引导激活中
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
            // 直接添加到 previewCanvasView，确保坐标系统一致
            previewCanvasView.addSubview(arGuidanceView)
            
            LMLogger.log("✅ AR Guidance View已添加到 previewCanvasView")
        }
        
        // 创建检测管理器（每个管理器使用独立的 PersonDetectionManager 实例）
        if referenceImageDetectionManager == nil {
            // 为 Reference Image 检测创建独立的 PersonDetectionManager
            let referenceDetector = LMPersonDetectionManager()
            referenceImageDetectionManager = LMReferenceImageDetectionManager(personDetectionManager: referenceDetector)
            LMLogger.log("✅ Reference Image Detection Manager 已创建（独立实例）")
        }
        
        if cameraStreamDetectionManager == nil {
            // 为实时流检测创建独立的 PersonDetectionManager
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
        
        // 根据图片宽高比判断初始方向
        let imageWidth = referenceImage.size.width
        let imageHeight = referenceImage.size.height
        let isImagePortrait = imageHeight > imageWidth
        
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
        
        // 检查当前设备方向是否匹配图片方向
        let isMatched = isCurrentOrientationMatched()
        let currentOrientation = LMOrientationMatcher.getCurrentDeviceOrientation()
        
        LMLogger.log("📱 [AR Guidance] Current device orientation: \(currentOrientation.rawValue), matched: \(isMatched)")
        
        if !isMatched {
            // 方向不匹配：不显示校准框，不启动检测
            arGuidanceState = .orientationMismatch
            arGuidanceView.setOrientationMatched(false)
            LMLogger.log("⚠️ [AR Guidance] Orientation mismatch - AR guidance disabled")
//            showToast("Please rotate device to match reference image orientation")
            return
        }
        
        // 方向匹配：检测人物并显示引导
        arGuidanceView.setOrientationMatched(true)
        LMLogger.log("✅ [AR Guidance] Orientation matched, starting person detection...")
        
        detectPersonAndShowGuidance(in: referenceImage)
        
        isARGuidanceActive = true
        LMLogger.log("✅ [AR Guidance] Session started, isARGuidanceActive: \(isARGuidanceActive)")
    }
    
    func stopARGuidanceSession() {
        arGuidanceState = .disabled
        stopRealtimePersonDetection()
        arGuidanceView.hideOrShowAllGuidance(true)
        isARGuidanceActive = false
        referenceImageInitialOrientation = nil // 清除初始方向
        
        LMLogger.log("✅ AR guidance session stopped")
    }
    
    // MARK: - State Management
    
    /// 处理AR引导状态变化
    func handleARGuidanceStateChange(from oldState: LMARGuidanceState, to newState: LMARGuidanceState) {
        LMLogger.log("📊 AR Guidance状态变化: \(oldState) -> \(newState)")
        
        switch newState {
        case .disabled:
            stopRealtimePersonDetection()
            arGuidanceView.hideOrShowAllGuidance(true)
            // 注意：不清除 currentReferenceImage 和 currentReferenceBbox
            // 因为用户可能从预览页返回，需要保持这些引用以便恢复 AR 引导
            // currentReferenceImage = nil
            // currentReferenceBbox = nil
            
        case .waitingForReferenceDetection:
            // TODO: 显示检测中的提示（使用Toast或加载动画）
            LMLogger.log("🔍 正在检测Reference Image中的人物...")
            
        case .referenceDetected(let bbox):
            currentReferenceBbox = bbox
            LMLogger.log("✅ Reference检测完成，bbox: \(bbox)")
            
        case .activeGuidance:
            startRealtimePersonDetection()
            
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
        
        // 检查方向是否与图片方向类型匹配
        let isMatched = isCurrentOrientationMatched()
        
        if !isMatched {
            let currentOrientation = LMOrientationMatcher.getCurrentDeviceOrientation()
            LMLogger.log("📱 [AR Guidance] detectPersonAndShowGuidance - 当前: \(currentOrientation.rawValue), 匹配: \(isMatched)")
            arGuidanceState = .orientationMismatch
            arGuidanceView.setOrientationMatched(false)
            LMLogger.log("⚠️ [AR Guidance] Orientation mismatch in detectPersonAndShowGuidance")
            return
        }
        
        // 方向匹配：检测人物
        arGuidanceState = .waitingForReferenceDetection
        arGuidanceView.setOrientationMatched(true)
        LMLogger.log("✅ [AR Guidance] Starting person detection in reference image...")
        
        // 使用图片尺寸作为缓存key
        let imageId = "\(Int(image.size.width))x\(Int(image.size.height))"
        
        referenceImageDetectionManager.detectPersonInReferenceImage(
            image,
            imageId: imageId
        ) { [weak self] bbox in
            guard let self = self else { return }
            
            LMLogger.log("📦 [AR Guidance] Detection callback received, bbox: \(String(describing: bbox))")
            
            guard let bbox = bbox else {
                self.arGuidanceState = .error(LMARGuidanceError.noPersonDetected)
                LMLogger.log("❌ [AR Guidance] No person detected in reference image")
                self.showToast("No person detected in reference image")
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
            
            // 转换bbox坐标到画布坐标（始终使用竖向画布）
            let canvasBbox = self.convertBboxToCanvas(bbox: bbox, imageSize: image.size)
            LMLogger.log("📐 [AR Guidance] Canvas bbox (body): \(canvasBbox)")
            
            // 判断是否需要旋转（横向参考图）
            // 注意：需要考虑图片的 EXIF 方向信息
            let isImageLandscape: Bool
            let imageOrientation = image.imageOrientation
            
            LMLogger.log("🔍 [AR Guidance] Image orientation check:")
            LMLogger.log("  - Image width: \(image.size.width)")
            LMLogger.log("  - Image height: \(image.size.height)")
            LMLogger.log("  - Image orientation: \(imageOrientation.rawValue)")
            
            // 根据 EXIF 方向判断实际的宽高
            switch imageOrientation {
            case .left, .right, .leftMirrored, .rightMirrored:
                // 图片被旋转了90度或270度，宽高需要交换
                isImageLandscape = image.size.height > image.size.width
                LMLogger.log("  - Orientation rotated 90°/270°, swapping width/height")
            default:
                // 正常方向或上下翻转
                isImageLandscape = image.size.width > image.size.height
            }
            
            LMLogger.log("  - Is landscape (final): \(isImageLandscape)")
            
            // 使用完整的 bbox 设置白色框（位置和尺寸）
            // 注意：对于横向图片，坐标已经在 convertBboxToCanvas 中旋转过了
            self.arGuidanceView.setReferenceBoxBounds(bbox: canvasBbox)
            
            LMLogger.log("ℹ️ [AR Guidance] Bbox coordinates already rotated in convertBboxToCanvas for landscape images")
            
            // 显示白色框
            self.arGuidanceView.showReferenceBox()
            
            LMLogger.log("📍 [AR Guidance] Reference box set with bbox: \(canvasBbox)")
            LMLogger.log("📍 [AR Guidance] Center: (\(canvasBbox.midX), \(canvasBbox.midY))")
            LMLogger.log("📍 [AR Guidance] Size: (\(canvasBbox.width), \(canvasBbox.height))")
            LMLogger.log("📍 [AR Guidance] Is landscape: \(isImageLandscape)")
            
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
        LMLogger.log("✅ 开始实时人物检测，方向匹配: \(isMatched) (当前: \(currentOrientation.rawValue))")
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
        guard let bbox = bbox else {
            // 没有检测到人物，隐藏蓝色框
            if !arGuidanceView.livePersonBox.isHidden {
                arGuidanceView.hideLiveBox()
                LMLogger.log("🔵 [Live Detection] No person detected, hiding blue box")
            }
            return
        }
        
        // 详细的坐标转换日志
        let maxCanvasSize = getMaxCanvasSize()
        LMLogger.log("🔵 [Live Detection] ===== 开始坐标转换 =====")
        LMLogger.log("🔵 [Live Detection] Vision bbox (原始): x=\(bbox.origin.x), y=\(bbox.origin.y), w=\(bbox.width), h=\(bbox.height)")
        LMLogger.log("🔵 [Live Detection] Max canvas size: \(maxCanvasSize)")
        
        // 使用统一的坐标转换方法（包含 Y 轴翻转）
        let canvasBbox = convertBboxToCanvas(bbox: bbox, imageSize: CGSize.zero)
        
        // 计算中心点位置
        let centerX = canvasBbox.midX
        let centerY = canvasBbox.midY
        let position = CGPoint(x: centerX, y: centerY)
        
        LMLogger.log("🔵 [Live Detection] Canvas bbox (转换后): x=\(canvasBbox.origin.x), y=\(canvasBbox.origin.y), w=\(canvasBbox.width), h=\(canvasBbox.height)")
        LMLogger.log("🔵 [Live Detection] Center position: x=\(position.x), y=\(position.y)")
        LMLogger.log("🔵 [Live Detection] ===== 坐标转换完成 =====")
        
        // 判断是否需要旋转（横向参考图）
        let isImageLandscape: Bool
        if let referenceImage = currentReferenceImage {
            isImageLandscape = referenceImage.size.width > referenceImage.size.height
        } else if let initialOrientation = referenceImageInitialOrientation {
            isImageLandscape = (initialOrientation == .landscapeLeft || initialOrientation == .landscapeRight)
        } else {
            isImageLandscape = false
        }
        
        // 首次显示时设置位置，后续直接更新center
        if arGuidanceView.livePersonBox.isHidden {
            arGuidanceView.setLiveBoxPosition(position: position)
            
            // 如果是横向参考图，旋转蓝色框90度
            if isImageLandscape {
                arGuidanceView.rotateLiveBox(angle: .pi / 2)
                LMLogger.log("🔄 [Live Detection] Blue box rotated 90° for landscape image")
            }
            
            arGuidanceView.showLiveBox()
            LMLogger.log("🔵 [Live Detection] Blue box shown for first time")
        } else {
            arGuidanceView.moveLiveBoxToPosition(position: position)
        }
        
        // 检查对齐状态（80%重叠率）
        if let referenceBbox = currentReferenceBbox,
           let referenceImage = currentReferenceImage {
            let referenceCanvasBbox = convertBboxToCanvas(bbox: referenceBbox, imageSize: referenceImage.size)
            let overlapRatio = calculateOverlapRatio(rect1: referenceCanvasBbox, rect2: canvasBbox)
            
            if overlapRatio >= 0.80 {
                // 对齐成功（80%重叠）- 显示绿色成功框
                showAlignmentSuccessWithGreenFrame()
                LMLogger.log("✅ 对齐成功！重叠率: \(String(format: "%.1f", overlapRatio * 100))%")
            }
        }
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
        updateARGuidanceViewRotation(for: currentOrientation)
        
        handleOrientationMatchChange(isMatched: isMatched)
    }
    
    /// 根据设备方向更新 ARGuidanceView 的旋转
    private func updateARGuidanceViewRotation(for orientation: UIDeviceOrientation) {
        guard let referenceImage = currentReferenceImage else { return }
        
        let isImageLandscape = referenceImage.size.width > referenceImage.size.height
        
        if isImageLandscape {
            // 横向参考图
            switch orientation {
            case .landscapeRight:
                // 旋转 180 度
                LMLogger.log("🔄 [AR Guidance] Rotating ARGuidanceView 180° for landscapeRight")
                arGuidanceView.transform = .identity
            case .landscapeLeft:
                // 清除 transform
                LMLogger.log("🔄 [AR Guidance] Clearing ARGuidanceView transform for landscapeLeft")
                arGuidanceView.transform = CGAffineTransform(rotationAngle: .pi)
            default:
                break
            }
        } else {
            // 竖向参考图
            switch orientation {
            case .portraitUpsideDown:
                // 旋转 180 度
                LMLogger.log("🔄 [AR Guidance] Rotating ARGuidanceView 180° for portraitUpsideDown")
                arGuidanceView.transform = CGAffineTransform(rotationAngle: .pi)
            case .portrait:
                // 清除 transform
                LMLogger.log("🔄 [AR Guidance] Clearing ARGuidanceView transform for portrait")
                arGuidanceView.transform = .identity
            default:
                break
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    
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
    /// 参考图（无论横向还是竖向）都以图片宽度对齐屏幕宽度进行等比拉伸
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
    /// 对于横向图片，需要进行坐标旋转以正确显示为垂直方向
    /// 注意：输入的 bbox 使用 Vision 坐标系统（原点在左下角，Y轴向上）
    private func convertBboxToCanvas(bbox: CGRect, imageSize: CGSize) -> CGRect {
        // 使用实际画布尺寸（已根据图片宽高比计算）
        let canvasSize = getMaxCanvasSize()
        
        // 判断是否为横向图片
        let isImageLandscape = imageSize.width > imageSize.height
        
        LMLogger.log("📐 [Coordinate] Converting bbox")
        LMLogger.log("  - Image size: \(imageSize)")
        LMLogger.log("  - Is landscape: \(isImageLandscape)")
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
        
        if isImageLandscape {
            // 横向图片：需要旋转坐标使其显示为垂直
            // 旋转90度逆时针（因为图片是横向的，需要转成竖向）
            // 旋转公式（90度逆时针）：
            // newX = y
            // newY = canvasWidth - x - width
            // newWidth = height
            // newHeight = width
            
            let rotatedX = canvasY
            let rotatedY = canvasSize.width - canvasX - canvasBboxWidth
            let rotatedWidth = canvasBboxHeight
            let rotatedHeight = canvasBboxWidth
            
            let result = CGRect(x: rotatedX, y: rotatedY, width: rotatedWidth, height: rotatedHeight)
            LMLogger.log("📐 [Coordinate] Landscape - rotated bbox: \(result)")
            
            return result
        } else {
            // 竖向图片：正常转换
            let result = CGRect(x: canvasX, y: canvasY, width: canvasBboxWidth, height: canvasBboxHeight)
            LMLogger.log("📐 [Coordinate] Portrait bbox: \(result)")
            
            return result
        }
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
    func showAlignmentSuccessWithGreenFrame() {
        // 检查是否已经显示绿色框
        guard arGuidanceView.successBox.isHidden else {
            return
        }
        
        // 停止AR引导检测
        stopARGuidanceSession()
        
        // 更新AR Guidance按钮状态
        cameraBottomControlsView.setARGuidanceActive(false)
        
        // 显示绿色成功框（在白色框位置，3秒后自动消失）
        arGuidanceView.showSuccessBox()
        
        // 触觉反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        LMLogger.log("✅ 显示绿色成功框")
    }
    
    // MARK: - Cleanup
    
    /// 清理AR引导资源（临时暂停，不清除状态）
    func cleanupARGuidance() {
        // 注意：这是临时暂停，不是完全停止
        // 保留所有状态和回调，以便从预览页返回时能快速恢复
        
        // 只隐藏UI，不停止检测，不改变任何状态
        // 这样当相机会话恢复时，检测会自动继续
        arGuidanceView.hideOrShowAllGuidance(true)
        
        // 不调用以下方法，保持所有状态：
        // - stopRealtimePersonDetection()（会停止检测）
        // - reset()（会清除回调）
        // - stopARGuidanceSession()（会清除 isARGuidanceActive）
        
        // 保留以下内容：
        // - currentReferenceImage（参考图）
        // - currentReferenceBbox（参考框位置）
        // - arGuidanceState（AR引导状态，保持 .activeGuidance）
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
        referenceImageDetectionManager?.clearCache()
        referenceImageInitialOrientation = nil
        currentReferenceImage = nil
        currentReferenceBbox = nil
        
        arGuidanceView.hideOrShowAllGuidance(true)
        
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
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
