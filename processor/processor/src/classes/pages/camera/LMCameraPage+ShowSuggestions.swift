//
//  LMCameraPage+ShowSuggestions.swift
//  processor
//

import UIKit

// MARK: - Device Orientation Handling
extension LMCameraPage {
    
    /// 开始监听设备方向变化（订阅通知）
    func startObservingDeviceOrientation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceOrientationChangeNotification(_:)),
            name: .devicePhysicalOrientationDidChange,
            object: nil
        )
        
        // 立即应用当前方向
        updateReferenceImageRotation()
        
        LMLogger.log("📱 Started observing device orientation notifications")
    }
    
    /// 停止监听设备方向变化（取消订阅通知）
    func stopObservingDeviceOrientation() {
        NotificationCenter.default.removeObserver(
            self,
            name: .devicePhysicalOrientationDidChange,
            object: nil
        )
        LMLogger.log("📱 Stopped observing device orientation notifications")
    }
    
    /// 处理设备方向变化通知
    @objc private func handleDeviceOrientationChangeNotification(_ notification: Notification) {
        updateReferenceImageRotation()
    }
    
    /// 更新参考图旋转
    private func updateReferenceImageRotation() {
        guard let containerView = referenceImageContainerView,
              !containerView.isHidden else {
            return
        }
        
        let orientation = LMDeviceOrientationManager.shared.currentOrientation
        
        // 只处理有效的方向（排除 FaceUp、FaceDown、Unknown）
        guard orientation.isValidInterfaceOrientation else {
            return
        }
        
        // 获取旋转角度
        let rotationAngle = LMDeviceOrientationManager.shared.getCurrentRotationAngle()
        
        // 应用旋转变换（以容器中心为轴心）
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            containerView.transform = CGAffineTransform(rotationAngle: rotationAngle)
        }
        
        LMLogger.log("📱 Reference image rotated to \(orientation.rawValue), angle: \(rotationAngle * 180 / .pi)°")
    }
}

// MARK: - Show Suggestions State Management
extension LMCameraPage {
    
    /// 进入 Show Suggestions 状态
    func enterShowSuggestionsState(taskId: String, suggestions: [LMCompositionSuggestion]) {
        guard currentCameraState != .showingSuggestions else { return }
        
        currentCameraState = .showingSuggestions
        currentTaskId = taskId
        currentSuggestions = suggestions
        
        // 隐藏 Inspire Me 按钮
        inspireMeButtonView.isHidden = true
        
        // 调整底部控制栏高度
        bottomControlsHeightConstraint?.update(offset: 44)
        
        // 切换底部控制栏为紧凑模式
        cameraBottomControlsView.setLayoutMode(.compact, animated: true)
        
        // Show Suggestions 状态下，AR Guidance 保持不可用（灰色）
        cameraBottomControlsView.resetARGuidance()
        
        // 显示构图轮播
        showSuggestionsCarousel()
        
        // 开始轮询 AI 生成构图
        startPollingAIGCSuggestions()
        
        // 应用布局变化
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            self.view.layoutIfNeeded()
        }
        
        LMLogger.log("📐 Entered Show Suggestions state - Task ID: \(taskId), Suggestions: \(suggestions.count), AR Guidance unavailable")
    }
    
    /// 退出 Show Suggestions 状态
    func exitShowSuggestionsState() {
        guard currentCameraState == .showingSuggestions else { return }
        
        currentCameraState = .normal
        
        // 停止轮询
        stopPollingAIGCSuggestions()
        
        // 隐藏构图轮播
        hideSuggestionsCarousel()
        
        // 显示 Inspire Me 按钮
        inspireMeButtonView.isHidden = false
        
        // 恢复底部控制栏高度
        bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
        
        // 切换底部控制栏为正常模式
        cameraBottomControlsView.setLayoutMode(.normal, animated: true)
        
        // 重置 AR Guidance 状态
        cameraBottomControlsView.resetARGuidance()
        if isARGuidanceActive {
            configureARGuidanceFeatures(false)
        }
        
        // 清理数据
        currentTaskId = nil
        currentSuggestions.removeAll()
        
        // 应用布局变化
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            self.view.layoutIfNeeded()
        }
        
        LMLogger.log("📐 Exited Show Suggestions state, AR Guidance reset to unavailable")
    }
}

