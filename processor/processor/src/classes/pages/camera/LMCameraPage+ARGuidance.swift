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
        
        guard suggestion.personBoundingBox != nil else {
            LMLogger.log("⚠️ No person bounding box in suggestion")
            showError("This suggestion doesn't support AR guidance")
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
        cameraPreviewView.viewWithTag(ViewTag.personDetectionFrame.rawValue)?.removeFromSuperview()
        
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
        
        if isAligned {
            showAlignmentFeedback()
        }
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

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension LMCameraPage: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
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
