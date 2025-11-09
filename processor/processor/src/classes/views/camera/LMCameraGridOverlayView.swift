//
//  LMCameraGridOverlayView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit

class LMCameraGridOverlayView: UIView {
    
    // MARK: - Properties
    private let lineColor = UIColor.white
    private let lineWidth: CGFloat = 1.0
    private let lineOpacity: Float = 0.6
    private let animationDuration: TimeInterval = 0.3
    private var isGridVisible = false
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if isGridVisible {
            drawGridLines()
        }
    }
    
    // MARK: - Setup
    private func setupView() {
        backgroundColor = .clear
        alpha = 0
        isUserInteractionEnabled = false
    }
}

// MARK: - Grid Drawing
extension LMCameraGridOverlayView {
    
    private func drawGridLines() {
        clearGridLines()
        
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        // 绘制三分法网格（2条垂直线 + 2条水平线）
        let verticalX1 = bounds.width / 3
        let verticalX2 = bounds.width * 2 / 3
        let horizontalY1 = bounds.height / 3
        let horizontalY2 = bounds.height * 2 / 3
        
        drawLine(from: CGPoint(x: verticalX1, y: 0), to: CGPoint(x: verticalX1, y: bounds.height))
        drawLine(from: CGPoint(x: verticalX2, y: 0), to: CGPoint(x: verticalX2, y: bounds.height))
        drawLine(from: CGPoint(x: 0, y: horizontalY1), to: CGPoint(x: bounds.width, y: horizontalY1))
        drawLine(from: CGPoint(x: 0, y: horizontalY2), to: CGPoint(x: bounds.width, y: horizontalY2))
    }
    
    private func clearGridLines() {
        layer.sublayers?.removeAll { $0 is CAShapeLayer }
    }
    
    private func drawLine(from start: CGPoint, to end: CGPoint) {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        
        let lineLayer = CAShapeLayer()
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = lineColor.cgColor
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = lineWidth
        lineLayer.opacity = lineOpacity
        
        layer.addSublayer(lineLayer)
    }
}



// MARK: - Public Methods
extension LMCameraGridOverlayView {
    
    /// 显示网格
    func showGrid(animated: Bool = true) {
        guard !isGridVisible else { return }
        
        isGridVisible = true
        drawGridLines()
        
        if animated {
            UIView.animate(withDuration: animationDuration) {
                self.alpha = 1.0
            }
        } else {
            alpha = 1.0
        }
    }
    
    /// 隐藏网格
    func hideGrid(animated: Bool = true) {
        guard isGridVisible else { return }
        
        isGridVisible = false
        
        if animated {
            UIView.animate(withDuration: animationDuration, animations: {
                self.alpha = 0.0
            }) { _ in
                self.clearGridLines()
            }
        } else {
            alpha = 0.0
            clearGridLines()
        }
    }
    
    /// 切换网格显示状态
    func toggleGrid(animated: Bool = true) {
        if isGridVisible {
            hideGrid(animated: animated)
        } else {
            showGrid(animated: animated)
        }
    }
    
    /// 获取当前网格显示状态
    func isGridCurrentlyVisible() -> Bool {
        return isGridVisible
    }
    
    /// 配置为摄影三分法网格（默认配置）
    func configureForPhotographyRuleOfThirds() {
        // 已经是默认配置，无需额外操作
    }
}