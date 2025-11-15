//
//  LMCameraGuidanceOverlayView.swift
//  processor
//
//  Created by Kiro on 2025/11/1.
//

import UIKit
import SnapKit

protocol LMCameraGuidanceOverlayViewDelegate: AnyObject {
    func cameraGuidanceOverlayViewDidRequestCloseReference(_ view: LMCameraGuidanceOverlayView)
    func cameraGuidanceOverlayView(_ view: LMCameraGuidanceOverlayView, didUpdateAlignment isAligned: Bool)
}

enum LMGuidanceState {
    case hidden
    case showingReference
    case activeGuidance
    case aligned
}

class LMCameraGuidanceOverlayView: UIView {
    
    // MARK: - UI Components
    private let referenceImageView = LMReferenceImageView()
    private let aiGuidanceFrame = LMGuidanceFrameView(style: .aiGuidance)
    private let personDetectionFrame = LMGuidanceFrameView(style: .personDetection)
    private let connectionLineView = LMConnectionLineView()
    private let guidanceNoticeLabel = UILabel()
    
    // MARK: - Properties
    weak var delegate: LMCameraGuidanceOverlayViewDelegate?
    private var currentState: LMGuidanceState = .hidden
    private var referenceImage: UIImage?
    private var isLandscapeReference: Bool = false
    private var isLargeReference: Bool = false
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
        setupConstraints()
        setupGestureRecognizers()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Subview Configuration
    private func configureSubviews() {
        backgroundColor = UIColor.clear
        
        // 参考图片视图设置
        referenceImageView.delegate = self
        referenceImageView.isHidden = true
        
        // AI引导框设置
        aiGuidanceFrame.isHidden = true
        
        // 人物检测框设置
        personDetectionFrame.isHidden = true
        
        // 连接线设置
        connectionLineView.isHidden = true
        
        // 引导提示标签设置
        setupGuidanceNoticeLabel()
        
        // 添加子视图
        addSubview(referenceImageView)
        addSubview(aiGuidanceFrame)
        addSubview(personDetectionFrame)
        addSubview(connectionLineView)
        addSubview(guidanceNoticeLabel)
    }
    
    private func setupGuidanceNoticeLabel() {
        guidanceNoticeLabel.text = LMText.camera.guidanceNotice
        guidanceNoticeLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        guidanceNoticeLabel.textColor = UIColor.white
        guidanceNoticeLabel.backgroundColor = UIColor.systemGray.withAlphaComponent(0.9)
        guidanceNoticeLabel.layer.cornerRadius = 15
        guidanceNoticeLabel.clipsToBounds = true
        guidanceNoticeLabel.textAlignment = .center
        guidanceNoticeLabel.numberOfLines = 0
        guidanceNoticeLabel.isHidden = true
        
        // 添加模糊效果
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.layer.cornerRadius = 15
        blurView.clipsToBounds = true
        guidanceNoticeLabel.insertSubview(blurView, at: 0)
        
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupConstraints() {
        // 参考图片视图约束（默认位置）
        updateReferenceImageConstraints()
        
        // AI引导框约束
        aiGuidanceFrame.snp.makeConstraints { make in
            make.center.equalToSuperview().offset(CGPoint(x: -50, y: -50) as! ConstraintOffsetTarget)
            make.size.equalTo(CGSize(width: 128, height: 160))
        }
        
        // 人物检测框约束
        personDetectionFrame.snp.makeConstraints { make in
            make.center.equalToSuperview().offset(CGPoint(x: 50, y: 100) as! ConstraintOffsetTarget)
            make.size.equalTo(CGSize(width: 96, height: 128))
        }
        
        // 连接线约束
        connectionLineView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 引导提示标签约束
        guidanceNoticeLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
            make.height.equalTo(30)
        }
    }
    
    private func setupGestureRecognizers() {
        // 添加双击手势来切换参考图片大小
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        referenceImageView.addGestureRecognizer(doubleTapGesture)
    }
    
    // MARK: - Public Methods
    func showReferenceImage(_ image: UIImage, isLandscape: Bool = false) {
        self.referenceImage = image
        self.isLandscapeReference = isLandscape
        
        referenceImageView.setImage(image)
        referenceImageView.setLandscape(isLandscape)
        
        updateReferenceImageConstraints()
        
        currentState = .showingReference
        updateVisibility()
    }
    
    func hideReferenceImage() {
        currentState = .hidden
        updateVisibility()
    }
    
    func startARGuidance() {
        guard currentState == .showingReference else { return }
        
        currentState = .activeGuidance
        updateVisibility()
        
        // 开始模拟人物检测
        simulatePersonDetection()
    }
    
    func stopARGuidance() {
        currentState = .showingReference
        updateVisibility()
    }
    
