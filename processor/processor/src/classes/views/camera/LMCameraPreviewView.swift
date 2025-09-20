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
    
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let focusIndicatorView = UIView()
    private let gridOverlayView = UIView()
    
    weak var delegate: LMCameraPreviewViewDelegate?
    private var captureSession: AVCaptureSession?
    private var isGridVisible = false
    
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
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        if layer == gridOverlayView.layer {
            updateGridLinesLayout()
        }
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
        
        gridOverlayView.backgroundColor = UIColor.clear
        gridOverlayView.alpha = 0
        gridOverlayView.isUserInteractionEnabled = false
        
        gridOverlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        drawGridLinesInOverlayView()
    }
    
    private func drawGridLinesInOverlayView() {
        gridOverlayView.layer.sublayers?.removeAll()
        
        // 创建网格线
        let gridLineColor = UIColor.white.withAlphaComponent(0.5)
        let lineWidth: CGFloat = 1
        
        // 垂直线
        for i in 1...2 {
            let verticalLine = CALayer()
            verticalLine.backgroundColor = gridLineColor.cgColor
            gridOverlayView.layer.addSublayer(verticalLine)
        }
        
        // 水平线
        for i in 1...2 {
            let horizontalLine = CALayer()
            horizontalLine.backgroundColor = gridLineColor.cgColor
            gridOverlayView.layer.addSublayer(horizontalLine)
        }
    }
    
    private func updateGridLinesLayout() {
        guard let sublayers = gridOverlayView.layer.sublayers else { return }
        
        let bounds = gridOverlayView.bounds
        let lineWidth: CGFloat = 1
        
        // 更新垂直线位置
        for i in 0..<2 {
            let line = sublayers[i]
            let x = bounds.width / 3 * CGFloat(i + 1)
            line.frame = CGRect(x: x, y: 0, width: lineWidth, height: bounds.height)
        }
        
        // 更新水平线位置
        for i in 2..<4 {
            let line = sublayers[i]
            let y = bounds.height / 3 * CGFloat(i - 1)
            line.frame = CGRect(x: 0, y: y, width: bounds.width, height: lineWidth)
        }
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
        isGridVisible.toggle()
        
        UIView.animate(withDuration: 0.3) {
            self.gridOverlayView.alpha = self.isGridVisible ? 1.0 : 0.0
        }
    }
    
    func setGridVisibility(_ visible: Bool) {
        isGridVisible = visible
        
        UIView.animate(withDuration: 0.3) {
            self.gridOverlayView.alpha = visible ? 1.0 : 0.0
        }
    }
    
    func convertPointToDeviceCoordinates(_ point: CGPoint) -> CGPoint {
        return previewLayer.captureDevicePointConverted(fromLayerPoint: point)
    }
    
    func updatePreviewOrientation(_ orientation: AVCaptureVideoOrientation) {
        previewLayer.connection?.videoOrientation = orientation
    }
}
