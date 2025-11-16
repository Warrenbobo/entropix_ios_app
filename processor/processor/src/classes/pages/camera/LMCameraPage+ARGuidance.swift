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
        // 仅添加白色固定参考框（位于屏幕中心）
        addCenterReferenceFrame()
    }
    
    /// 添加白色固定参考框（位于屏幕中心，宽80，高120）
    func addCenterReferenceFrame() {
        let previewBounds = cameraPreviewView.bounds
        let frameWidth: CGFloat = 80
        let frameHeight: CGFloat = 120
        
        let centerX = previewBounds.width / 2
        let centerY = previewBounds.height / 2
        
        // 创建白色固定参考框
        let centerFrame = UIView()
        centerFrame.tag = ViewTag.arGuidanceFrame.rawValue // 使用固定tag
        centerFrame.backgroundColor = .clear
        centerFrame.layer.borderWidth = 3
        centerFrame.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        centerFrame.layer.cornerRadius = 8
        centerFrame.frame = CGRect(
            x: centerX - frameWidth/2,
            y: centerY - frameHeight/2,
            width: frameWidth,
            height: frameHeight
        )
        
        // 添加四角装饰（白色）
        addCornerDecorations(to: centerFrame, color: .white)
        
        cameraPreviewView.addSubview(centerFrame)
        
        LMLogger.log("📐 Added white center reference frame at (\(String(format: "%.1f", centerX)), \(String(format: "%.1f", centerY))) size: \(frameWidth)x\(frameHeight)")
    }
    

    func hideARGuidanceOverlay() {
        // 移除白色固定参考框
        cameraPreviewView.viewWithTag(ViewTag.arGuidanceFrame.rawValue)?.removeFromSuperview()
        cameraPreviewView.viewWithTag(ViewTag.arHintLabel.rawValue)?.removeFromSuperview()
        // 移除绿色动态检测框
        cameraPreviewView.viewWithTag(ViewTag.personDetectionFrame.rawValue)?.removeFromSuperview()
        // 移除连线
        cameraPreviewView.viewWithTag(ViewTag.arGuidanceLine.rawValue)?.removeFromSuperview()
    }
    

    /// 添加四角装饰线条
    /// - Parameters:
    ///   - view: 目标视图
    ///   - color: 装饰线条颜色（默认白色用于参考框）
    func addCornerDecorations(to view: UIView, color: UIColor = .white) {
        let cornerLength: CGFloat = 20
        let cornerWidth: CGFloat = 3
        let corners: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0, y: 0), CGPoint(x: cornerLength, y: 0)),
            (CGPoint(x: 0, y: 0), CGPoint(x: 0, y: cornerLength)),
            (CGPoint(x: view.bounds.width, y: 0), CGPoint(x: view.bounds.width - cornerLength, y: 0)),
            (CGPoint(x: view.bounds.width, y: 0), CGPoint(x: view.bounds.width, y: cornerLength)),
            (CGPoint(x: 0, y: view.bounds.height), CGPoint(x: cornerLength, y: view.bounds.height)),
            (CGPoint(x: 0, y: view.bounds.height), CGPoint(x: 0, y: view.bounds.height - cornerLength)),
            (CGPoint(x: view.bounds.width, y: view.bounds.height), CGPoint(x: view.bounds.width - cornerLength, y: view.bounds.height)),
            (CGPoint(x: view.bounds.width, y: view.bounds.height), CGPoint(x: view.bounds.width, y: view.bounds.height - cornerLength))
        ]
        
        for (start, end) in corners {
            let line = UIView()
            line.backgroundColor = color
            view.addSubview(line)
            
            if start.x == end.x {
                line.frame = CGRect(x: start.x - cornerWidth/2, y: min(start.y, end.y), width: cornerWidth, height: abs(end.y - start.y))
            } else {
                line.frame = CGRect(x: min(start.x, end.x), y: start.y - cornerWidth/2, width: abs(end.x - start.x), height: cornerWidth)
            }
        }
    }
    
    /// 更新检测到的人物框和引导元素
    /// 新需求：白色固定框在中心（80x120），绿色动态框跟随检测到的人物（略小）
    func updateDetectedPersonFrame(_ boundingBox: BoundingBox, isAligned: Bool) {
        // 移除旧的绿色动态检测框和连线（保留白色固定框）
        cameraPreviewView.viewWithTag(ViewTag.personDetectionFrame.rawValue)?.removeFromSuperview()
        cameraPreviewView.viewWithTag(ViewTag.arGuidanceLine.rawValue)?.removeFromSuperview()
        
        LMLogger.log("📊 Detected bbox: (\(String(format: "%.3f", boundingBox.x)), \(String(format: "%.3f", boundingBox.y))) size: \(String(format: "%.3f", boundingBox.width))x\(String(format: "%.3f", boundingBox.height))")
        
        // 创建绿色动态检测框（比白色框略小：70x105）
        let previewBounds = cameraPreviewView.bounds
        let detectedX = boundingBox.x * Double(previewBounds.width)
        let detectedY = boundingBox.y * Double(previewBounds.height)
        let detectedWidth = boundingBox.width * Double(previewBounds.width)
        let detectedHeight = boundingBox.height * Double(previewBounds.height)
        
        // 计算绿色框的尺寸（固定为70x105，保持宽高比与白色框一致）
        let greenFrameWidth: CGFloat = 70
        let greenFrameHeight: CGFloat = 105
        
        // 绿色框的中心点与检测到的人物中心点对齐
        let detectedCenterX = detectedX + detectedWidth / 2.0
        let detectedCenterY = detectedY + detectedHeight / 2.0
        
        let greenFrame = UIView()
        greenFrame.tag = ViewTag.personDetectionFrame.rawValue
        greenFrame.backgroundColor = .clear
        greenFrame.layer.borderWidth = 2
        greenFrame.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.8).cgColor
        greenFrame.layer.cornerRadius = 8
        greenFrame.frame = CGRect(
            x: detectedCenterX - Double(greenFrameWidth)/2.0,
            y: detectedCenterY - Double(greenFrameHeight)/2.0,
            width: Double(greenFrameWidth),
            height: Double(greenFrameHeight)
        )
        
        cameraPreviewView.addSubview(greenFrame)
        LMLogger.log("✅ Green dynamic frame added at (\(String(format: "%.1f", detectedCenterX)), \(String(format: "%.1f", detectedCenterY))) size: \(greenFrameWidth)x\(greenFrameHeight)")
        
        // 绘制从白色固定框到绿色动态框的连线
        drawGuidanceLineFromCenterToDetected(detectedCenter: CGPoint(x: detectedCenterX, y: detectedCenterY), isAligned: isAligned)
        
        if isAligned {
            showAlignmentFeedback()
        }
    }
    

    /// 绘制从白色固定框（屏幕中心）到绿色动态框的连线
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
        lineLayer.strokeColor = (isAligned ? UIColor.systemGreen : UIColor.systemYellow).withAlphaComponent(0.8).cgColor
        lineLayer.lineWidth = 3
        lineLayer.lineDashPattern = [8, 4] // 虚线样式
        lineLayer.lineCap = .round
        
        lineContainer.layer.addSublayer(lineLayer)
        
        // 在白色固定框中点添加圆点标记
        let whiteDot = createCenterDot(at: whiteCenter, color: .white)
        lineContainer.addSubview(whiteDot)
        
        // 在绿色动态框中点添加圆点标记
        let greenDot = createCenterDot(at: detectedCenter, color: .systemGreen)
        lineContainer.addSubview(greenDot)
        
        // 添加到预览视图（在检测框下方）
        cameraPreviewView.insertSubview(lineContainer, at: 0)
        
        // 计算距离并显示提示
        let distance = sqrt(pow(whiteCenter.x - detectedCenter.x, 2) + pow(whiteCenter.y - detectedCenter.y, 2))
        LMLogger.log("📏 Guidance line drawn - Distance: \(String(format: "%.1f", distance))px, Aligned: \(isAligned)")
    }
    
    /// 创建中点标记圆点
    func createCenterDot(at point: CGPoint, color: UIColor) -> UIView {
        let dotSize: CGFloat = 12
        let dot = UIView(frame: CGRect(x: point.x - dotSize/2, y: point.y - dotSize/2, width: dotSize, height: dotSize))
        dot.backgroundColor = color.withAlphaComponent(0.9)
        dot.layer.cornerRadius = dotSize / 2
        dot.layer.borderWidth = 2
        dot.layer.borderColor = UIColor.white.cgColor
        
        // 添加脉动动画
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = 1.0
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.3
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .infinity
        dot.layer.add(pulseAnimation, forKey: "pulse")
        
        return dot
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
    
    /// 处理AR引导的视频帧
    func processARGuidanceFrame(_ sampleBuffer: CMSampleBuffer) {
        guard isARGuidanceActive else { return }
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
    
    func personDetectionManager(_ manager: LMPersonDetectionManager, didFailWithError error: Error) {
        LMLogger.log("❌ Person detection failed: \(error.localizedDescription)")
    }
}
