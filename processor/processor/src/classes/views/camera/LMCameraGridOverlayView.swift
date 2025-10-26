//
//  LMCameraGridOverlayView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

/// 相机网格线类型枚举
enum LMCameraGridType {
    case ruleOfThirds    // 三分法网格（3x3）
    case golden          // 黄金比例网格
    case square          // 正方形网格
    case diagonal        // 对角线网格
    case center          // 中心十字线
    case fibonacci       // 斐波那契螺旋网格
}

/// 相机网格线样式配置
struct LMCameraGridStyle {
    let lineColor: UIColor
    let lineWidth: CGFloat
    let lineDashPattern: [NSNumber]?
    let opacity: Float
    let animationDuration: TimeInterval
    
    static let `default` = LMCameraGridStyle(
        lineColor: UIColor.white,
        lineWidth: 1.0,
        lineDashPattern: nil,
        opacity: 0.6,
        animationDuration: 0.3
    )
    
    static let subtle = LMCameraGridStyle(
        lineColor: UIColor.white,
        lineWidth: 0.5,
        lineDashPattern: nil,
        opacity: 0.4,
        animationDuration: 0.3
    )
    
    static let bold = LMCameraGridStyle(
        lineColor: UIColor.systemYellow,
        lineWidth: 2.0,
        lineDashPattern: nil,
        opacity: 0.8,
        animationDuration: 0.3
    )
    
    static let dashed = LMCameraGridStyle(
        lineColor: UIColor.white,
        lineWidth: 1.0,
        lineDashPattern: [4, 4],
        opacity: 0.6,
        animationDuration: 0.3
    )
}

class LMCameraGridOverlayView: UIView {
    
    // MARK: - Properties
    private var gridType: LMCameraGridType = .ruleOfThirds
    private var gridStyle: LMCameraGridStyle = .default
    private var isGridVisible = false
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGridOverlayView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateGridLinesLayout()
    }
}

// MARK: - Grid Overlay Setup Methods
extension LMCameraGridOverlayView {
    
    private func setupGridOverlayView() {
        backgroundColor = UIColor.clear
        alpha = 0
        isUserInteractionEnabled = false
        clipsToBounds = true
    }
}

// MARK: - Grid Drawing Methods
extension LMCameraGridOverlayView {
    
    private func drawGridLines() {
        // 清除现有的网格线
        clearExistingGridLines()
        
        // 根据网格类型绘制相应的网格线
        switch gridType {
        case .ruleOfThirds:
            drawRuleOfThirdsGrid()
        case .golden:
            drawGoldenRatioGrid()
        case .square:
            drawSquareGrid()
        case .diagonal:
            drawDiagonalGrid()
        case .center:
            drawCenterCrossGrid()
        case .fibonacci:
            drawFibonacciGrid()
        }
    }
    
    private func clearExistingGridLines() {
        layer.sublayers?.removeAll { $0 is CAShapeLayer }
    }
    
    private func drawRuleOfThirdsGrid() {
        let bounds = self.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        // 垂直线（将宽度三等分）
        let verticalX1 = bounds.width / 3
        let verticalX2 = bounds.width * 2 / 3
        
        drawVerticalLine(at: verticalX1)
        drawVerticalLine(at: verticalX2)
        
        // 水平线（将高度三等分）
        let horizontalY1 = bounds.height / 3
        let horizontalY2 = bounds.height * 2 / 3
        
        drawHorizontalLine(at: horizontalY1)
        drawHorizontalLine(at: horizontalY2)
    }
    
    private func drawGoldenRatioGrid() {
        let bounds = self.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let goldenRatio: CGFloat = 1.618
        
        // 垂直黄金比例线
        let verticalX1 = bounds.width / goldenRatio
        let verticalX2 = bounds.width - verticalX1
        
        drawVerticalLine(at: verticalX1)
        drawVerticalLine(at: verticalX2)
        
        // 水平黄金比例线
        let horizontalY1 = bounds.height / goldenRatio
        let horizontalY2 = bounds.height - horizontalY1
        
        drawHorizontalLine(at: horizontalY1)
        drawHorizontalLine(at: horizontalY2)
    }
    
    private func drawSquareGrid() {
        let bounds = self.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let minDimension = min(bounds.width, bounds.height)
        let gridSize = minDimension / 4
        
        // 垂直线
        for i in 1..<4 {
            let x = CGFloat(i) * gridSize
            if x < bounds.width {
                drawVerticalLine(at: x)
            }
        }
        
        // 水平线
        for i in 1..<4 {
            let y = CGFloat(i) * gridSize
            if y < bounds.height {
                drawHorizontalLine(at: y)
            }
        }
    }
    
    private func drawDiagonalGrid() {
        let bounds = self.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        // 主对角线（左上到右下）
        drawDiagonalLine(from: CGPoint(x: 0, y: 0), to: CGPoint(x: bounds.width, y: bounds.height))
        
        // 副对角线（右上到左下）
        drawDiagonalLine(from: CGPoint(x: bounds.width, y: 0), to: CGPoint(x: 0, y: bounds.height))
        
        // 添加三分法线作为辅助
        drawRuleOfThirdsGrid()
    }
    
    private func drawCenterCrossGrid() {
        let bounds = self.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let centerX = bounds.width / 2
        let centerY = bounds.height / 2
        
        // 垂直中心线
        drawVerticalLine(at: centerX)
        
        // 水平中心线
        drawHorizontalLine(at: centerY)
    }
    
