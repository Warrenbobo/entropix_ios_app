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
        guard let suggestion = currentSuggestion else {
            LMLogger.log("⚠️ No suggestion selected, cannot start AR guidance")
            showError("Please select a composition suggestion first")
            cameraBottomControlsView.setARGuidanceEnabled(false)
            return
        }
        
        guard let targetBox = suggestion.personBoundingBox else {
            LMLogger.log("⚠️ No person bounding box in suggestion")
            showError("This suggestion doesn't support AR guidance")
            cameraBottomControlsView.setARGuidanceEnabled(false)
            return
        }
        
        // 检查横竖方向是否一致（PRD 3.16.3.4）
        if !checkOrientationCompatibility(targetBox: targetBox) {
            LMLogger.log("⚠️ Orientation mismatch: suggestion and camera have different orientations")
            showError("Please rotate your device to match the reference photo orientation")
            cameraBottomControlsView.setARGuidanceEnabled(false)
            return
        }
        
        if personDetectionManager == nil {
            personDetectionManager = LMPersonDetectionManager()
            personDetectionManager?.delegate = self
        }
        
        personDetectionManager?.startDetection()
        isARGuidanceActive = true
        
        showARGuidanceOverlay()
        
        LMLogger.log("✅ AR guidance session started")
    }
    
    /// 检查参考图与取景方向是否一致
    /// PRD 3.16.3.4: 若横竖宽高方向不一致，则bbox和连线不显示
    func checkOrientationCompatibility(targetBox: BoundingBox) -> Bool {
        // 获取参考图的方向（通过 bbox 的宽高比判断）
        let targetIsPortrait = targetBox.height > targetBox.width
        
        // 获取当前相机预览的方向
        let previewBounds = cameraPreviewView.bounds
        let cameraIsPortrait = previewBounds.height > previewBounds.width
        
        // 方向必须一致
        let isCompatible = targetIsPortrait == cameraIsPortrait
        
        LMLogger.log("📐 Orientation check - Target: \(targetIsPortrait ? "Portrait" : "Landscape"), Camera: \(cameraIsPortrait ? "Portrait" : "Landscape"), Compatible: \(isCompatible)")
        
        return isCompatible
    }
    
    func stopARGuidanceSession() {
        personDetectionManager?.stopDetection()
        isARGuidanceActive = false
        
        hideARGuidanceOverlay()
        
        LMLogger.log("✅ AR guidance session stopped")
    }
    
    func showARGuidanceOverlay() {
        guard let suggestion = currentSuggestion,
              let targetBox = suggestion.personBoundingBox else {
            return
        }
        
        let guidanceFrame = createGuidanceFrame(for: targetBox)
        guidanceFrame.tag = ViewTag.arGuidanceFrame.rawValue
        cameraPreviewView.addSubview(guidanceFrame)
        
        let hintLabel = UILabel()
        hintLabel.text = LMText.camera.alignPersonFrame
        hintLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        hintLabel.textColor = .white
        hintLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        hintLabel.textAlignment = .center
        hintLabel.layer.cornerRadius = 8
        hintLabel.clipsToBounds = true
        hintLabel.tag = ViewTag.arHintLabel.rawValue
        
        cameraPreviewView.addSubview(hintLabel)
        
        hintLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(100)
            make.height.equalTo(32)
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
        }
    }
    
    func hideARGuidanceOverlay() {
        cameraPreviewView.viewWithTag(ViewTag.arGuidanceFrame.rawValue)?.removeFromSuperview()
        cameraPreviewView.viewWithTag(ViewTag.arHintLabel.rawValue)?.removeFromSuperview()
        cameraPreviewView.viewWithTag(ViewTag.personDetectionFrame.rawValue)?.removeFromSuperview()
        cameraPreviewView.viewWithTag(ViewTag.arGuidanceLine.rawValue)?.removeFromSuperview()
    }
    
    func createGuidanceFrame(for boundingBox: BoundingBox) -> UIView {
        let frame = UIView()
        frame.backgroundColor = .clear
        frame.layer.borderWidth = 3
        frame.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.8).cgColor
        frame.layer.cornerRadius = 12
        
        addCornerDecorations(to: frame)
        
        let previewBounds = cameraPreviewView.bounds
        let x = boundingBox.x * Double(previewBounds.width)
        let y = boundingBox.y * Double(previewBounds.height)
        let width = boundingBox.width * Double(previewBounds.width)
        let height = boundingBox.height * Double(previewBounds.height)
        
        frame.frame = CGRect(x: x, y: y, width: width, height: height)
        
        return frame
    }
    
    func addCornerDecorations(to view: UIView) {
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
            line.backgroundColor = .systemGreen
            view.addSubview(line)
            
            if start.x == end.x {
                line.frame = CGRect(x: start.x - cornerWidth/2, y: min(start.y, end.y), width: cornerWidth, height: abs(end.y - start.y))
            } else {
                line.frame = CGRect(x: min(start.x, end.x), y: start.y - cornerWidth/2, width: abs(end.x - start.x), height: cornerWidth)
            }
        }
    }
    
    func updateDetectedPersonFrame(_ boundingBox: BoundingBox, isAligned: Bool) {
        // 移除旧的检测框和连线
        cameraPreviewView.viewWithTag(ViewTag.personDetectionFrame.rawValue)?.removeFromSuperview()
        cameraPreviewView.viewWithTag(ViewTag.arGuidanceLine.rawValue)?.removeFromSuperview()
        
        // 创建实时检测的人物框（蓝色/绿色）
        let frame = UIView()
        frame.tag = ViewTag.personDetectionFrame.rawValue
        frame.backgroundColor = .clear
        frame.layer.borderWidth = 2
        frame.layer.borderColor = (isAligned ? UIColor.systemGreen : UIColor.systemBlue).withAlphaComponent(0.8).cgColor
        frame.layer.cornerRadius = 8
        
        let previewBounds = cameraPreviewView.bounds
        let x = boundingBox.x * Double(previewBounds.width)
        let y = boundingBox.y * Double(previewBounds.height)
        let width = boundingBox.width * Double(previewBounds.width)
        let height = boundingBox.height * Double(previewBounds.height)
        
        frame.frame = CGRect(x: x, y: y, width: width, height: height)
        cameraPreviewView.addSubview(frame)
        
        // 绘制中点连线（PRD 3.16.3.4）
        if let targetBox = currentSuggestion?.personBoundingBox {
            drawGuidanceLine(from: targetBox, to: boundingBox, isAligned: isAligned)
        }
        
        if isAligned {
            showAlignmentFeedback()
        }
    }
    
    /// 绘制从参考框到实时检测框的中点连线
    /// PRD 3.16.3.4: 计算两个bbox框的中点，显示位置指导连线
    func drawGuidanceLine(from targetBox: BoundingBox, to detectedBox: BoundingBox, isAligned: Bool) {
        let previewBounds = cameraPreviewView.bounds
        
        // 计算参考框（白色静止框）的中点
        let targetCenterX = (targetBox.x + targetBox.width / 2.0) * Double(previewBounds.width)
        let targetCenterY = (targetBox.y + targetBox.height / 2.0) * Double(previewBounds.height)
        let targetCenter = CGPoint(x: targetCenterX, y: targetCenterY)
        
        // 计算实时检测框的中点
        let detectedCenterX = (detectedBox.x + detectedBox.width / 2.0) * Double(previewBounds.width)
        let detectedCenterY = (detectedBox.y + detectedBox.height / 2.0) * Double(previewBounds.height)
        let detectedCenter = CGPoint(x: detectedCenterX, y: detectedCenterY)
        
        // 创建连线容器视图
        let lineContainer = UIView()
        lineContainer.tag = ViewTag.arGuidanceLine.rawValue
        lineContainer.backgroundColor = .clear
        lineContainer.frame = previewBounds
        
        // 使用 CAShapeLayer 绘制连线
        let linePath = UIBezierPath()
        linePath.move(to: targetCenter)
        linePath.addLine(to: detectedCenter)
        
        let lineLayer = CAShapeLayer()
        lineLayer.path = linePath.cgPath
        lineLayer.strokeColor = (isAligned ? UIColor.systemGreen : UIColor.systemYellow).withAlphaComponent(0.8).cgColor
        lineLayer.lineWidth = 3
        lineLayer.lineDashPattern = [8, 4] // 虚线样式
        lineLayer.lineCap = .round
        
        lineContainer.layer.addSublayer(lineLayer)
        
        // 在参考框中点添加圆点标记
        let targetDot = createCenterDot(at: targetCenter, color: .systemGreen)
        lineContainer.addSubview(targetDot)
        
        // 在实时检测框中点添加圆点标记
        let detectedDot = createCenterDot(at: detectedCenter, color: isAligned ? .systemGreen : .systemBlue)
        lineContainer.addSubview(detectedDot)
        
        // 添加到预览视图（在检测框下方）
        cameraPreviewView.insertSubview(lineContainer, at: 0)
        
        // 计算距离并显示提示
        let distance = sqrt(pow(targetCenter.x - detectedCenter.x, 2) + pow(targetCenter.y - detectedCenter.y, 2))
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
        guard let targetBox = currentSuggestion?.personBoundingBox else {
            return
        }
        
        // 再次检查方向兼容性（防止设备旋转）
        guard checkOrientationCompatibility(targetBox: targetBox) else {
            // 方向不兼容，停止 AR 引导
            DispatchQueue.main.async { [weak self] in
                self?.stopARGuidanceSession()
                self?.cameraBottomControlsView.setARGuidanceEnabled(false)
                self?.showError("Device orientation changed. Please rotate to match the reference photo.")
            }
            return
        }
        
        let alignment = LMPersonDetectionManager.calculateAlignment(
            between: result.boundingBox,
            and: targetBox
        )
        
        let isAligned = alignment >= 0.7
        
        DispatchQueue.main.async { [weak self] in
            self?.updateDetectedPersonFrame(result.boundingBox, isAligned: isAligned)
        }
        
        if isAligned {
            LMLogger.log("✅ Person aligned! Alignment score: \(String(format: "%.2f", alignment))")
        }
    }
    
    func personDetectionManager(_ manager: LMPersonDetectionManager, didFailWithError error: Error) {
        LMLogger.log("❌ Person detection failed: \(error.localizedDescription)")
    }
}
