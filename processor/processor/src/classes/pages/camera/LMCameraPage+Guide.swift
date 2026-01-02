//
//  LMCameraPage+Guide.swift
//  processor
//
//  相机页面引导功能扩展
//  处理四个引导步骤的显示和隐藏逻辑
//

import UIKit

// MARK: - Guide Properties
extension LMCameraPage {
    
    // 使用关联对象存储引导视图
    private struct AssociatedKeys {
        static var guideView = "guideView"
        static var currentGuideStep = "currentGuideStep"
    }
    
    /// 引导视图
    var guideView: LMCameraGuideView? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.guideView) as? LMCameraGuideView
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.guideView, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// 当前显示的引导步骤
    var currentGuideStep: LMCameraGuideStep? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.currentGuideStep) as? LMCameraGuideStep
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.currentGuideStep, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - Guide Setup
extension LMCameraPage {
    
    /// 设置引导视图（在 viewDidLoad 中调用）
    func setupGuideView() {
        let guide = LMCameraGuideView()
        guide.delegate = self
        view.addSubview(guide)
        
        guide.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        guideView = guide
        
        LMLogger.log("✅ [Guide] Guide view setup completed")
    }
    
    /// 确保引导视图在最顶层
    func bringGuideViewToFront() {
        if let guide = guideView {
            view.bringSubviewToFront(guide)
        }
    }
}

// MARK: - Step 1: Inspire Me Guide
extension LMCameraPage {
    
    /// 显示 Inspire Me 引导（Step 1）
    /// 触发时机：用户第一次进入相机页面时
    func showInspireMeGuideIfNeeded() {
        guard LMCameraGuideManager.shared.shouldShowGuide(for: .inspirMe) else {
            LMLogger.log("📖 [Guide] Inspire Me guide already shown, skipping")
            return
        }
        
        guard let guide = guideView else {
            LMLogger.log("❌ [Guide] Guide view not initialized")
            return
        }
        
        // 确保引导视图在最顶层
        bringGuideViewToFront()
        
        // 显示引导，目标是 Inspire Me 按钮
        currentGuideStep = .inspirMe
        guide.showGuide(step: .inspirMe, targetView: inspireMeButtonView, in: view)
    }
    
    /// 隐藏 Inspire Me 引导
    /// 触发时机：
    /// 1. 用户点击 Inspire Me 按钮后
    /// 2. 用户点击拍照按钮后
    func hideInspireMeGuide() {
        guard currentGuideStep == .inspirMe else { return }
        
        guideView?.hideGuide(animated: true) { [weak self] in
            LMCameraGuideManager.shared.markGuideAsShown(for: .inspirMe)
            self?.currentGuideStep = nil
        }
    }
}

// MARK: - Step 2: Swipe Up Guide
extension LMCameraPage {
    
    /// 显示上滑选择引导（Step 2）
    /// 触发时机：用户第一次进入 Show Suggestions 页面时
    func showSwipeUpGuideIfNeeded() {
        guard LMCameraGuideManager.shared.shouldShowGuide(for: .swipeUp) else {
            LMLogger.log("📖 [Guide] Swipe Up guide already shown, skipping")
            return
        }
        
        guard let guide = guideView else {
            LMLogger.log("❌ [Guide] Guide view not initialized")
            return
        }
        
        // 确保引导视图在最顶层
        bringGuideViewToFront()
        
        // 获取当前选中的卡片视图作为目标
        let targetView = suggestionsCarouselView?.getSelectedCardView()
        
        currentGuideStep = .swipeUp
        guide.showGuide(step: .swipeUp, targetView: targetView, in: view)
    }
    
    /// 隐藏上滑选择引导
    /// 触发时机：
    /// 1. 用户上滑选择构图方案后
    /// 2. 用户点选其他 suggestion 项目后
    /// 3. 用户点击拍照按钮后
    func hideSwipeUpGuide() {
        guard currentGuideStep == .swipeUp else { return }
        
        guideView?.hideGuide(animated: true) { [weak self] in
            LMCameraGuideManager.shared.markGuideAsShown(for: .swipeUp)
            self?.currentGuideStep = nil
        }
    }
}

// MARK: - Step 3: AR Guidance Guide
extension LMCameraPage {
    
    /// 显示 AR Guidance 引导（Step 3）
    /// 触发时机：用户第一次进入 Camera w/ composition selected 状态时
    func showARGuidanceGuideIfNeeded() {
        guard LMCameraGuideManager.shared.shouldShowGuide(for: .arGuidance) else {
            LMLogger.log("📖 [Guide] AR Guidance guide already shown, skipping")
            return
        }
        
        guard let guide = guideView else {
            LMLogger.log("❌ [Guide] Guide view not initialized")
            return
        }
        
        // 确保引导视图在最顶层
        bringGuideViewToFront()
        
        // 目标是 AR Guidance 按钮（在 cameraBottomControlsView 中）
        // 需要获取 AR Guidance 按钮的引用
        currentGuideStep = .arGuidance
        guide.showGuide(step: .arGuidance, targetView: getARGuidanceButtonView(), in: view)
    }
    
