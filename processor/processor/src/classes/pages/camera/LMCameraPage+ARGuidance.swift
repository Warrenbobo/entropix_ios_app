//
//  LMCameraPage+ARGuidance.swift
//  processor
//
//  AR Guidance feature implementation
//

import UIKit
import AVFoundation

// MARK: - AR Guidance
extension LMCameraPage {
    
    func configureARGuidanceFeatures(_ enabled: Bool) {
        if enabled {
            LMLogger.log("📱 AR Guidance features enabled")
            startARGuidanceSession()
        } else {
            LMLogger.log("📱 AR Guidance features disabled")
            stopARGuidanceSession()
        }
    }
    
    func startARGuidanceSession() {
        // 初始化人物检测管理器
        if personDetectionManager == nil {
            personDetectionManager = LMPersonDetectionManager()
            personDetectionManager?.delegate = self
        }
        
        personDetectionManager?.startDetection()
        isARGuidanceActive = true
        
        // 显示AR引导覆盖层（包括白色固定框、四角标记、十字准星）
        showARGuidanceOverlay()
        
        LMLogger.log("✅ AR guidance session started - White center frame (80x120) and green dynamic frame ready")
    }
    

    func stopARGuidanceSession() {
        personDetectionManager?.stopDetection()
        isARGuidanceActive = false
        
        hideARGuidanceOverlay()
        
        LMLogger.log("✅ AR guidance session stopped")
    }
    
    func showARGuidanceOverlay() {
        // 检查是否已存在白色固定参考框
        if let existingFrame = cameraPreviewView.viewWithTag(ViewTag.arGuidanceFrame.rawValue) {
            // 已存在，只需显示
            existingFrame.isHidden = false
            LMLogger.log("📐 Showing existing white center reference frame")
        } else {
            // 不存在，创建新的
            addCenterReferenceFrame()
        }
    }
    
    /// 添加白色固定参考框（位于屏幕中心，宽为屏幕宽度的2/5，高为宽度的1.2倍）
    func addCenterReferenceFrame() {
        let previewBounds = cameraPreviewView.bounds
        
        // 宽度为屏幕宽度的2/5
        let frameWidth: CGFloat = previewBounds.width * 2.0 / 5.0
        // 高度为宽度的1.1倍
        let frameHeight: CGFloat = frameWidth * 1.1
        
        let centerX = previewBounds.width / 2
        let centerY = previewBounds.height / 2
        
        // 创建白色固定参考框容器
        let centerFrame = UIView()
        centerFrame.tag = ViewTag.arGuidanceFrame.rawValue
        centerFrame.backgroundColor = .clear
        centerFrame.frame = CGRect(
            x: centerX - frameWidth/2,
            y: centerY - frameHeight/2,
            width: frameWidth,
            height: frameHeight
        )
        
        // 使用 BezierPath 绘制白色引导框
        // 1. 绘制四个圆角（仅描边，不填充）
        let cornerLayer = CAShapeLayer()
        cornerLayer.fillColor = UIColor.clear.cgColor
        cornerLayer.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
        cornerLayer.lineWidth = 3
        
        let cornerPath = createCornerPath(in: centerFrame.bounds)
        cornerLayer.path = cornerPath.cgPath
        centerFrame.layer.addSublayer(cornerLayer)
        
        // 2. 绘制中心准星（实心填充）
        let crosshairLayer = CAShapeLayer()
        crosshairLayer.fillColor = UIColor.white.cgColor
        crosshairLayer.strokeColor = UIColor.clear.cgColor
        
        let crosshairPath = createCrosshairPath(in: centerFrame.bounds, length: 8, width: 3)
        crosshairLayer.path = crosshairPath.cgPath
        centerFrame.layer.addSublayer(crosshairLayer)
        
        cameraPreviewView.addSubview(centerFrame)
        
        LMLogger.log("📐 Added white center reference frame at (\(String(format: "%.1f", centerX)), \(String(format: "%.1f", centerY))) size: \(String(format: "%.1f", frameWidth))x\(String(format: "%.1f", frameHeight))")
    }
    