// MARK: - Suggestions Carousel Management
extension LMCameraPage {
    
    /// 显示构图轮播视图
    func showSuggestionsCarousel() {
        // 创建轮播视图
        if self.suggestionsCarouselView != nil {
            self.suggestionsCarouselView?.isHidden = false
        } else {
            let carouselView = LMSuggestionsCarouselView()
            carouselView.delegate = self
            view.addSubview(carouselView)
            carouselView.snp.makeConstraints { make in
                make.bottom.equalTo(cameraBottomControlsView.snp.top).offset(-20)
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(170)
            }
            self.suggestionsCarouselView = carouselView
        }
    }
    
    /// 隐藏构图轮播视图
    func hideSuggestionsCarousel() {
        self.suggestionsCarouselView?.isHidden = true
        LMLogger.log("✅ Suggestions carousel hidden")
    }
}

// MARK: - AI Generation Polling
extension LMCameraPage {
    
    /// 开始轮询 AI 生成构图
    func startPollingAIGCSuggestions() {
        guard let taskId = currentTaskId else { return }
        
        stopPollingAIGCSuggestions()
        var pollCount = 0
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            pollCount += 1
            
            // 最多轮询 10 次
            if pollCount > 10 {
                timer.invalidate()
                self.handlePollingTimeout()
                return
            }
            
            self.pollAIGCSuggestions(taskId: taskId)
        }
        
        pollAIGCSuggestions(taskId: taskId)
        LMLogger.log("🔄 Started polling AIGC suggestions - Task ID: \(taskId)")
    }
    
    /// 停止轮询
    func stopPollingAIGCSuggestions() {
        pollTimer?.invalidate()
        pollTimer = nil
        LMLogger.log("🛑 Stopped polling AIGC suggestions")
    }
    
    /// 执行单次轮询
    func pollAIGCSuggestions(taskId: String) {
        // 在后台线程执行网络请求
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            LMCompositionService.shared.pollTaskStatus(taskId: taskId) { result in
                guard let self = self else { return }
                
                switch result {
                case .success(let response):
                    self.handlePollingSuccess(response)
                    
                case .failure(let error):
                    LMLogger.log("❌ Polling failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 处理轮询成功
    func handlePollingSuccess(_ response: LMCompositionService.CompositionStatusResponse) {
        // 更新构图列表
        currentSuggestions = response.suggestions
        
        // 在主线程更新 UI
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.suggestionsCarouselView?.updateSuggestions(self.currentSuggestions)
        }
        
        // 检查是否所有构图都已生成
        let allReady = response.suggestions.allSatisfy { $0.ready }
        if allReady || response.status == "completed" {
            stopPollingAIGCSuggestions()
            LMLogger.log("✅ All suggestions ready - Status: \(response.status)")
        }
    }
    
    /// 处理轮询超时
    func handlePollingTimeout() {
        LMLogger.log("⏱️ Polling timeout - using available suggestions")
        
        // 在主线程显示提示
        DispatchQueue.main.async { [weak self] in
            self?.showAlert("Some AI suggestions are still generating. You can use available suggestions.", style: .toast)
        }
    }
}

// MARK: - LMSuggestionsCarouselViewDelegate
extension LMCameraPage: LMSuggestionsCarouselViewDelegate {
    
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView,
                                 didSelectSuggestion suggestion: LMCompositionSuggestion,
                                 at index: Int) {
        LMLogger.log("📱 Selected suggestion at index: \(index), ID: \(suggestion.id)")
        
        // 保存当前选中的构图
        currentSuggestion = suggestion
        
        // TODO: 可以在这里预加载构图图片
    }
    
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView,
                                 didToggleFavorite suggestion: LMCompositionSuggestion,
                                 at index: Int) {
        LMLogger.log("❤️ Toggling favorite for suggestion: \(suggestion.id)")
        
        // TODO: 调用 API 保存/取消收藏
        // 暂时只显示反馈
        showAlert("Suggestion saved to favorites", style: .toast)
    }
    
    func suggestionsCarouselViewDidRequestMoreSuggestions(_ view: LMSuggestionsCarouselView) {
        LMLogger.log("🔄 Requesting more suggestions")
        
        // TODO: 实现分页或重新生成
        showAlert("No more suggestions available", style: .toast)
    }
    
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView,
                                 didSwipeUpSuggestion suggestion: LMCompositionSuggestion,
                                 at index: Int) {
        LMLogger.log("⬆️ Swiped up suggestion at index: \(index), ID: \(suggestion.id)")
        
        // 保存当前选中的构图
        currentSuggestion = suggestion
        
        // 进入 Camera with Composition Selected 状态
        enterCompositionSelectedState(with: suggestion)
    }
}

