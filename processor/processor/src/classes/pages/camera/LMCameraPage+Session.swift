//
//  LMCameraPage+Session.swift
//  processor
//
//  Camera session setup and management
//

import UIKit
import AVFoundation

// MARK: - Camera Session Management
extension LMCameraPage {
    
    func setupCameraSession() {
        captureSession = AVCaptureSession()
        
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        }
        
        setupCameraInput()
        setupPhotoOutput()
        
        captureSession.commitConfiguration()
        
        cameraPreviewView.configureCaptureSession(captureSession)
    }
    
    func setupCameraInput() {
        guard let captureSession = captureSession else { return }
        
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            LMLogger.log("❌ Unable to access back camera")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentCameraDevice = backCamera
            }
        } catch {
            LMLogger.log("❌ Error setting up camera input: \(error)")
        }
    }
    
    func setupPhotoOutput() {
        guard let captureSession = captureSession else { return }
        
        photoOutput = AVCapturePhotoOutput()
        
        if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
        
        setupVideoDataOutput()
    }
    
    func setupVideoDataOutput() {
        guard let captureSession = captureSession else { return }
        
        videoDataOutput = AVCaptureVideoDataOutput()
        
        guard let videoDataOutput = videoDataOutput else { return }
        
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        let videoQueue = DispatchQueue(label: "com.framaist.videoqueue", qos: .userInitiated)
        videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
    }
    
    func startCameraSession() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.startRunning()
        }
    }
    
    func stopCameraSession() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.stopRunning()
        }
    }
    
    func switchCameraPosition() {
        guard let captureSession = captureSession else { return }
        
        captureSession.beginConfiguration()
        
        if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
            captureSession.removeInput(currentInput)
        }
        
        let newPosition: AVCaptureDevice.Position = isUsingFrontCamera ? .back : .front
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            captureSession.commitConfiguration()
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                currentCameraDevice = newCamera
                isUsingFrontCamera.toggle()
                updateInspireMeButtonState()
            }
        } catch {
            LMLogger.log("❌ Error switching camera: \(error)")
        }
        
        captureSession.commitConfiguration()
    }
    
    func setDefaultCameraParameters() {
        cameraControlsView.updateFlashMode(.auto)
        cameraControlsView.updateAspectRatio(.ratio3_4)
        cameraControlsView.updateTimerDuration(.off)
        cameraControlsView.updateLivePhotoStatus(false)
        cameraControlsView.updateGridStatus(true)
        cameraPreviewView.setGridVisibility(true)
        
        LMLogger.log("📷 Camera default parameters set")
    }
    
    func updateInspireMeButtonState() {
        if isUsingFrontCamera {
            cameraBottomControlsView.setInspireMeButtonEnabled(false)
            LMLogger.log("📷 Front camera: Inspire Me button disabled")
        } else {
            cameraBottomControlsView.setInspireMeButtonEnabled(true)
            LMLogger.log("📷 Back camera: Inspire Me button enabled")
        }
    }
}