    /// 创建四个圆角路径（仅用于描边）
    /// - Parameter bounds: 框的边界
    /// - Returns: 四个圆角的路径
    func createCornerPath(in bounds: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        
        // 参数定义
        let cornerLength: CGFloat = 24  // 每个角的长度
        let cornerRadius: CGFloat = 18  // 圆角半径
        
        // 四个角的位置
        // 左上角
        path.move(to: CGPoint(x: 0, y: cornerLength))
        path.addArc(withCenter: CGPoint(x: cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .pi,
                    endAngle: .pi * 1.5,
                    clockwise: true)
        path.addLine(to: CGPoint(x: cornerLength, y: 0))
        
        // 右上角
        path.move(to: CGPoint(x: bounds.width - cornerLength, y: 0))
        path.addArc(withCenter: CGPoint(x: bounds.width - cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .pi * 1.5,
                    endAngle: 0,
                    clockwise: true)
        path.addLine(to: CGPoint(x: bounds.width, y: cornerLength))
        
        // 右下角
        path.move(to: CGPoint(x: bounds.width, y: bounds.height - cornerLength))
        path.addArc(withCenter: CGPoint(x: bounds.width - cornerRadius, y: bounds.height - cornerRadius),
                    radius: cornerRadius,
                    startAngle: 0,
                    endAngle: .pi * 0.5,
                    clockwise: true)
        path.addLine(to: CGPoint(x: bounds.width - cornerLength, y: bounds.height))
        
        // 左下角
        path.move(to: CGPoint(x: cornerLength, y: bounds.height))
        path.addArc(withCenter: CGPoint(x: cornerRadius, y: bounds.height - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .pi * 0.5,
                    endAngle: .pi,
                    clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: bounds.height - cornerLength))
        
        return path
    }
    
    /// 创建十字准星路径（用于实心填充）
    /// - Parameters:
    ///   - bounds: 框的边界
    ///   - length: 准星长度（从中心点延伸的距离）
    ///   - width: 准星线宽
    /// - Returns: 十字准星的路径
    func createCrosshairPath(in bounds: CGRect, length: CGFloat, width: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2
        
        // 水平线（使用矩形）
        let horizontalRect = CGRect(
            x: centerX - length,
            y: centerY - width / 2,
            width: length * 2,
            height: width
        )
        path.append(UIBezierPath(rect: horizontalRect))
        
        // 垂直线（使用矩形）
        let verticalRect = CGRect(
            x: centerX - width / 2,
            y: centerY - length,
            width: width,
            height: length * 2
        )
        path.append(UIBezierPath(rect: verticalRect))
        
        return path
    }
    

    func hideARGuidanceOverlay() {
        // 隐藏白色固定参考框（不移除，只隐藏）
        cameraPreviewView.viewWithTag(ViewTag.arGuidanceFrame.rawValue)?.isHidden = true
        cameraPreviewView.viewWithTag(ViewTag.arHintLabel.rawValue)?.isHidden = true
        // 移除绿色动态检测框
        cameraPreviewView.viewWithTag(ViewTag.personDetectionFrame.rawValue)?.removeFromSuperview()
        // 移除连线
        cameraPreviewView.viewWithTag(ViewTag.arGuidanceLine.rawValue)?.removeFromSuperview()
    }

    
    /// 更新检测到的人物框和引导元素
    /// 新需求：白色固定框在中心（使用BezierPath绘制），蓝色动态框跟随检测到的人物（略小）
    func updateDetectedPersonFrame(_ boundingBox: BoundingBox, isAligned: Bool) {
        // 检查是否已存在蓝色动态检测框
        let existingGreenFrame = cameraPreviewView.viewWithTag(ViewTag.personDetectionFrame.rawValue)
        
        LMLogger.log("📊 Detected bbox: (\(String(format: "%.3f", boundingBox.x)), \(String(format: "%.3f", boundingBox.y))) size: \(String(format: "%.3f", boundingBox.width))x\(String(format: "%.3f", boundingBox.height))")
        
        // 计算蓝色框的尺寸（比白色框略小，保持宽高比1:1.1）
        let previewBounds = cameraPreviewView.bounds
        let detectedX = boundingBox.x * Double(previewBounds.width)
        let detectedY = boundingBox.y * Double(previewBounds.height)
        let detectedWidth = boundingBox.width * Double(previewBounds.width)
        let detectedHeight = boundingBox.height * Double(previewBounds.height)
        
        let whiteFrameWidth = previewBounds.width * 2.0 / 5.0
        let whiteFrameHeight = whiteFrameWidth * 1.1
        let blueFrameWidth: CGFloat = whiteFrameWidth * 0.70 // 白色框的70%
        let blueFrameHeight: CGFloat = blueFrameWidth * 1.1 // 保持1:1.1的宽高比
        
        // 蓝色框的中心点与检测到的人物中心点对齐
        let detectedCenterX = detectedX + detectedWidth / 2.0
        let detectedCenterY = detectedY + detectedHeight / 2.0
        
        let blueFrameRect = CGRect(
            x: detectedCenterX - Double(blueFrameWidth)/2.0,
            y: detectedCenterY - Double(blueFrameHeight)/2.0,
            width: Double(blueFrameWidth),
            height: Double(blueFrameHeight)
        )
        
        // 计算白色框的位置（屏幕中心）
        let whiteFrameRect = CGRect(
            x: Double(previewBounds.width / 2 - whiteFrameWidth / 2),
            y: Double(previewBounds.height / 2 - whiteFrameHeight / 2),
            width: Double(whiteFrameWidth),
            height: Double(whiteFrameHeight)
        )
        
        // 计算重叠比例
        let overlapRatio = calculateOverlapRatio(rect1: whiteFrameRect, rect2: blueFrameRect)
        LMLogger.log("📐 Overlap ratio: \(String(format: "%.1f", overlapRatio * 100))%")
        
        // 检查重叠比例，如果超过90%则显示对齐成功提示
        if overlapRatio >= 0.9 {
            // 隐藏两个校准框和连线
            cameraPreviewView.viewWithTag(ViewTag.arGuidanceFrame.rawValue)?.isHidden = true
            cameraPreviewView.viewWithTag(ViewTag.personDetectionFrame.rawValue)?.isHidden = true
            cameraPreviewView.viewWithTag(ViewTag.arGuidanceLine.rawValue)?.isHidden = true
            
            // 显示绿色对勾提示并停止AR引导
            showAlignmentSuccessIndicator()
            
            LMLogger.log("✅ Frames aligned! Overlap: \(String(format: "%.1f", overlapRatio * 100))% - Stopping AR guidance")
            return
        } else {
            // 确保校准框可见
            cameraPreviewView.viewWithTag(ViewTag.arGuidanceFrame.rawValue)?.isHidden = false
            cameraPreviewView.viewWithTag(ViewTag.arGuidanceLine.rawValue)?.isHidden = false
        }
        
        if let existingFrame = existingGreenFrame {
            // 更新现有框的位置和大小
            existingFrame.frame = blueFrameRect
            existingFrame.isHidden = false
            
            // 更新 ShapeLayer 的路径（蓝色框准星长度6，线宽2）
            if let sublayers = existingFrame.layer.sublayers as? [CAShapeLayer], sublayers.count >= 2 {
                // 更新圆角路径
                let newCornerPath = createCornerPath(in: CGRect(origin: .zero, size: blueFrameRect.size))
                sublayers[0].path = newCornerPath.cgPath
                
                // 更新准星路径
                let newCrosshairPath = createCrosshairPath(in: CGRect(origin: .zero, size: blueFrameRect.size), length: 6, width: 2)
                sublayers[1].path = newCrosshairPath.cgPath
            }
        } else {
            // 创建新的蓝色动态检测框
            let blueFrame = UIView()
            blueFrame.tag = ViewTag.personDetectionFrame.rawValue
            blueFrame.backgroundColor = .clear
            blueFrame.frame = blueFrameRect
            
            // 使用 BezierPath 绘制蓝色引导框（比白色框略小）
            // 1. 绘制四个圆角（仅描边，不填充）
            let blueCornerLayer = CAShapeLayer()
            blueCornerLayer.fillColor = UIColor.clear.cgColor
            blueCornerLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8).cgColor
            blueCornerLayer.lineWidth = 2
            
            let blueCornerPath = createCornerPath(in: CGRect(origin: .zero, size: blueFrameRect.size))
            blueCornerLayer.path = blueCornerPath.cgPath
            blueFrame.layer.addSublayer(blueCornerLayer)
            
            // 2. 绘制中心准星（实心填充，长度6，线宽2）
            let blueCrosshairLayer = CAShapeLayer()
            blueCrosshairLayer.fillColor = UIColor.systemBlue.withAlphaComponent(0.8).cgColor
            blueCrosshairLayer.strokeColor = UIColor.clear.cgColor
            
            let blueCrosshairPath = createCrosshairPath(in: CGRect(origin: .zero, size: blueFrameRect.size), length: 6, width: 2)
            blueCrosshairLayer.path = blueCrosshairPath.cgPath
            blueFrame.layer.addSublayer(blueCrosshairLayer)
            
            cameraPreviewView.addSubview(blueFrame)
        }
        
        LMLogger.log("✅ Blue dynamic frame updated at (\(String(format: "%.1f", detectedCenterX)), \(String(format: "%.1f", detectedCenterY))) size: \(blueFrameWidth)x\(blueFrameHeight)")
        
        // 绘制从白色固定框到蓝色动态框的连线
        drawGuidanceLineFromCenterToDetected(detectedCenter: CGPoint(x: detectedCenterX, y: detectedCenterY), isAligned: isAligned)
        
        if isAligned {
            showAlignmentFeedback()
        }
    }
    
    /// 计算两个矩形的重叠比例（相对于较小矩形的面积）
    /// - Parameters:
    ///   - rect1: 第一个矩形
    ///   - rect2: 第二个矩形
    /// - Returns: 重叠比例（0.0 到 1.0）
    func calculateOverlapRatio(rect1: CGRect, rect2: CGRect) -> Double {
        let intersection = rect1.intersection(rect2)
        
        // 如果没有交集，返回0
        guard !intersection.isNull else {
            return 0.0
        }
        
        // 计算交集面积
        let intersectionArea = intersection.width * intersection.height
        
        // 使用较小矩形的面积作为基准
        let smallerArea = min(rect1.width * rect1.height, rect2.width * rect2.height)
        
        // 返回重叠比例
        return Double(intersectionArea / smallerArea)
    }
    
    /// 显示对齐成功指示器（绿色对勾）并停止AR引导
    func showAlignmentSuccessIndicator() {
        // 检查是否已经显示
        let indicatorTag = 9999
        if cameraPreviewView.viewWithTag(indicatorTag) != nil {
            return
        }
        
        // 停止AR引导检测
        personDetectionManager?.stopDetection()
        
        // 创建指示器容器
        let indicatorView = UIView()
        indicatorView.tag = indicatorTag
        indicatorView.backgroundColor = .clear
        
        // 创建绿色对勾图片视图
        let checkImageView = UIImageView()
        checkImageView.image = UIImage(systemName: "checkmark.circle.fill")
        checkImageView.tintColor = .systemGreen
        checkImageView.contentMode = .scaleAspectFit
        
        // 设置大小和位置（屏幕中心）
        let size: CGFloat = 80
        let centerX = cameraPreviewView.bounds.width / 2
        let centerY = cameraPreviewView.bounds.height / 2
        
        indicatorView.frame = CGRect(
            x: centerX - size / 2,
            y: centerY - size / 2,
            width: size,
            height: size
        )
        
        checkImageView.frame = indicatorView.bounds
        indicatorView.addSubview(checkImageView)
        
        // 添加到预览视图
        cameraPreviewView.addSubview(indicatorView)
        
        // 添加缩放动画
        indicatorView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        indicatorView.alpha = 0
        
        UIView.animate(withDuration: 0.3, animations: {
            indicatorView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            indicatorView.alpha = 1.0
        }) { _ in
            // 3秒后消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                UIView.animate(withDuration: 0.3, animations: {
                    indicatorView.alpha = 0
                    indicatorView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                }) { _ in
                    indicatorView.removeFromSuperview()
                    
                    // 不再恢复校准框显示，保持AR引导关闭状态
                    LMLogger.log("✅ AR guidance stopped after alignment success")
                }
            }
        }
        
        // 触觉反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        LMLogger.log("✅ Alignment success indicator shown, AR guidance stopped")
    }
    

    /// 绘制从白色固定框（屏幕中心）到蓝色动态框的连线
    func drawGuidanceLineFromCenterToDetected(detectedCenter: CGPoint, isAligned: Bool) {
        let previewBounds = cameraPreviewView.bounds
        
        // 白色固定框的中心点（屏幕中心）
        let centerX = previewBounds.width / 2
        let centerY = previewBounds.height / 2
        let whiteCenter = CGPoint(x: centerX, y: centerY)
        
        // 创建连线容器视图
        let lineContainer = UIView()
        lineContainer.tag = ViewTag.arGuidanceLine.rawValue
        lineContainer.backgroundColor = .clear
        lineContainer.frame = previewBounds
        
        // 使用 CAShapeLayer 绘制连线
        let linePath = UIBezierPath()
        linePath.move(to: whiteCenter)
        linePath.addLine(to: detectedCenter)
        
        let lineLayer = CAShapeLayer()
        lineLayer.path = linePath.cgPath
        lineLayer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8).cgColor // 蓝色虚线
        lineLayer.lineWidth = 3
        lineLayer.lineDashPattern = [2, 6] // 虚线样式
        lineLayer.lineCap = .round
        
        lineContainer.layer.addSublayer(lineLayer)
        
        // 添加到预览视图（在检测框之前，确保连线可见）
        // 先移除可能存在的旧连线
        cameraPreviewView.viewWithTag(ViewTag.arGuidanceLine.rawValue)?.removeFromSuperview()
        // 添加新连线到预览视图
        cameraPreviewView.addSubview(lineContainer)
        // 将连线移到白色框和蓝色框之后
        if let whiteFrame = cameraPreviewView.viewWithTag(ViewTag.arGuidanceFrame.rawValue) {
            cameraPreviewView.bringSubviewToFront(whiteFrame)
        }
        if let blueFrame = cameraPreviewView.viewWithTag(ViewTag.personDetectionFrame.rawValue) {
            cameraPreviewView.bringSubviewToFront(blueFrame)
        }
        
        // 计算距离并显示提示
        let distance = sqrt(pow(whiteCenter.x - detectedCenter.x, 2) + pow(whiteCenter.y - detectedCenter.y, 2))
        LMLogger.log("📏 Guidance line drawn - Distance: \(String(format: "%.1f", distance))px, Aligned: \(isAligned)")
    }
    
    func showAlignmentFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        UIView.animate(withDuration: 0.2, animations: {
            self.cameraPreviewView.viewWithTag(ViewTag.arGuidanceFrame.rawValue)?.alpha = 0.5
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.cameraPreviewView.viewWithTag(ViewTag.arGuidanceFrame.rawValue)?.alpha = 1.0
            }
        }
    }
}

