//
//  LMCameraPreviewView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import AVFoundation
import SnapKit

protocol LMCameraPreviewViewDelegate: AnyObject {
    func cameraPreviewViewDidTapToFocus(at point: CGPoint)
    func cameraPreviewViewDidPinchToZoom(scale: CGFloat)
}

class LMCameraPreviewView: UIView {
    
    // MARK: - UI Components
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let focusIndicatorView = UIView()
    private let gridOverlayView = LMCameraGridOverlayView()
    
    // MARK: - Properties
    weak var delegate: LMCameraPreviewViewDelegate?
    private var captureSession: AVCaptureSession?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCameraPreviewComponents()
        setupGestureRecognizers()
        configureLayoutConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
    

}

extension LMCameraPreviewView {
    
    private func setupCameraPreviewComponents() {
        backgroundColor = UIColor.black
        
        // 设置预览图层
        previewLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(previewLayer)
        
        // 设置焦点指示器
        setupFocusIndicatorView()
        
        // 设置网格覆盖层
        setupGridOverlayView()
    }
    
    private func setupFocusIndicatorView() {
        addSubview(focusIndicatorView)
        
        focusIndicatorView.backgroundColor = UIColor.clear
        focusIndicatorView.layer.borderWidth = 2
        focusIndicatorView.layer.borderColor = UIColor.systemYellow.cgColor
        focusIndicatorView.layer.cornerRadius = 4
        focusIndicatorView.alpha = 0
        focusIndicatorView.isUserInteractionEnabled = false
        
        focusIndicatorView.snp.makeConstraints { make in
            make.size.equalTo(80)
        }
    }
    
    private func setupGridOverlayView() {
        addSubview(gridOverlayView)
        
        gridOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 配置默认的三分法网格
        gridOverlayView.configureForPhotographyRuleOfThirds()
    }
    
    private func setupGestureRecognizers() {
        // 点击对焦手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapToFocusGesture(_:)))
        addGestureRecognizer(tapGesture)
        
        // 缩放手势
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchToZoomGesture(_:)))
        addGestureRecognizer(pinchGesture)
    }
    
    private func configureLayoutConstraints() {
        // 布局约束已在setupFocusIndicatorView和setupGridOverlayView中设置
    }
}

extension LMCameraPreviewView {
    
    @objc private func handleTapToFocusGesture(_ gesture: UITapGestureRecognizer) {
        let touchPoint = gesture.location(in: self)
        
        // 显示焦点指示器
        showFocusIndicatorAtPoint(touchPoint)
        
        // 通知代理
        delegate?.cameraPreviewViewDidTapToFocus(at: touchPoint)
    }
    
    @objc private func handlePinchToZoomGesture(_ gesture: UIPinchGestureRecognizer) {
        delegate?.cameraPreviewViewDidPinchToZoom(scale: gesture.scale)
        gesture.scale = 1.0
    }
    
    private func showFocusIndicatorAtPoint(_ point: CGPoint) {
        focusIndicatorView.center = point
        focusIndicatorView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        focusIndicatorView.alpha = 1.0
        
        UIView.animate(withDuration: 0.3, animations: {
            self.focusIndicatorView.transform = CGAffineTransform.identity
        }) { _ in
            UIView.animate(withDuration: 0.5, delay: 0.5, animations: {
                self.focusIndicatorView.alpha = 0
            })
        }
    }
}

extension LMCameraPreviewView {
    
    func configureCaptureSession(_ session: AVCaptureSession) {
        captureSession = session
        previewLayer.session = session
    }
    
    func toggleGridVisibility() {
        gridOverlayView.toggleGrid(animated: true)
    }
    
    func setGridVisibility(_ visible: Bool) {
        if visible {
            gridOverlayView.showGrid(animated: true)
        } else {
            gridOverlayView.hideGrid(animated: true)
        }
    }
    
    func convertPointToDeviceCoordinates(_ point: CGPoint) -> CGPoint {
        return previewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }
    
    func updatePreviewOrientation(_ orientation: AVCaptureVideoOrientation) {
        previewLayer.connection?.videoOrientation = orientation
    }
}
// MARK: - Grid Configuration Methods
extension LMCameraPreviewView {
    
    /// 获取当前网格显示状态
    func isGridCurrentlyVisible() -> Bool {
        return gridOverlayView.isGridCurrentlyVisible()
    }
    
    /// 配置为摄影三分法网格
    func configureForPhotographyRuleOfThirds() {
        gridOverlayView.configureForPhotographyRuleOfThirds()
    }
}