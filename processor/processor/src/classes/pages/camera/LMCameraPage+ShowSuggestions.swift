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
        
        inspireMeButtonView.isHidden = true
        bottomControlsHeightConstraint?.update(offset: 44)
        showSuggestionsCarousel()
        startPollingAIGCSuggestions()
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
        
        stopPollingAIGCSuggestions()
        hideSuggestionsCarousel()
        inspireMeButtonView.isHidden = false
        bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
        
        currentTaskId = nil
        currentSuggestions.removeAll()
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
        
        containerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(cameraBottomControlsView.snp.top).offset(-20)
            make.height.equalTo(150)
        }
        
        // 创建轮播视图
        let carouselView = LMSuggestionsCarouselView()
        carouselView.delegate = self
        containerView.addSubview(carouselView)
        
        carouselView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // 转换为 DisplayModel 并更新
        let displayModels = currentSuggestions.map { SuggestionDisplayModel(from: $0) }
        carouselView.updateSuggestions(displayModels)
        
        // 保存引用
        self.suggestionsContainerView = containerView
        self.suggestionsCarouselView = carouselView
        
        // 淡入动画
        containerView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            containerView.alpha = 1
        }
        
        LMLogger.log("✅ Suggestions carousel displayed with \(displayModels.count) items")
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
}