// MARK: - Video Frame Processing for AR Guidance
extension LMCameraPage {
    
    /// 处理AR引导的视频帧（限制频率为每1秒处理一次）
    func processARGuidanceFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isARGuidanceActive else { return }
        
        // 时间控制：每1秒处理一次
        let currentTime = Date().timeIntervalSince1970
        if let lastProcessTime = lastARGuidanceProcessTime {
            let timeSinceLastProcess = currentTime - lastProcessTime
            if timeSinceLastProcess < 1.0 {
                // 距离上次处理不足1秒，跳过本次处理
                return
            }
        }
        
        // 更新最后处理时间
        lastARGuidanceProcessTime = currentTime
        
        // 处理视频帧
        personDetectionManager?.processVideoFrame(sampleBuffer)
    }
}

// MARK: - LMPersonDetectionManagerDelegate
extension LMCameraPage: LMPersonDetectionManagerDelegate {
    
    func personDetectionManager(_ manager: LMPersonDetectionManager, didDetectPerson result: PersonDetectionResult) {
        // 计算检测到的人物中心点是否接近屏幕中心（白色固定框位置）
        let detectedCenterX = result.boundingBox.x + result.boundingBox.width / 2.0
        let detectedCenterY = result.boundingBox.y + result.boundingBox.height / 2.0
        
        // 屏幕中心点（归一化坐标）
        let screenCenterX = 0.5
        let screenCenterY = 0.5
        
        // 计算距离（归一化坐标系）
        let distanceX = abs(detectedCenterX - screenCenterX)
        let distanceY = abs(detectedCenterY - screenCenterY)
        let distance = sqrt(distanceX * distanceX + distanceY * distanceY)
        
        // 对齐阈值：距离小于0.1（归一化坐标）认为已对齐
        let isAligned = distance < 0.1
        
        DispatchQueue.main.async { [weak self] in
            self?.updateDetectedPersonFrame(result.boundingBox, isAligned: isAligned)
        }
        
        if isAligned {
            LMLogger.log("✅ Person aligned to center! Distance: \(String(format: "%.3f", distance))")
        }
    }
    
    func personDetectionManagerDidNotDetectPerson(_ manager: LMPersonDetectionManager) {
        // 未检测到人物，隐藏蓝色引导框和连接线
        DispatchQueue.main.async { [weak self] in
            self?.hideBlueFrameAndGuidanceLine()
        }
    }
    
    func personDetectionManager(_ manager: LMPersonDetectionManager, didFailWithError error: Error) {
        LMLogger.log("❌ Person detection failed: \(error.localizedDescription)")
    }
    
    /// 隐藏蓝色引导框和连接线
    private func hideBlueFrameAndGuidanceLine() {
        // 隐藏蓝色动态检测框
        cameraPreviewView.viewWithTag(ViewTag.personDetectionFrame.rawValue)?.isHidden = true
        // 隐藏连线
        cameraPreviewView.viewWithTag(ViewTag.arGuidanceLine.rawValue)?.isHidden = true
        
        LMLogger.log("👻 No person detected - blue frame and guidance line hidden")
    }
}
