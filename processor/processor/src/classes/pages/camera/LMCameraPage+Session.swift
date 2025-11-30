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
                isUsingFrontCamera = false // 确保初始状态为后摄
                
                // 初始化时更新Inspire Me按钮状态
                DispatchQueue.main.async { [weak self] in
                    self?.updateInspireMeButtonState()
                }
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
            
            // 启用 Live Photo 捕获功能（如果设备支持）
            if photoOutput.isLivePhotoCaptureSupported {
                photoOutput.isLivePhotoCaptureEnabled = true
                LMLogger.log("✅ Live Photo capture enabled")
            } else {
                LMLogger.log("⚠️ Live Photo capture not supported on this device")
            }
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
        guard let captureSession = captureSession else {
            LMLogger.log("❌ Capture session not available")
            return
        }
        
        // 在后台线程执行相机切换，避免阻塞主线程
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            captureSession.beginConfiguration()
            
            // 移除当前输入
            if let currentInput = captureSession.inputs.first as? AVCaptureDeviceInput {
                captureSession.removeInput(currentInput)
            }
            
            // 确定新的相机位置
            let newPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .back : .front
            
            // 获取新相机设备
            guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
                LMLogger.log("❌ Unable to access \(newPosition == .front ? "front" : "back") camera")
                captureSession.commitConfiguration()
                return
            }
            
            do {
                let newInput = try AVCaptureDeviceInput(device: newCamera)
                if captureSession.canAddInput(newInput) {
                    captureSession.addInput(newInput)
                    
                    // 在主线程更新 UI 相关的状态
                    DispatchQueue.main.async {
                        self.currentCameraDevice = newCamera
                        self.isUsingFrontCamera.toggle()
                        self.updateInspireMeButtonState()
                        
                        LMLogger.log("✅ Camera switched to \(self.isUsingFrontCamera ? "front" : "back")")
                    }
                } else {
                    LMLogger.log("❌ Cannot add new camera input")
                }
            } catch {
                LMLogger.log("❌ Error switching camera: \(error)")
            }
            
            captureSession.commitConfiguration()
        }
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
            inspireMeButtonView.setInspireMeButtonEnabled(false)
            LMLogger.log("📷 Front camera: Inspire Me button disabled")
        } else {
            inspireMeButtonView.setInspireMeButtonEnabled(true)
            LMLogger.log("📷 Back camera: Inspire Me button enabled")
        }
    }
}