    private func drawFibonacciGrid() {
        let bounds = self.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        // 斐波那契比例：1, 1, 2, 3, 5, 8, 13...
        let fibRatios: [CGFloat] = [0.382, 0.618] // 基于黄金比例的简化版本
        
        // 垂直斐波那契线
        for ratio in fibRatios {
            let x1 = bounds.width * ratio
            let x2 = bounds.width * (1 - ratio)
            
            drawVerticalLine(at: x1)
            drawVerticalLine(at: x2)
        }
        
        // 水平斐波那契线
        for ratio in fibRatios {
            let y1 = bounds.height * ratio
            let y2 = bounds.height * (1 - ratio)
            
            drawHorizontalLine(at: y1)
            drawHorizontalLine(at: y2)
        }
        
        // 添加螺旋曲线（简化版）
        drawFibonacciSpiral()
    }
    
    private func drawFibonacciSpiral() {
        let bounds = self.bounds
        let centerX = bounds.width * 0.618
        let centerY = bounds.height * 0.382
        
        let spiralPath = UIBezierPath()
        let radius = min(bounds.width, bounds.height) * 0.3
        
        // 绘制简化的螺旋线
        for i in 0...100 {
            let angle = CGFloat(i) * 0.1
            let spiralRadius = radius * (1 + angle * 0.05)
            let x = centerX + spiralRadius * cos(angle)
            let y = centerY + spiralRadius * sin(angle)
            
            if i == 0 {
                spiralPath.move(to: CGPoint(x: x, y: y))
            } else {
                spiralPath.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        let spiralLayer = CAShapeLayer()
        spiralLayer.path = spiralPath.cgPath
        spiralLayer.strokeColor = gridStyle.lineColor.cgColor
        spiralLayer.fillColor = UIColor.clear.cgColor
        spiralLayer.lineWidth = gridStyle.lineWidth
        spiralLayer.opacity = gridStyle.opacity * 0.7 // 螺旋线稍微淡一些
        
        if let dashPattern = gridStyle.lineDashPattern {
            spiralLayer.lineDashPattern = dashPattern
        }
        
        layer.addSublayer(spiralLayer)
    }
}

// MARK: - Line Drawing Helper Methods
extension LMCameraGridOverlayView {
    
    private func drawVerticalLine(at x: CGFloat) {
        let bounds = self.bounds
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: 0))
        path.addLine(to: CGPoint(x: x, y: bounds.height))
        
        createLineLayer(with: path)
    }
    
    private func drawHorizontalLine(at y: CGFloat) {
        let bounds = self.bounds
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: bounds.width, y: y))
        
        createLineLayer(with: path)
    }
    
    private func drawDiagonalLine(from startPoint: CGPoint, to endPoint: CGPoint) {
        let path = UIBezierPath()
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        
        createLineLayer(with: path)
    }
    
    private func createLineLayer(with path: UIBezierPath) {
        let lineLayer = CAShapeLayer()
        lineLayer.path = path.cgPath
        lineLayer.strokeColor = gridStyle.lineColor.cgColor
        lineLayer.fillColor = UIColor.clear.cgColor
        lineLayer.lineWidth = gridStyle.lineWidth
        lineLayer.opacity = gridStyle.opacity
        
        if let dashPattern = gridStyle.lineDashPattern {
            lineLayer.lineDashPattern = dashPattern
        }
        
        layer.addSublayer(lineLayer)
    }
    
    private func updateGridLinesLayout() {
        if isGridVisible {
            drawGridLines()
        }
    }
}

// MARK: - Public Configuration Methods
extension LMCameraGridOverlayView {
    
    /// 设置网格类型
    func setGridType(_ type: LMCameraGridType) {
        gridType = type
        if isGridVisible {
            drawGridLines()
        }
    }
    
    /// 设置网格样式
    func setGridStyle(_ style: LMCameraGridStyle) {
        gridStyle = style
        if isGridVisible {
            drawGridLines()
        }
    }
    
    /// 显示网格
    func showGrid(animated: Bool = true) {
        guard !isGridVisible else { return }
        
        isGridVisible = true
        drawGridLines()
        
        if animated {
            UIView.animate(withDuration: gridStyle.animationDuration) {
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
            UIView.animate(withDuration: gridStyle.animationDuration, animations: {
                self.alpha = 0.0
            }) { _ in
                self.clearExistingGridLines()
            }
        } else {
            alpha = 0.0
            clearExistingGridLines()
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
    
    /// 获取当前网格类型
    func getCurrentGridType() -> LMCameraGridType {
        return gridType
    }
    
    /// 获取当前网格样式
    func getCurrentGridStyle() -> LMCameraGridStyle {
        return gridStyle
    }
}

// MARK: - Preset Configurations
extension LMCameraGridOverlayView {
    
    /// 配置为摄影三分法网格
    func configureForPhotographyRuleOfThirds() {
        setGridType(.ruleOfThirds)
        setGridStyle(.default)
    }
    
    /// 配置为专业摄影黄金比例网格
    func configureForProfessionalPhotography() {
        setGridType(.golden)
        setGridStyle(.subtle)
    }
    
    /// 配置为建筑摄影网格
    func configureForArchitecturalPhotography() {
        setGridType(.square)
        setGridStyle(.bold)
    }
    
    /// 配置为艺术摄影网格
    func configureForArtisticPhotography() {
        setGridType(.fibonacci)
        setGridStyle(.dashed)
    }
    
    /// 配置为简单中心对齐网格
    func configureForCenterAlignment() {
        setGridType(.center)
        setGridStyle(.subtle)
    }
}