// MARK: - Composition Selected State
extension LMCameraPage {
    
    /// 进入 Camera with Composition Selected 状态（从 Show Suggestions 进入）
    func enterCompositionSelectedState(with suggestion: LMCompositionSuggestion) {
        guard currentCameraState == .showingSuggestions else {
            LMLogger.log("⚠️ [Composition Selected] Cannot enter - current state is not showingSuggestions")
            return
        }
        
        LMLogger.log("🎯 [Composition Selected] Entering state with suggestion: \(suggestion.id)")
        
        currentCameraState = .compositionSelected
        currentSuggestion = suggestion
        
        // 隐藏构图轮播
        hideSuggestionsCarousel()
        
        // 恢复底部控制栏高度
        bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
        
        // 切换底部控制栏为正常模式
        cameraBottomControlsView.setLayoutMode(.normal, animated: true)
        
        // 显示参考图在左下角
        showReferenceImageInCorner(suggestion: suggestion)
        
        // 加载Reference Image用于AR Guidance
        if let image = UIImage(named: suggestion.similarImageUrl ?? "") {
            currentReferenceImage = image
            LMLogger.log("✅ [Composition Selected] Reference image loaded for AR Guidance")
        } else {
            LMLogger.log("❌ [Composition Selected] Failed to load reference image")
        }
        
        // 自动开启 AR Guidance
        cameraBottomControlsView.setARGuidanceActive(true)
        LMLogger.log("🎯 [Composition Selected] Calling configureARGuidanceFeatures(true)...")
        configureARGuidanceFeatures(true)
        
        // 应用布局变化
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            self.view.layoutIfNeeded()
        }
        