    /// 隐藏 AR Guidance 引导
    /// 触发时机：
    /// 1. 用户点击 AR Guidance 按钮后
    /// 2. 用户点击拍照按钮后
    /// 3. 用户点击关闭 Reference Image 按钮后
    /// 4. 用户点击返回按钮后
    func hideARGuidanceGuide() {
        guard currentGuideStep == .arGuidance else { return }
        
        guideView?.hideGuide(animated: true) { [weak self] in
            LMCameraGuideManager.shared.markGuideAsShown(for: .arGuidance)
            self?.currentGuideStep = nil
        }
    }
    
    /// 获取 AR Guidance 按钮视图
    private func getARGuidanceButtonView() -> UIView? {
        // 从 cameraBottomControlsView 获取 AR Guidance 按钮
        // 需要在 LMCameraBottomControlsView 中暴露这个方法
        return cameraBottomControlsView.getARGuidanceContainerView()
    }
}

// MARK: - Step 4: Align Boxes Guide
extension LMCameraPage {
    
    /// 显示对齐框引导（Step 4）
    /// 触发条件：
    /// 1. Step 3 引导图已消失（已被标记为已显示）
    /// 2. 当前处于 AR Guidance 开启状态
    /// 3. 尚未显示过 Step 4 引导图
    /// 触发时机：
    /// 1. 进入 Reference Image（composition selected 状态）且 AR Guidance 开启时
    /// 2. 点击 AR Guidance 按钮打开 AR Guidance 功能时
    func showAlignBoxesGuideIfNeeded() {
        // 检查 Step 4 是否已显示过
        guard LMCameraGuideManager.shared.shouldShowGuide(for: .alignBoxes) else {
            LMLogger.log("📖 [Guide] Align Boxes guide already shown, skipping")
            return
        }
        
        // 检查 Step 3 是否已消失（已被标记为已显示）
        guard LMCameraGuideManager.shared.hasShownGuide(for: .arGuidance) else {
            LMLogger.log("📖 [Guide] AR Guidance guide (Step 3) not yet shown, skipping Step 4")
            return
        }
        
        // 检查当前是否处于 AR Guidance 开启状态
        guard isARGuidanceActive else {
            LMLogger.log("📖 [Guide] AR Guidance not active, skipping Step 4")
            return
        }
        
        guard let guide = guideView else {
            LMLogger.log("❌ [Guide] Guide view not initialized")
            return
        }
        
        // 确保引导视图在最顶层
        bringGuideViewToFront()
        
        // Step 4 只显示文本，不需要 Lottie 动画
        currentGuideStep = .alignBoxes
        guide.showGuide(step: .alignBoxes, targetView: nil, in: view)
        
        LMLogger.log("✅ [Guide] Showing Align Boxes guide (Step 4)")
    }
    
    /// 尝试显示 Step 4 引导（用于进入 composition selected 状态时）
    /// 延迟 0.5 秒等待 AR Guidance 初始化完成后检查
    func tryShowAlignBoxesGuideAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showAlignBoxesGuideIfNeeded()
        }
    }
    
    /// 隐藏对齐框引导
    /// 触发时机：
    /// 1. 用户第一次 AR Guidance 校准成功后
    /// 2. 用户点击拍照按钮后
    /// 3. 用户点击关闭 Reference Image 按钮后
    /// 4. 用户点击返回按钮后
    /// 5. 用户点击 AR Guidance 按钮关闭 AR 引导后
    func hideAlignBoxesGuide() {
        guard currentGuideStep == .alignBoxes else { return }
        
        guideView?.hideGuide(animated: true) { [weak self] in
            LMCameraGuideManager.shared.markGuideAsShown(for: .alignBoxes)
            self?.currentGuideStep = nil
        }
    }
}

// MARK: - LMCameraGuideViewDelegate
extension LMCameraPage: LMCameraGuideViewDelegate {
    
    func cameraGuideViewDidComplete(_ guideView: LMCameraGuideView, step: LMCameraGuideStep) {
        LMLogger.log("✅ [Guide] Guide completed for step: \(step.rawValue)")
        currentGuideStep = nil
    }
}

// MARK: - Guide Dismissal Helpers
extension LMCameraPage {
    
    /// 隐藏当前显示的任何引导（用于拍照等通用操作）
    func hideCurrentGuideIfNeeded() {
        guard let step = currentGuideStep else { return }
        
        switch step {
        case .inspirMe:
            hideInspireMeGuide()
        case .swipeUp:
            hideSwipeUpGuide()
        case .arGuidance:
            hideARGuidanceGuide()
        case .alignBoxes:
            hideAlignBoxesGuide()
        }
    }
    
    /// 隐藏 Step 3 和 Step 4 引导（用于关闭参考图、返回按钮等操作）
    func hideCompositionSelectedGuides() {
        guard let step = currentGuideStep else { return }
        
        if step == .arGuidance {
            hideARGuidanceGuide()
        } else if step == .alignBoxes {
            hideAlignBoxesGuide()
        }
    }
}
