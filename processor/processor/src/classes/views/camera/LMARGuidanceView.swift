//
//  LMARGuidanceView.swift
//  processor
//
//  Created by Kiro on 2025-01-XX.
//

import UIKit

/// AR引导视图 - 显示人物检测的校准框和引导线
class LMARGuidanceView: UIView {
    
    // MARK: - Properties
    
    /// 白色静态框（Reference Image中的人物位置）
    private var referencePersonBox: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()
    
    /// 蓝色动态框（实时检测的人物位置）
    /// 注意：设为internal以便外部检查isHidden状态
    var livePersonBox: UIView = {
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
    
    /// 连接线
    private var guidanceLine: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8).cgColor
        layer.lineWidth = 3.0
        layer.lineDashPattern = [2, 6]
        layer.lineCap = .round
        layer.isHidden = true
        return layer
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
    
    /// 蓝色框尺寸（白色框的 0.8 倍）
    private var liveBoxSize: CGSize {
        let refSize = referenceBoxSize
        return CGSize(width: refSize.width * 0.8, height: refSize.height * 0.8)
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
        
        // 2. 设置蓝色框的固定尺寸和图层
        let liveSize = liveBoxSize
        livePersonBox.bounds = CGRect(origin: .zero, size: liveSize)
        createAndSetupFrameLayers(
            for: livePersonBox,
            color: .systemBlue,
            lineWidth: 2.0,
            crosshairLength: 6,
            crosshairWidth: 2
        )
        
        // 3. 设置绿色成功框的固定尺寸和图层（与白色框相同）
        successBox.bounds = CGRect(origin: .zero, size: refSize)
        createAndSetupFrameLayers(
            for: successBox,
            color: .systemGreen,
            lineWidth: 3.0,
            crosshairLength: 8,
            crosshairWidth: 3
        )
        
        // 4. 添加子视图到视图层级
        addSubview(referencePersonBox)
        addSubview(livePersonBox)
        addSubview(successBox)
        addSubview(successCheckmark)
        layer.addSublayer(guidanceLine)
        
        referencePersonBox.center = CGPoint(x: -1000, y: -1000)
        livePersonBox.center = CGPoint(x: -1000, y: -1000)
        successBox.center = CGPoint(x: -1000, y: -1000)
        
        // 设置对号图标尺寸
        successCheckmark.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        successCheckmark.center = CGPoint(x: -1000, y: -1000)
        
        print("[AR Guidance] 初始化完成 - 白色框尺寸: \(refSize), 蓝色框尺寸: \(liveSize)")
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
    
    // MARK: - Public Methods - Live Box (蓝色动态框)
    
    /// 设置蓝色框的位置（首次显示时调用）
    /// 注意：尺寸和图层已在 setupViews 中创建，此方法只设置中心点位置
    /// - Parameter position: 中心点位置
    func setLiveBoxPosition(position: CGPoint) {
        // 只设置中心点位置（bounds 和图层已在 setupViews 中设置）
        livePersonBox.center = position
        livePersonBox.transform = .identity  // 重置 transform
        
        print("[AR Guidance] 设置蓝色校准框位置 - position: \(position)")
    }
    
    /// 旋转蓝色校准框
    /// - Parameter angle: 旋转角度（弧度），正值为顺时针旋转
    func rotateLiveBox(angle: CGFloat) {
        // 保存当前的 center，因为旋转可能会影响 frame
        let currentCenter = livePersonBox.center
        
        // 以中心点为基准旋转
        livePersonBox.transform = CGAffineTransform(rotationAngle: angle)
        
        // 确保 center 保持不变
        livePersonBox.center = currentCenter
        
        print("[AR Guidance View] 旋转蓝色校准框 - angle: \(angle) radians (\(angle * 180 / .pi) degrees)")
    }
    
    /// 移动蓝色框到新位置（直接更新center，高频调用）
    /// 注意：只移动位置，不改变尺寸
    /// - Parameter position: 目标中心点位置
    func moveLiveBoxToPosition(position: CGPoint) {
        // 直接更新center位置
        livePersonBox.center = position
        
        // 更新连接线
        updateGuidanceLine()
    }
    
    /// 设置蓝色框的完整 bounds（位置和尺寸）
    /// - Parameter bbox: 画布坐标系统下的边界框
    func setLiveBoxBounds(bbox: CGRect) {
        // 清除之前的图层
        livePersonBox.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        // 应用最小尺寸限制，防止圆角重叠
        let constrainedWidth = max(bbox.size.width, minimumBoxSize)
        let constrainedHeight = max(bbox.size.height, minimumBoxSize)
        let constrainedSize = CGSize(width: constrainedWidth, height: constrainedHeight)
        
        // 设置新的 bounds 和 center
        livePersonBox.bounds = CGRect(origin: .zero, size: constrainedSize)
        livePersonBox.center = CGPoint(x: bbox.midX, y: bbox.midY)
        livePersonBox.transform = .identity  // 重置旋转
        
        // 重新创建图层（基于新的 bounds）
        createAndSetupFrameLayers(
            for: livePersonBox,
            color: .systemBlue,
            lineWidth: 2.0,
            crosshairLength: 6,
            crosshairWidth: 2
        )
        
        print("[AR Guidance View] 设置蓝色框 bbox - original: \(bbox.size), constrained: \(constrainedSize), frame: \(livePersonBox.frame)")
    }
    
    /// 更新蓝色框的 bounds（高频调用，带动画）
    /// - Parameter bbox: 画布坐标系统下的边界框
    func updateLiveBoxBounds(bbox: CGRect) {
        // 应用最小尺寸限制，防止圆角重叠
        let constrainedWidth = max(bbox.size.width, minimumBoxSize)
        let constrainedHeight = max(bbox.size.height, minimumBoxSize)
        
        // 计算约束后的 frame（保持中心点不变）
        let constrainedFrame = CGRect(
            x: bbox.midX - constrainedWidth / 2,
            y: bbox.midY - constrainedHeight / 2,
            width: constrainedWidth,
            height: constrainedHeight
        )
        
        // 保存当前的 transform
        let currentTransform = self.livePersonBox.transform
        // 临时重置 transform 以便正确设置 frame
        self.livePersonBox.transform = .identity
        // 设置新的 frame
        self.livePersonBox.frame = constrainedFrame
        // 恢复 transform
        self.livePersonBox.transform = currentTransform
        self.updateGuidanceLine()
    }
    
    /// 显示蓝色框
    func showLiveBox() {
        livePersonBox.isHidden = false
    }
    
    /// 隐藏蓝色框
    func hideLiveBox() {
        livePersonBox.isHidden = true
        livePersonBox.transform = .identity  // 重置transform
        guidanceLine.isHidden = true
    }
    
    /// 更新连接线（连接白色框准星和蓝色框准星）
    func updateGuidanceLine() {
        guard !referencePersonBox.isHidden && !livePersonBox.isHidden else {
            guidanceLine.isHidden = true
            return
        }
        
        // 计算白色框的中心点（准星位置）
        let whiteCenter = referencePersonBox.center
        
        // 计算蓝色框的中心点（准星位置）
        let blueCenter = livePersonBox.center
        
        let path = UIBezierPath()
        path.move(to: whiteCenter)
        path.addLine(to: blueCenter)
        guidanceLine.path = path.cgPath
        guidanceLine.isHidden = false
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
        
        // 隐藏白色框和蓝色框
        referencePersonBox.isHidden = true
        livePersonBox.isHidden = true
        guidanceLine.isHidden = true
        
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
        hideOrShowAllGuidance(!matched)
        print("[AR Guidance] 方向匹配 - \(matched)")
    }
    
    /// 隐藏所有引导元素
    /// 仅隐藏使用
    func hideOrShowAllGuidance(_ hidden: Bool = false) {
        referencePersonBox.isHidden = hidden
        livePersonBox.isHidden = hidden
        guidanceLine.isHidden = hidden
        // 绿框和对号也需要隐藏
        if hidden {
            successBox.isHidden = true
            successCheckmark.isHidden = true
        }
        print("[AR Guidance] 所有引导元素 \(hidden ? "隐藏" : "显示")")
    }
}