    func showGuidanceNotice(_ message: String) {
        guidanceNoticeLabel.text = message
        guidanceNoticeLabel.isHidden = false
        
        // 自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.guidanceNoticeLabel.isHidden = true
        }
    }
    
    func toggleReferenceSize() {
        isLargeReference.toggle()
        updateReferenceImageConstraints()
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            self.layoutIfNeeded()
        }
    }
    
    // MARK: - Private Methods
    private func updateReferenceImageConstraints() {
        referenceImageView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-180)
            
            if isLandscapeReference {
                if isLargeReference {
                    make.size.equalTo(CGSize(width: 160, height: 120))
                } else {
                    make.size.equalTo(CGSize(width: 100, height: 75))
                }
            } else {
                if isLargeReference {
                    make.size.equalTo(CGSize(width: 120, height: 160))
                } else {
                    make.size.equalTo(CGSize(width: 75, height: 100))
                }
            }
        }
    }
    
    private func updateVisibility() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            switch self.currentState {
            case .hidden:
                self.referenceImageView.isHidden = true
                self.aiGuidanceFrame.isHidden = true
                self.personDetectionFrame.isHidden = true
                self.connectionLineView.isHidden = true
                
            case .showingReference:
                self.referenceImageView.isHidden = false
                self.aiGuidanceFrame.isHidden = true
                self.personDetectionFrame.isHidden = true
                self.connectionLineView.isHidden = true
                
            case .activeGuidance:
                self.referenceImageView.isHidden = false
                self.aiGuidanceFrame.isHidden = false
                self.personDetectionFrame.isHidden = false
                self.connectionLineView.isHidden = false
                
            case .aligned:
                self.referenceImageView.isHidden = false
                self.aiGuidanceFrame.isHidden = false
                self.personDetectionFrame.isHidden = false
                self.connectionLineView.isHidden = false
                self.aiGuidanceFrame.setAligned(true)
                self.personDetectionFrame.setAligned(true)
            }
        }
    }
    
    private func simulatePersonDetection() {
        // 模拟人物检测和对齐过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.currentState = .aligned
            self.updateVisibility()
            self.delegate?.cameraGuidanceOverlayView(self, didUpdateAlignment: true)
            
            // 3秒后回到活跃引导状态
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.currentState = .activeGuidance
                self.updateVisibility()
                self.aiGuidanceFrame.setAligned(false)
                self.personDetectionFrame.setAligned(false)
                self.delegate?.cameraGuidanceOverlayView(self, didUpdateAlignment: false)
            }
        }
    }
    
    // MARK: - Gesture Handlers
    @objc private func handleDoubleTap() {
        toggleReferenceSize()
    }
}

// MARK: - LMReferenceImageViewDelegate
extension LMCameraGuidanceOverlayView: LMReferenceImageViewDelegate {
    func referenceImageViewDidTapClose(_ view: LMReferenceImageView) {
        delegate?.cameraGuidanceOverlayViewDidRequestCloseReference(self)
    }
}

// MARK: - Supporting Views

// 参考图片视图
protocol LMReferenceImageViewDelegate: AnyObject {
    func referenceImageViewDidTapClose(_ view: LMReferenceImageView)
}

class LMReferenceImageView: UIView {
    
    private let imageView = UIImageView()
    private let gridOverlay = UIView()
    private let closeButton = UIButton()
    
    weak var delegate: LMReferenceImageViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureSubviews() {
        layer.cornerRadius = 12
        clipsToBounds = true
        layer.borderWidth = 2
        layer.borderColor = UIColor.white.withAlphaComponent(0.8).cgColor
        backgroundColor = UIColor.black.withAlphaComponent(0.2)
        
        // 添加模糊效果
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        addSubview(blurView)
        
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 图片视图
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
        
        // 网格覆盖层
        setupGridOverlay()
        addSubview(gridOverlay)
        
        // 关闭按钮
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = UIColor.white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 9
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        addSubview(closeButton)
        
        // 约束
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        gridOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.trailing.equalToSuperview().offset(-4)
            make.size.equalTo(18)
        }
    }
    
    private func setupGridOverlay() {
        // 创建九宫格线条
        let lineColor = UIColor.white.withAlphaComponent(0.3)
        
        // 垂直线
        for i in 1...2 {
            let line = UIView()
            line.backgroundColor = lineColor
            gridOverlay.addSubview(line)
            
            line.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.width.equalTo(1)
                make.leading.equalToSuperview().multipliedBy(CGFloat(i) / 3.0)
            }
        }
        
        // 水平线
        for i in 1...2 {
            let line = UIView()
            line.backgroundColor = lineColor
            gridOverlay.addSubview(line)
            
            line.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(1)
                make.top.equalToSuperview().multipliedBy(CGFloat(i) / 3.0)
            }
        }
    }
    
    func setImage(_ image: UIImage) {
        imageView.image = image
    }
    
    func setLandscape(_ isLandscape: Bool) {
        // 可以根据需要调整布局
    }
    
    @objc private func closeButtonTapped() {
        delegate?.referenceImageViewDidTapClose(self)
    }
}

