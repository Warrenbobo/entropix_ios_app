//
//  LMARGuidanceView.swift
//  processor
//
//  Created by Kiro on 2025-01-XX.
//

import UIKit

/// AR引导视图 - 显示人物检测的白色校准框和绿色成功框
/// 注意：蓝色框（livePersonBox）已分离到独立的视图中（在LMCameraPage中），不在此View内
/// 这是因为此View会随设备方向旋转，而蓝色框需要保持固定方向（跟随相机预览）
class LMARGuidanceView: UIView {
    
    // MARK: - Properties

    private let lineArtImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleToFill
        imageView.alpha = 0.32
        imageView.isHidden = true
        imageView.isUserInteractionEnabled = false
        return imageView
    }()
    
    /// 白色静态框（Reference Image中的人物位置）
    private var referencePersonBox: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()
    
    /// 绿色成功框（对齐成功时显示）
    var successBox: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()
    
    /// 成功对号图标（在绿框中心显示，3秒后消失）
    private var successCheckmark: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGreen
        imageView.image = UIImage(systemName: "checkmark.circle.fill")
        imageView.isHidden = true
        return imageView
    }()
    
    /// 方向匹配状态
    private var isOrientationMatched: Bool = false
    
    // MARK: - Size Constants
    
    /// 白色框尺寸（基于屏幕宽度计算）
    private var referenceBoxSize: CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let width = screenWidth * 2.0 / 5.0
        let height = width * 1.1
        return CGSize(width: width, height: height)
    }
    
    /// 框的最小尺寸（防止圆角重叠）
    /// 圆角半径为 18，每个角的长度为 24，最小尺寸应为 cornerLength * 2 = 48
    /// 为了更好的视觉效果，设置为 60
    private let minimumBoxSize: CGFloat = 60
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // 设置视图不拦截触摸事件
        isUserInteractionEnabled = false
        backgroundColor = .clear
        
        // 1. 设置白色框的固定尺寸和图层
        let refSize = referenceBoxSize
        referencePersonBox.bounds = CGRect(origin: .zero, size: refSize)
        createAndSetupFrameLayers(
            for: referencePersonBox,
            color: .white,
            lineWidth: 3.0,
            crosshairLength: 8,
            crosshairWidth: 3
        )
        
        // 2. 设置绿色成功框的固定尺寸和图层（与白色框相同）
        successBox.bounds = CGRect(origin: .zero, size: refSize)
        createAndSetupFrameLayers(
            for: successBox,
            color: .systemGreen,
            lineWidth: 3.0,
            crosshairLength: 8,
            crosshairWidth: 3
        )
        
        // 3. 添加子视图到视图层级（不包含引导线，引导线已移到外部管理）
        addSubview(lineArtImageView)
        addSubview(referencePersonBox)
        addSubview(successBox)
        addSubview(successCheckmark)
        
        referencePersonBox.center = CGPoint(x: -1000, y: -1000)
        successBox.center = CGPoint(x: -1000, y: -1000)
        
        // 设置对号图标尺寸
        successCheckmark.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        successCheckmark.center = CGPoint(x: -1000, y: -1000)
        
        print("[AR Guidance] 初始化完成 - 白色框尺寸: \(refSize)")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        lineArtImageView.frame = bounds
    }
    
    // MARK: - Public Methods - Reference Box (白色静态框)
    
    /// 设置白色框的位置（Reference Image中检测到的人物位置）
    /// - Parameter position: 中心点位置
    func setReferenceBoxPosition(position: CGPoint) {
        referencePersonBox.center = position
        referencePersonBox.transform = .identity
        self.showReferenceBox()
        
        print("[AR Guidance View] 设置白色校准框位置 - position: \(position), bounds: \(referencePersonBox.bounds), frame: \(referencePersonBox.frame)")
    }
    
    /// 设置白色框的完整 bbox（位置和尺寸）
    /// - Parameter bbox: 画布坐标系统下的边界框
    func setReferenceBoxBounds(bbox: CGRect) {
        // 清除之前的图层
        referencePersonBox.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        // 应用最小尺寸限制，防止圆角重叠
        let constrainedWidth = max(bbox.size.width, minimumBoxSize)
        let constrainedHeight = max(bbox.size.height, minimumBoxSize)
        let constrainedSize = CGSize(width: constrainedWidth, height: constrainedHeight)
        
        // 设置新的 bounds 和 center
        referencePersonBox.bounds = CGRect(origin: .zero, size: constrainedSize)
        referencePersonBox.center = CGPoint(x: bbox.midX, y: bbox.midY)
        referencePersonBox.transform = .identity  // 重置旋转
        
        // 重新创建图层（基于新的 bounds）
        createAndSetupFrameLayers(
            for: referencePersonBox,
            color: .white,
            lineWidth: 3.0,
            crosshairLength: 8,
            crosshairWidth: 3
        )
        
        // 注意：不在这里调用 showReferenceBox()
        // 让外部在设置完旋转后再调用 showReferenceBox()
        
        print("[AR Guidance View] 设置白色校准框 bbox - original: \(bbox.size), constrained: \(constrainedSize), frame: \(referencePersonBox.frame)")
    }
    
    /// 旋转白色校准框
    /// - Parameter angle: 旋转角度（弧度），正值为顺时针旋转
    func rotateReferenceBox(angle: CGFloat) {
        // 以中心点为基准旋转
        referencePersonBox.transform = CGAffineTransform(rotationAngle: angle)
        
        print("[AR Guidance View] 旋转白色校准框 - angle: \(angle) radians (\(angle * 180 / .pi) degrees)")
        print("  - center: \(referencePersonBox.center)")
        print("  - bounds: \(referencePersonBox.bounds)")
        print("  - frame: \(referencePersonBox.frame)")
    }
    
    /// 显示白色框
    func showReferenceBox() {
        referencePersonBox.isHidden = false
        referencePersonBox.alpha = 1.0  // 确保 alpha 为 1
        
        print("[AR Guidance View] 显示白色校准框")
        print("  - isHidden: \(referencePersonBox.isHidden)")
        print("  - alpha: \(referencePersonBox.alpha)")
        print("  - frame: \(referencePersonBox.frame)")
        print("  - bounds: \(referencePersonBox.bounds)")
        print("  - center: \(referencePersonBox.center)")
        print("  - transform: \(referencePersonBox.transform)")
        print("  - superview: \(referencePersonBox.superview != nil)")
        print("  - layer.sublayers count: \(referencePersonBox.layer.sublayers?.count ?? 0)")
        
        // 检查图层是否存在
        if let sublayers = referencePersonBox.layer.sublayers {
            for (index, layer) in sublayers.enumerated() {
                print("  - Layer \(index): \(layer.name ?? "unnamed"), isHidden: \(layer.isHidden), opacity: \(layer.opacity)")
            }
        }
    }
    
    /// 隐藏白色框
    func hideReferenceBox() {
        referencePersonBox.isHidden = true
    }
    
    /// 获取白色框的中心点（用于外部计算引导线）
    /// - Returns: 白色框在本视图坐标系中的中心点
    func getReferenceBoxCenter() -> CGPoint {
        return referencePersonBox.center
    }
    
    /// 获取白色框是否隐藏
    func isReferenceBoxHidden() -> Bool {
        return referencePersonBox.isHidden
    }
    
    // MARK: - Public Methods - Success Box (绿色成功框)
    
    /// 显示绿色成功框（复用白色框的位置和尺寸，绿框常驻，对号图标3秒后消失）
    func showSuccessBox() {
        // 清除之前的图层
        successBox.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        // 复用白色框的 bounds（尺寸）
        successBox.bounds = referencePersonBox.bounds
        
        // 复用白色框的 center（位置）
        successBox.center = referencePersonBox.center
        
        // 复用白色框的 transform（旋转）
        successBox.transform = referencePersonBox.transform
        
        // 重新创建绿色框的图层（基于新的 bounds）
        createAndSetupFrameLayers(
            for: successBox,
            color: .systemGreen,
            lineWidth: 3.0,
            crosshairLength: 8,
            crosshairWidth: 3
        )
        
        // 显示绿色框（常驻）
        successBox.isHidden = false
        successBox.alpha = 1.0
        
        // 隐藏白色框（蓝色框和引导线由外部控制）
        referencePersonBox.isHidden = true
        
        // 设置对号图标位置（在绿框中心）
        successCheckmark.center = successBox.center
        successCheckmark.isHidden = false
        successCheckmark.alpha = 1.0
        
        print("[AR Guidance] 显示绿色成功框 - bounds: \(successBox.bounds), center: \(successBox.center)")
        
        // 3秒后只隐藏对号图标，绿框保持显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.hideSuccessCheckmark()
        }
    }
    
    /// 隐藏对号图标（绿框保持显示）
    private func hideSuccessCheckmark() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.successCheckmark.alpha = 0
        } completion: { [weak self] _ in
            self?.successCheckmark.isHidden = true
            self?.successCheckmark.alpha = 1.0  // 重置alpha以便下次显示
            print("[AR Guidance] 隐藏对号图标，绿框保持显示")
        }
    }
    
    /// 隐藏绿色成功框（完全隐藏，包括绿框和对号）
    func hideSuccessBox() {
        UIView.animate(withDuration: 0.3) { [weak self] in
            self?.successBox.alpha = 0
            self?.successCheckmark.alpha = 0
        } completion: { [weak self] _ in
            self?.successBox.isHidden = true
            self?.successBox.alpha = 1.0  // 重置alpha以便下次显示
            self?.successCheckmark.isHidden = true
            self?.successCheckmark.alpha = 1.0
            print("[AR Guidance] 隐藏绿色成功框")
        }
    }

    func setLineArtImage(_ image: UIImage?) {
        lineArtImageView.image = image
        lineArtImageView.isHidden = image == nil || !isOrientationMatched
    }

    func clearLineArtImage() {
        lineArtImageView.image = nil
        lineArtImageView.isHidden = true
    }
    
    // MARK: - Private Helper Methods
    
    /// 创建并设置框的图层（四个圆角 + 中心准星）
    /// 注意：此方法只在首次设置 frame 时调用一次，图层基于 view.bounds 创建
    ///      后续使用 transform 移动时，图层会自动跟随，无需重新创建或更新
    /// - Parameters:
    ///   - view: 目标视图
    ///   - color: 颜色
    ///   - lineWidth: 线宽
    ///   - crosshairLength: 准星长度
    ///   - crosshairWidth: 准星宽度
    private func createAndSetupFrameLayers(
        for view: UIView,
        color: UIColor,
        lineWidth: CGFloat,
        crosshairLength: CGFloat,
        crosshairWidth: CGFloat
    ) {
        let bounds = view.bounds
        
        // 1. 创建并设置四个圆角图层（仅描边，不填充）
        let cornerLayer = CAShapeLayer()
        cornerLayer.name = "cornerLayer"
        cornerLayer.fillColor = UIColor.clear.cgColor
        cornerLayer.strokeColor = color.withAlphaComponent(0.9).cgColor
        cornerLayer.lineWidth = lineWidth
        cornerLayer.path = createCornerPath(in: bounds).cgPath
        view.layer.addSublayer(cornerLayer)
        
        // 2. 创建并设置中心准星图层（实心填充）
        let crosshairLayer = CAShapeLayer()
        crosshairLayer.name = "crosshairLayer"
        crosshairLayer.fillColor = color.cgColor
        crosshairLayer.strokeColor = UIColor.clear.cgColor
        crosshairLayer.path = createCrosshairPath(in: bounds, length: crosshairLength, width: crosshairWidth).cgPath
        view.layer.addSublayer(crosshairLayer)
        
        print("[AR Guidance] 创建图层 - bounds: \(bounds), color: \(color)")
    }
    
    /// 创建四个圆角路径（仅用于描边）
    /// - Parameter bounds: 框的边界
    /// - Returns: 四个圆角的路径
    private func createCornerPath(in bounds: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        
        // 参数定义
        let cornerLength: CGFloat = 24  // 每个角的长度
        let cornerRadius: CGFloat = 18  // 圆角半径
        
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
    private func createCrosshairPath(in bounds: CGRect, length: CGFloat, width: CGFloat) -> UIBezierPath {
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
    
    /// 设置方向匹配状态
    /// - Parameter matched: 是否匹配
    func setOrientationMatched(_ matched: Bool) {
        isOrientationMatched = matched
        lineArtImageView.isHidden = !matched || lineArtImageView.image == nil
        hideOrShowAllGuidance(!matched)
        print("[AR Guidance] 方向匹配 - \(matched)")
    }
    
    /// 隐藏所有引导元素（仅控制本视图内的元素，蓝色框和引导线由外部控制）
    /// 仅隐藏使用
    func hideOrShowAllGuidance(_ hidden: Bool = false) {
        lineArtImageView.isHidden = hidden || lineArtImageView.image == nil || !isOrientationMatched
        referencePersonBox.isHidden = hidden
        // 绿框和对号也需要隐藏
        if hidden {
            successBox.isHidden = true
            successCheckmark.isHidden = true
        }
        print("[AR Guidance] 所有引导元素 \(hidden ? "隐藏" : "显示")")
    }
}