        LMLogger.log("📐 [Composition Selected] State entered - AR Guidance should be starting")
    }
    
    /// 进入 Camera with Composition Selected 状态（从 Saved Idea 进入）
    func enterCompositionSelectedStateFromSavedIdea(item: GalleryItem) {
        currentCameraState = .compositionSelected
        inspireMeButtonView.isHidden = true
        showReferenceImageFromSavedIdea(item: item)
        cameraBottomControlsView.setARGuidanceActive(true)
        configureARGuidanceFeatures(true)
        LMLogger.log("📐 Entered Composition Selected state from Saved Idea - ID: \(item.id), AR Guidance auto-enabled")
    }
    
    /// 初始化参考图组件（在页面加载时调用一次，长期持有）
    func setupReferenceImageComponent() {
        // 创建容器视图
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.isHidden = true // 默认隐藏
        containerView.isUserInteractionEnabled = true
        view.addSubview(containerView)
        
        // 创建参考图 ImageView
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        containerView.addSubview(imageView)
        
        // 创建关闭按钮
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = UIColor.black.withAlphaComponent(0.5)
//        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 13
        closeButton.addTarget(self, action: #selector(closeReferenceImage), for: .touchUpInside)
        containerView.addSubview(closeButton)
        
        // 设置约束（初始尺寸，后续会根据图片宽高比更新）
        let defaultWidth: CGFloat = 100
        let defaultHeight: CGFloat = 133 // 默认 3:4 比例
        
        containerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalTo(cameraBottomControlsView.snp.top).offset(-20)
            make.width.equalTo(defaultWidth)
            make.height.equalTo(defaultHeight)
        }
        
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.width.height.equalTo(26)
        }
        
        // 添加双击手势（放大/缩小）
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleReferenceImageDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        containerView.addGestureRecognizer(doubleTapGesture)
        
        // 添加拖动手势
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleReferenceImagePan(_:)))
        containerView.addGestureRecognizer(panGesture)
        
        // 保存引用
        self.referenceImageContainerView = containerView
        self.referenceImageView = imageView
        self.referenceCloseButton = closeButton
        
        // 开始监听设备方向变化
        startObservingDeviceOrientation()
        
        LMLogger.log("✅ Reference image component initialized and hidden by default")
    }
    
    /// 显示参考图并更新数据（从 Show Suggestions 进入）
    func showReferenceImageInCorner(suggestion: LMCompositionSuggestion) {
        guard let containerView = referenceImageContainerView,
              let imageView = referenceImageView else {
            LMLogger.log("❌ Reference image component not initialized")
            return
        }
        
        // 根据图片宽高比计算尺寸（最大边长为100）
        let aspectRatio = suggestion.getAspectRatio()
        let defaultMaxEdge: CGFloat = 100
        let newSize = calculateReferenceImageSize(maxEdge: defaultMaxEdge, aspectRatio: aspectRatio)
        
        // 保存原始宽高比到容器的 tag（用于双击放大/缩小时使用）
        // 将 Double 转换为 Int 存储（乘以 10000 保留 4 位小数精度）
        containerView.tag = Int(aspectRatio * 10000)
        
        // 更新容器尺寸
        containerView.snp.updateConstraints { make in
            make.width.equalTo(newSize.width)
            make.height.equalTo(newSize.height)
        }
        
        // 加载图片
//        if let imageUrl = suggestion.imageUrl, let url = URL(string: imageUrl) {
//            // TODO: 使用图片加载库加载图片
//            // 临时使用占位图
//            imageView.image = UIImage(systemName: "photo")
//            LMLogger.log("📷 Loading reference image from: \(imageUrl), aspect ratio: \(aspectRatio)")
//        } else {
            imageView.image = UIImage(named: suggestion.similarImageUrl ?? "")
//        }
        // 显示容器
        containerView.isHidden = false
        
        // 确保视图层级正确：Preview → AR Guidance → Reference Image → Controls
        ensureCorrectViewHierarchy()
        
        LMLogger.log("✅ Reference image displayed - Size: \(newSize), Aspect Ratio: \(aspectRatio)")
    }
    
    /// 显示参考图（从 Saved Idea 进入）
    /// 从go shrt 进入时
    func showReferenceImageFromSavedIdea(item: GalleryItem) {
        guard let containerView = referenceImageContainerView,
              let imageView = referenceImageView else {
            LMLogger.log("❌ Reference image component not initialized")
            return
        }
        
        // 使用 Saved Idea 的图片
        guard let image = item.image else {
            LMLogger.log("❌ Saved Idea image is nil")
            return
        }
        
        // 保存当前参考图（用于 AR 引导）
        currentReferenceImage = image
        LMLogger.log("✅ Current reference image set from Saved Idea")
        
        // 计算图片宽高比
        let aspectRatio = image.size.width / image.size.height
        let defaultMaxEdge: CGFloat = 100
        let newSize = calculateReferenceImageSize(maxEdge: defaultMaxEdge, aspectRatio: aspectRatio)
        
        // 保存原始宽高比到容器的 tag（用于双击放大/缩小时使用）
        // 将 Double 转换为 Int 存储（乘以 10000 保留 4 位小数精度）
        containerView.tag = Int(aspectRatio * 10000)
        
        // 更新容器尺寸
        containerView.snp.updateConstraints { make in
            make.width.equalTo(newSize.width)
            make.height.equalTo(newSize.height)
        }
        
        // 设置图片
        imageView.image = image
        
        // 显示容器
        containerView.isHidden = false
        
        // 确保视图层级正确
        ensureCorrectViewHierarchy()
        
        LMLogger.log("✅ Reference image displayed from Saved Idea - Size: \(newSize), Aspect Ratio: \(aspectRatio)")
    }
    
    /// 计算参考图尺寸（根据最大边长和宽高比）
    /// - Parameters:
    ///   - maxEdge: 最大边的长度（100 或 160）
    ///   - aspectRatio: 宽高比（width/height）
    /// - Returns: 计算后的尺寸
    private func calculateReferenceImageSize(maxEdge: CGFloat, aspectRatio: CGFloat) -> CGSize {
        if aspectRatio > 1.0 {
            // 横向图片：宽度是最大边
            let width = maxEdge
            let height = width / aspectRatio
            return CGSize(width: width, height: height)
        } else {
            // 纵向图片：高度是最大边
            let height = maxEdge
            let width = height * aspectRatio
            return CGSize(width: width, height: height)
        }
    }
    
    /// 处理参考图双击（放大/缩小）
    @objc func handleReferenceImageDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let containerView = referenceImageContainerView else {
            LMLogger.log("⚠️ Reference image double tap failed - missing container")
            return
        }
        
        // 从容器的 tag 中恢复原始宽高比（除以 10000）
        let aspectRatio = Double(containerView.tag) / 10000.0
        
        // 如果 tag 为 0（未设置），使用默认值 3:4
        let finalAspectRatio = aspectRatio > 0 ? aspectRatio : 0.75
        
        let defaultMaxEdge: CGFloat = 100
        let enlargedMaxEdge: CGFloat = 160
        
        // 获取当前容器尺寸
        let currentWidth = containerView.bounds.width
        let currentHeight = containerView.bounds.height
        
        // 获取当前最大边长（根据宽高比判断）
        let currentMaxEdge = finalAspectRatio > 1.0 ? currentWidth : currentHeight
        
        // 判断当前是否为放大状态（使用更宽松的阈值）
        let isEnlarged = abs(currentMaxEdge - enlargedMaxEdge) < 5.0
        let targetMaxEdge = isEnlarged ? defaultMaxEdge : enlargedMaxEdge
        
        // 计算新尺寸（保持原始宽高比）
        let newSize = calculateReferenceImageSize(maxEdge: targetMaxEdge, aspectRatio: finalAspectRatio)
        
        LMLogger.log("🔍 Double tap - Current: \(String(format: "%.1f", currentWidth))x\(String(format: "%.1f", currentHeight)), AspectRatio: \(String(format: "%.2f", finalAspectRatio)), CurrentMaxEdge: \(String(format: "%.1f", currentMaxEdge)), IsEnlarged: \(isEnlarged), Target: \(String(format: "%.1f", targetMaxEdge)), NewSize: \(String(format: "%.1f", newSize.width))x\(String(format: "%.1f", newSize.height))")
        
        // 更新约束并动画
        containerView.snp.updateConstraints { make in
            make.width.equalTo(newSize.width)
            make.height.equalTo(newSize.height)
        }
        
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut, .allowUserInteraction]
        ) {
            self.view.layoutIfNeeded()
        }
        
        LMLogger.log("✅ Reference image \(isEnlarged ? "shrunk" : "enlarged") to \(String(format: "%.1f", newSize.width))x\(String(format: "%.1f", newSize.height))")
    }
    
    /// 关闭参考图
    @objc func closeReferenceImage() {
        guard let containerView = referenceImageContainerView else {
            return
        }
        
        // 重置旋转变换
        containerView.transform = .identity
        
        // 判断导航来源
        switch navigationSource {
        case .savedIdea:
            // 从 Saved Idea 进入，关闭参考图应该返回到 Saved Idea 页面
            LMLogger.log("🔙 Closing reference image from Saved Idea - navigating back")
            
            // 清理状态
            containerView.isHidden = true
            currentCameraState = .normal
            currentSuggestion = nil
            
            // 重置 AR Guidance 为不可用状态
            cameraBottomControlsView.resetARGuidance()
            
            // 如果 AR Guidance 正在运行，停止它
            if isARGuidanceActive {
                configureARGuidanceFeatures(false)
            }
            
            // 清除参考图相关数据
            referenceImageInitialOrientation = nil
            currentReferenceImage = nil
            currentReferenceBbox = nil
            
            // 返回到 Saved Idea 页面
            navigationController?.popViewController(animated: true)
            
            LMLogger.log("✅ Navigated back to Saved Idea page")
            
        case .normal:
            // 从 Show Suggestions 进入，返回 Show Suggestions 状态
            containerView.isHidden = true
            currentCameraState = .showingSuggestions
            
            // 保存当前选中的构图索引（用于恢复选中状态）
            let previouslySelectedIndex = currentSuggestions.firstIndex { $0.id == currentSuggestion?.id } ?? -1
            
            currentSuggestion = nil
            
            // 重置 AR Guidance 为不可用状态（灰色）
            cameraBottomControlsView.resetARGuidance()
            
            // 如果 AR Guidance 正在运行，停止它
            if isARGuidanceActive {
                configureARGuidanceFeatures(false)
            }
            
            // 清除参考图初始方向（防止旋转手机时误触发AR引导）
            referenceImageInitialOrientation = nil
            currentReferenceImage = nil
            currentReferenceBbox = nil
            
            // 显示构图轮播
            showSuggestionsCarousel()
            
            // 更新轮播视图的数据
            if let carouselView = suggestionsCarouselView {
                carouselView.updateSuggestions(currentSuggestions)
                
                // 如果之前有选中的构图，恢复选中状态
                if previouslySelectedIndex >= 0 && previouslySelectedIndex < currentSuggestions.count {
                    // 延迟一点执行，确保轮播视图已经完成布局
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        carouselView.selectSuggestion(at: previouslySelectedIndex, animated: true)
                        LMLogger.log("📐 Restored selection to index: \(previouslySelectedIndex)")
                    }
                }
            }
            
            // 调整底部控制栏
            bottomControlsHeightConstraint?.update(offset: 44)
            cameraBottomControlsView.setLayoutMode(.compact, animated: true)
            
            LMLogger.log("✅ Reference image hidden, returned to Show Suggestions state, AR Guidance reset to unavailable")
        }
    }
    
    /// 处理参考图拖动
    @objc func handleReferenceImagePan(_ gesture: UIPanGestureRecognizer) {
        guard let containerView = referenceImageContainerView else {
            return
        }
        
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .changed:
            // 计算新的中心点
            var newCenter = CGPoint(
                x: containerView.center.x + translation.x,
                y: containerView.center.y + translation.y
            )
            
            // 获取边界约束（使用实时的 bounds，支持动态尺寸变化）
            let imageHalfWidth = containerView.bounds.width / 2
            let imageHalfHeight = containerView.bounds.height / 2
            
            // 顶部边界：状态栏底部 + 安全距离
            let topBoundary = view.safeAreaInsets.top + 44 + imageHalfHeight + 10
            
            // 底部边界：底部控制栏顶部 - 安全距离
            let bottomBoundary = cameraBottomControlsView.frame.minY - imageHalfHeight - 20
            
            // 左右边界：屏幕边缘 + 安全距离
            let leftBoundary = imageHalfWidth + 10
            let rightBoundary = view.bounds.width - imageHalfWidth - 10
            
            // 应用边界约束
            newCenter.x = max(leftBoundary, min(newCenter.x, rightBoundary))
            newCenter.y = max(topBoundary, min(newCenter.y, bottomBoundary))
            
            // 更新位置
            containerView.center = newCenter
            gesture.setTranslation(.zero, in: view)
            
        case .ended:
            LMLogger.log("📷 Reference image moved to: \(containerView.center), size: \(containerView.bounds.size)")
            
        default:
            break
        }
    }
}