// 引导框视图
enum LMGuidanceFrameStyle {
    case aiGuidance
    case personDetection
}

class LMGuidanceFrameView: UIView {
    
    private let style: LMGuidanceFrameStyle
    private let cornerViews: [UIView] = []
    private let plusLabel = UILabel()
    private var isAligned: Bool = false
    
    init(style: LMGuidanceFrameStyle) {
        self.style = style
        super.init(frame: .zero)
        configureSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureSubviews() {
        backgroundColor = UIColor.clear
        layer.cornerRadius = 15
        
        // 创建四个角的边框
        createCornerBorders()
        
        // 添加加号标识
        plusLabel.text = "+"  // Keep as symbol
        plusLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        plusLabel.textAlignment = .center
        addSubview(plusLabel)
        
        plusLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        updateAppearance()
    }
    
    private func createCornerBorders() {
        let borderWidth: CGFloat = 2
        let cornerLength: CGFloat = 20
        
        // 左上角
        let topLeft = createCornerView(borderWidth: borderWidth, cornerLength: cornerLength)
        addSubview(topLeft)
        topLeft.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(-borderWidth)
            make.size.equalTo(cornerLength)
        }
        
        // 右上角
        let topRight = createCornerView(borderWidth: borderWidth, cornerLength: cornerLength)
        topRight.transform = CGAffineTransform(rotationAngle: .pi / 2)
        addSubview(topRight)
        topRight.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().offset(borderWidth)
            make.size.equalTo(cornerLength)
        }
        
        // 左下角
        let bottomLeft = createCornerView(borderWidth: borderWidth, cornerLength: cornerLength)
        bottomLeft.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        addSubview(bottomLeft)
        bottomLeft.snp.makeConstraints { make in
            make.bottom.leading.equalToSuperview().offset(borderWidth)
            make.size.equalTo(cornerLength)
        }
        
        // 右下角
        let bottomRight = createCornerView(borderWidth: borderWidth, cornerLength: cornerLength)
        bottomRight.transform = CGAffineTransform(rotationAngle: .pi)
        addSubview(bottomRight)
        bottomRight.snp.makeConstraints { make in
            make.bottom.trailing.equalToSuperview().offset(-borderWidth)
            make.size.equalTo(cornerLength)
        }
    }
    
    private func createCornerView(borderWidth: CGFloat, cornerLength: CGFloat) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.clear
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: cornerLength))
        path.addLine(to: CGPoint(x: 0, y: borderWidth))
        path.addLine(to: CGPoint(x: borderWidth, y: borderWidth))
        path.addLine(to: CGPoint(x: borderWidth, y: 0))
        path.addLine(to: CGPoint(x: cornerLength, y: 0))
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = borderWidth
        shapeLayer.fillColor = UIColor.clear.cgColor
        
        view.layer.addSublayer(shapeLayer)
        return view
    }
    
    func setAligned(_ aligned: Bool) {
        isAligned = aligned
        updateAppearance()
    }
    
    private func updateAppearance() {
        let color: UIColor
        
        if isAligned {
            color = UIColor.systemGreen
        } else {
            switch style {
            case .aiGuidance:
                color = UIColor.white
            case .personDetection:
                color = UIColor.systemBlue
            }
        }
        
        plusLabel.textColor = color
        
        // 更新边框颜色
        layer.sublayers?.forEach { layer in
            if let shapeLayer = layer as? CAShapeLayer {
                shapeLayer.strokeColor = color.cgColor
            }
        }
    }
}

// 连接线视图
class LMConnectionLineView: UIView {
    
    private let shapeLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func configureSubviews() {
        backgroundColor = UIColor.clear
        
        shapeLayer.strokeColor = UIColor.systemBlue.cgColor
        shapeLayer.lineWidth = 2
        shapeLayer.lineDashPattern = [8, 8]
        shapeLayer.fillColor = UIColor.clear.cgColor
        
        // 添加发光效果
        shapeLayer.shadowColor = UIColor.systemBlue.cgColor
        shapeLayer.shadowRadius = 4
        shapeLayer.shadowOpacity = 0.6
        shapeLayer.shadowOffset = .zero
        
        layer.addSublayer(shapeLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 绘制连接线路径
        let path = UIBezierPath()
        let startPoint = CGPoint(x: bounds.width * 0.3, y: bounds.height * 0.4)
        let endPoint = CGPoint(x: bounds.width * 0.7, y: bounds.height * 0.7)
        
        path.move(to: startPoint)
        path.addLine(to: endPoint)
        
        shapeLayer.path = path.cgPath
    }
}
