//
//  LMCameraGuideView.swift
//  processor
//
//  相机功能引导视图
//  显示引导提示框和 Lottie 动画
//

import UIKit
import SnapKit
import Lottie

/// 引导视图代理
protocol LMCameraGuideViewDelegate: AnyObject {
    func cameraGuideViewDidComplete(_ guideView: LMCameraGuideView, step: LMCameraGuideStep)
}

/// 相机引导视图
class LMCameraGuideView: UIView {
    
    // MARK: - Properties
    
    weak var delegate: LMCameraGuideViewDelegate?
    
    private var currentStep: LMCameraGuideStep?
    
    /// 顶部提示框容器
    private let tipContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        return view
    }()
    
    /// 提示文字标签
    private let tipLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 2
        return label
    }()
    
    /// Lottie 动画视图
    private var lottieAnimationView: LottieAnimationView?
    
    /// 动画容器（用于定位）
    private let animationContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false // 关键：不拦截触摸事件
        return view
    }()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // 整个视图不拦截触摸事件
        isUserInteractionEnabled = false
        backgroundColor = .clear
        
        // 添加提示框
        addSubview(tipContainerView)
        tipContainerView.addSubview(tipLabel)
        
        // 添加动画容器
        addSubview(animationContainerView)
        
        // 提示框布局 - 顶部居中
        tipContainerView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide).offset(60)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(280)
        }
        
        tipLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20))
        }
        
        // 动画容器布局 - 默认隐藏
        animationContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 默认隐藏
        isHidden = true
    }
    
    // MARK: - Public Methods
    
    /// 显示引导
    /// - Parameters:
    ///   - step: 引导步骤
    ///   - targetView: 目标视图（用于定位 Lottie 动画）
    ///   - inView: 父视图
    func showGuide(step: LMCameraGuideStep, targetView: UIView?, in parentView: UIView) {
        currentStep = step
        
        // 设置提示文字
        tipLabel.text = step.title
        
        // 移除旧的动画
        lottieAnimationView?.removeFromSuperview()
        lottieAnimationView = nil
        
        // 如果需要 Lottie 动画
        if step.needsLottieAnimation, let fileName = step.lottieFileName, let targetView = targetView {
            setupLottieAnimation(fileName: fileName, targetView: targetView, parentView: parentView, step: step)
        }
        
        // 显示视图
        isHidden = false
        
        // 淡入动画
        alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
        
        LMLogger.log("📖 [Guide] Showing guide for step: \(step.rawValue)")
    }
    
    /// 隐藏引导
    /// - Parameter animated: 是否使用动画
    func hideGuide(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let step = currentStep else {
            completion?()
            return
        }
        
        // 立即清除 currentStep，防止重复调用
        currentStep = nil
        
        if animated {
            UIView.animate(withDuration: 0.3, animations: {
                self.alpha = 0
            }) { _ in
                self.isHidden = true
                self.lottieAnimationView?.stop()
                self.delegate?.cameraGuideViewDidComplete(self, step: step)
                completion?()
            }
        } else {
            isHidden = true
            lottieAnimationView?.stop()
            delegate?.cameraGuideViewDidComplete(self, step: step)
            completion?()
        }
        
        LMLogger.log("📖 [Guide] Hiding guide for step: \(step.rawValue)")
    }
    
    /// 更新动画位置（当目标视图位置变化时调用）
    /// - Parameters:
    ///   - targetView: 目标视图
    ///   - parentView: 父视图
    func updateAnimationPosition(targetView: UIView, in parentView: UIView) {
        guard let lottieView = lottieAnimationView, let step = currentStep else { return }
        
        // 计算目标视图在当前视图（self）中的位置
        let targetFrame = targetView.convert(targetView.bounds, to: self)
        
        // 根据不同步骤设置不同的动画位置和尺寸
        let animationSize: CGFloat
        let animationX: CGFloat
        let animationY: CGFloat
        
        switch step {
        case .swipeUp:
            // Step 2: swipe up 动画显示在目标视图的 y 轴上方，尺寸为 240 * 0.7 = 168
            animationSize = 168
            animationX = targetFrame.midX - animationSize / 2
            animationY = targetFrame.minY - animationSize - 10
        default:
            // 其他步骤: 动画覆盖在目标视图上方（z轴），中心点与目标视图中心点对齐
            animationSize = 240
            animationX = targetFrame.midX - animationSize / 2
            animationY = targetFrame.midY - animationSize / 2
        }
        
        lottieView.frame = CGRect(
            x: animationX,
            y: animationY,
            width: animationSize,
            height: animationSize
        )
    }
    
    // MARK: - Private Methods
    
    private func setupLottieAnimation(fileName: String, targetView: UIView, parentView: UIView, step: LMCameraGuideStep) {
        // 创建 Lottie 动画视图
        guard let animation = LottieAnimation.named(fileName) else {
            LMLogger.log("❌ [Guide] Failed to load Lottie animation: \(fileName)")
            return
        }
        
        let animationView = LottieAnimationView(animation: animation)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.isUserInteractionEnabled = false // 关键：不拦截触摸事件
        
        animationContainerView.addSubview(animationView)
        
        // 计算目标视图在当前视图（self）中的位置
        let targetFrame = targetView.convert(targetView.bounds, to: self)
        
        // 根据不同步骤设置不同的动画位置和尺寸
        let animationSize: CGFloat
        let animationX: CGFloat
        let animationY: CGFloat
        
        switch step {
        case .swipeUp:
            // Step 2: swipe up 动画显示在目标视图的 y 轴上方，尺寸为 240 * 0.7 = 168
            animationSize = 168
            animationX = targetFrame.midX - animationSize / 2
            animationY = targetFrame.minY - animationSize - 10
        default:
            // 其他步骤: 动画覆盖在目标视图上方（z轴），中心点与目标视图中心点对齐
            animationSize = 240
            animationX = targetFrame.midX - animationSize / 2
            animationY = targetFrame.midY - animationSize / 2
        }
        
        animationView.frame = CGRect(
            x: animationX,
            y: animationY,
            width: animationSize,
            height: animationSize
        )
        
        // 开始播放动画
        animationView.play()
        
        lottieAnimationView = animationView
        
        LMLogger.log("✅ [Guide] Lottie animation setup: \(fileName), target frame: \(targetFrame), animation frame: \(animationView.frame)")
    }
}

// MARK: - Hit Testing Override
extension LMCameraGuideView {
    
    /// 重写 hitTest 方法，让所有触摸事件穿透到下层视图
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 返回 nil 表示不处理任何触摸事件，让事件传递到下层视图
        return nil
    }
}
