//
//  LMCameraPage+ShowSuggestions.swift
//  processor
//
//  Show Suggestions feature implementation
//  PRD 3.14: 在 Camera 页面内展示构图建议
//

import UIKit

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
        
        LMLogger.log("📐 Entered Show Suggestions state - Task ID: \(taskId), Suggestions: \(suggestions.count)")
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
        
        LMLogger.log("📐 Exited Show Suggestions state")
    }
}

// MARK: - Suggestions Carousel Management
extension LMCameraPage {
    
    /// 显示构图轮播视图
    func showSuggestionsCarousel() {
        // 创建容器视图
        let containerView = UIView()
        containerView.backgroundColor = UIColor.clear
        containerView.tag = ViewTag.suggestionsContainer.rawValue
        view.addSubview(containerView)
        
        let carouselHeight: CGFloat = 200
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(cameraBottomControlsView.snp.top).offset(-16)
            make.height.equalTo(carouselHeight)
        }
        
        // 创建轮播视图
        let carouselView = LMSuggestionsCarouselView()
        carouselView.delegate = self
        containerView.addSubview(carouselView)
        
        carouselView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 保存引用
        self.suggestionsContainerView = containerView
        self.suggestionsCarouselView = carouselView
    }
    
    /// 隐藏构图轮播视图
    func hideSuggestionsCarousel() {
        guard let containerView = view.viewWithTag(ViewTag.suggestionsContainer.rawValue) else {
            return
        }
        
        // 淡出动画
        UIView.animate(withDuration: 0.3, animations: {
            containerView.alpha = 0
        }) { _ in
            containerView.removeFromSuperview()
            self.suggestionsContainerView = nil
            self.suggestionsCarouselView = nil
        }
        
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
            
            let displayModels = self.currentSuggestions.map { SuggestionDisplayModel(from: $0) }
            self.suggestionsCarouselView?.updateSuggestions(displayModels)
            
            LMLogger.log("🔄 Updated suggestions - Total: \(displayModels.count), Ready: \(displayModels.filter { !$0.isGenerating }.count)")
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
    
    /// 进入 Camera with Composition Selected 状态
    func enterCompositionSelectedState(with suggestion: LMCompositionSuggestion) {
        guard currentCameraState == .showingSuggestions else { return }
        
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
        
        LMLogger.log("📐 Entered Composition Selected state - Suggestion ID: \(suggestion.id)")
    }
    
    /// 在左下角显示参考图
    func showReferenceImageInCorner(suggestion: LMCompositionSuggestion) {
        // 创建参考图容器
        let referenceImageView = UIImageView()
        referenceImageView.tag = ViewTag.referenceImageView.rawValue
        referenceImageView.contentMode = .scaleAspectFill
        referenceImageView.clipsToBounds = true
        referenceImageView.layer.cornerRadius = 12
        referenceImageView.layer.borderWidth = 2
        referenceImageView.layer.borderColor = UIColor.white.cgColor
        referenceImageView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        // 添加关闭按钮
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 15
        closeButton.addTarget(self, action: #selector(closeReferenceImage), for: .touchUpInside)
        
        view.addSubview(referenceImageView)
        referenceImageView.addSubview(closeButton)
        
        // 设置约束
        let referenceSize = CGSize(width: 120, height: 160)
        referenceImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalTo(cameraBottomControlsView.snp.top).offset(-20)
            make.width.equalTo(referenceSize.width)
            make.height.equalTo(referenceSize.height)
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.width.height.equalTo(30)
        }
        
        // 加载图片
        if let imageUrl = suggestion.imageUrl, let url = URL(string: imageUrl) {
            // TODO: 使用图片加载库加载图片
            // 临时使用占位图
            referenceImageView.image = UIImage(systemName: "photo")
            LMLogger.log("📷 Loading reference image from: \(imageUrl)")
        } else {
            referenceImageView.image = UIImage(systemName: "photo")
        }
        
        // 添加双击放大手势
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleReferenceImageDoubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        referenceImageView.isUserInteractionEnabled = true
        referenceImageView.addGestureRecognizer(doubleTapGesture)
        
        // 添加拖动手势
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleReferenceImagePan(_:)))
        referenceImageView.addGestureRecognizer(panGesture)
        
        // 淡入动画
        referenceImageView.alpha = 0
        referenceImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            referenceImageView.alpha = 1
            referenceImageView.transform = .identity
        }
        
        LMLogger.log("✅ Reference image displayed in corner")
    }
    
    /// 关闭参考图
    @objc func closeReferenceImage() {
        guard let referenceImageView = view.viewWithTag(ViewTag.referenceImageView.rawValue) else {
            return
        }
        
        // 淡出动画
        UIView.animate(withDuration: 0.3, animations: {
            referenceImageView.alpha = 0
            referenceImageView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            referenceImageView.removeFromSuperview()
        }
        
        // 返回 Show Suggestions 状态
        currentCameraState = .showingSuggestions
        currentSuggestion = nil
        
        // 显示构图轮播
        showSuggestionsCarousel()
        
        // 调整底部控制栏
        bottomControlsHeightConstraint?.update(offset: 44)
        cameraBottomControlsView.setLayoutMode(.compact, animated: true)
        
        UIView.animate(withDuration: 0.35) {
            self.view.layoutIfNeeded()
        }
        
        LMLogger.log("✅ Reference image closed, returned to Show Suggestions state")
    }
    
    /// 处理参考图双击放大
    @objc func handleReferenceImageDoubleTap() {
        guard let referenceImageView = view.viewWithTag(ViewTag.referenceImageView.rawValue) else {
            return
        }
        
        // TODO: 实现放大查看功能
        LMLogger.log("📷 Reference image double tapped")
    }
    
    /// 处理参考图拖动
    @objc func handleReferenceImagePan(_ gesture: UIPanGestureRecognizer) {
        guard let referenceImageView = view.viewWithTag(ViewTag.referenceImageView.rawValue) else {
            return
        }
        
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .changed:
            referenceImageView.center = CGPoint(
                x: referenceImageView.center.x + translation.x,
                y: referenceImageView.center.y + translation.y
            )
            gesture.setTranslation(.zero, in: view)
            
        case .ended:
            // 可以添加边界检查，确保不会拖出屏幕
            LMLogger.log("📷 Reference image moved to: \(referenceImageView.center)")
            
        default:
            break
        }
    }
}
