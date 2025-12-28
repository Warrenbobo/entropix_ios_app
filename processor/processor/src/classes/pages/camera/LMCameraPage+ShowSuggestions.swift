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
    func enterShowSuggestionsState(taskId: String, suggestions: [LMCompositionSuggestion]?) {
        guard currentCameraState != .showingSuggestions else { return }
        
        currentCameraState = .showingSuggestions
        currentTaskId = taskId
        if let suggestionsList = suggestions {
            currentSuggestions = suggestionsList
        }
        
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
        
        // 立即更新轮播视图的数据（如果有初始数据）
        if !currentSuggestions.isEmpty {
            suggestionsCarouselView?.updateSuggestions(currentSuggestions)
            LMLogger.log("✅ Initial suggestions loaded: \(currentSuggestions.count) items")
        }
        
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
        
        LMLogger.log("📐 Entered Show Suggestions state - Task ID: \(taskId), Suggestions: \(suggestions?.count ?? 0), AR Guidance unavailable")
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
            LMLogger.log("✅ Suggestions carousel shown (reused existing view)")
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
            LMLogger.log("✅ Suggestions carousel created and shown")
        }
    }
    
    /// 隐藏构图轮播视图
    func hideSuggestionsCarousel() {
        self.suggestionsCarouselView?.isHidden = true
        LMLogger.log("✅ Suggestions carousel hidden")
    }
}

// MARK: - AI Generation Polling (Job-based)
extension LMCameraPage {
    
    /// 开始轮询 AI 生成构图（基于 Job 的新轮询逻辑）
    func startPollingAIGCSuggestions() {
        guard let taskId = currentTaskId else { return }
        stopPollingAIGCSuggestions()
        LMLogger.log("🔄 Started job-based polling - Task ID: \(taskId)")
        // 2秒后开始第一次轮询
        scheduleNextPoll(taskId: taskId)
    }
    
    /// 停止轮询
    func stopPollingAIGCSuggestions() {
        isPolling = false
        LMLogger.log("🛑 Stopped polling AIGC suggestions")
    }
    
    /// 轮询 Job 列表
    private func pollJobList(taskId: String) {
        // 如果正在轮询中，跳过本次请求
        guard !isPolling else {
            LMLogger.log("⚠️ Polling already in progress, skipping this request")
            return
        }
        isPolling = true
        // 步骤1: 获取所有 jobs 数据
        LMApiService.shared.getJobList(taskId: taskId) { [weak self] response in
            guard let self = self else { return }
            // 收到服务器响应，重置轮询标志
            self.isPolling = false
            if response.requestSuccess, let data = response.value {
                self.handleJobListResponse(taskId: taskId, response: data)
            } else {
                LMLogger.log("❌ Failed to get job list: \(response.message ?? "Unknown error")")
                // 请求失败，2秒后重试
                self.scheduleNextPoll(taskId: taskId)
            }
        }
    }
    
    /// 处理 Job 列表响应
    private func handleJobListResponse(taskId: String, response: LMCompositionJobListResponse) {
        // 检查 all_completed，如果已完成则停止轮询
        if response.allCompleted == true {
            LMLogger.log("✅ All jobs completed - stopping polling")
            stopPollingAIGCSuggestions()
            
            // 清理无效的占位数据：ready 为 false 且 imageUrl 为 nil 的数据
            cleanupInvalidSuggestions()
            return
        }
        // 收到 job 列表响应后，立即安排 2 秒后的下一次轮询（与子 job 请求无关）
        scheduleNextPoll(taskId: taskId)
        guard let jobIds = response.jobIds, !jobIds.isEmpty else {
            LMLogger.log("⚠️ No job IDs found in response")
            return
        }
        LMLogger.log("📋 Got \(jobIds.count) jobs, all_completed: \(response.allCompleted ?? false)")
        // 步骤2: 异步并发请求所有 jobId 对应的建议图
        for jobId in jobIds {
            fetchJobDetailAndUpdateImmediately(taskId: taskId, jobId: jobId)
        }
    }
    
    /// 获取单个 Job 详情并立即更新列表
    private func fetchJobDetailAndUpdateImmediately(taskId: String, jobId: String) {
        LMApiService.shared.getJobDetail(taskId: taskId, jobId: jobId) { [weak self] detailResponse in
            guard let self = self else { return }
            
            if detailResponse.requestSuccess, let data = detailResponse.value {
                // 当 job 的 status 为 done 且 suggestions 包含数据时，立即更新列表
                if let job = data.job,
                   job.status == "done",
                   let suggestions = data.suggestions,
                   !suggestions.isEmpty {
                    LMLogger.log("✅ Job \(jobId) done with \(suggestions.count) suggestions - updating immediately")
                    
                    // 在主线程立即更新 UI
                    DispatchQueue.main.async {
                        self.updateSuggestionsWithNewData(suggestions)
                    }
                } else {
                    LMLogger.log("⏳ Job \(jobId) status: \(data.job?.status ?? "unknown")")
                }
            } else {
                LMLogger.log("❌ Failed to get job detail for \(jobId): \(detailResponse.message ?? "Unknown error")")
            }
        }
    }
    
    /// 根据新数据立即更新建议图列表
    private func updateSuggestionsWithNewData(_ newSuggestions: [LMCompositionSuggestion]) {
        guard !newSuggestions.isEmpty else { return }
        
        // 根据 rank 替换现有列表中的占位符或更新已有项
        for newSuggestion in newSuggestions {
            guard let rank = newSuggestion.rank else { continue }
            
            // 查找现有列表中相同 rank 的项
            if let existingIndex = currentSuggestions.firstIndex(where: { $0.rank == rank }) {
                // 替换占位符或更新已有项
                currentSuggestions[existingIndex] = newSuggestion
                LMLogger.log("🔄 Updated suggestion at rank \(rank)")
            } else {
                // 如果没有找到相同 rank 的项，添加到列表
                currentSuggestions.append(newSuggestion)
                LMLogger.log("➕ Added new suggestion at rank \(rank)")
            }
        }
        
        // 按 rank 排序
        currentSuggestions.sort { ($0.rank ?? 0) < ($1.rank ?? 0) }
        
        // 刷新 UI（无论 Show Suggestions 是否可见，只要视图存在就更新）
        // 这样当用户从 compositionSelected 状态返回时，列表已经是最新的
        if let carouselView = suggestionsCarouselView {
            carouselView.updateSuggestions(currentSuggestions)
            LMLogger.log("✅ UI updated with \(newSuggestions.count) new suggestions, total: \(currentSuggestions.count), carousel visible: \(!carouselView.isHidden)")
        } else {
            LMLogger.log("✅ Data updated with \(newSuggestions.count) new suggestions, total: \(currentSuggestions.count) (carousel not available)")
        }
    }
    
    /// 安排下一次轮询（在收到 job 列表响应后 2 秒执行）
    private func scheduleNextPoll(taskId: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self,
                  self.currentTaskId == taskId else {
                LMLogger.log("⚠️ Polling cancelled - task mismatch or cleared")
                return
            }
            
            // 允许在 showingSuggestions 或 compositionSelected 状态下继续轮询
            // compositionSelected 状态下 Show Suggestions 只是隐藏，没有销毁
            guard self.currentCameraState == .showingSuggestions || 
                  self.currentCameraState == .compositionSelected else {
                LMLogger.log("⚠️ Polling cancelled - state changed to \(self.currentCameraState)")
                return
            }
            
            self.pollJobList(taskId: taskId)
        }
    }
    
    /// 清理无效的占位数据（ready 为 false 且 imageUrl 为 nil）
    private func cleanupInvalidSuggestions() {
        let originalCount = currentSuggestions.count
        
        // 过滤掉 ready 为 false 且 imageUrl 为 nil 的数据
        currentSuggestions = currentSuggestions.filter { suggestion in
            // 保留条件：ready 为 true，或者 imageUrl 不为空
            let isReady = suggestion.ready == true
            let hasImageUrl = suggestion.imageUrl != nil && !suggestion.imageUrl!.isEmpty
            return isReady || hasImageUrl
        }
        
        let removedCount = originalCount - currentSuggestions.count
        
        if removedCount > 0 {
            LMLogger.log("🧹 Cleaned up \(removedCount) invalid suggestions (ready=false && imageUrl=nil)")
            
            // 更新 UI（无论 Show Suggestions 是否可见，只要视图存在就更新）
            if let carouselView = suggestionsCarouselView {
                carouselView.updateSuggestions(currentSuggestions)
                LMLogger.log("✅ UI updated after cleanup, remaining: \(currentSuggestions.count) suggestions, carousel visible: \(!carouselView.isHidden)")
            } else {
                LMLogger.log("✅ Data cleaned up, remaining: \(currentSuggestions.count) suggestions (carousel not available)")
            }
        } else {
            LMLogger.log("✅ No invalid suggestions to clean up")
        }
    }
}

// MARK: - LMSuggestionsCarouselViewDelegate
extension LMCameraPage: LMSuggestionsCarouselViewDelegate {
    
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView,
                                 didSelectSuggestion suggestion: LMCompositionSuggestion,
                                 at index: Int) {
        LMLogger.log("📱 Selected suggestion at index: \(index), ID: \(suggestion.id ?? "unknown")")
        
        // 保存当前选中的构图
        currentSuggestion = suggestion
        
        // TODO: 可以在这里预加载构图图片
    }
    
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView,
                                 didToggleFavorite suggestion: LMCompositionSuggestion,
                                 at index: Int) {
        LMLogger.log("❤️ Toggling favorite for suggestion: \(suggestion.id ?? "unknown")")
        
        // TODO: 调用 API 保存/取消收藏
        // 暂时只显示反馈
        AppTheme.Toast.showText("Suggestion saved to favorites")
    }
    
    func suggestionsCarouselViewDidRequestMoreSuggestions(_ view: LMSuggestionsCarouselView) {
        LMLogger.log("🔄 Requesting more suggestions")
        
        // TODO: 实现分页或重新生成
        AppTheme.Toast.showText("No more suggestions available")
    }
    
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView,
                                 didSwipeUpSuggestion suggestion: LMCompositionSuggestion,
                                 at index: Int) {
        LMLogger.log("⬆️ Swiped up suggestion at index: \(index), ID: \(suggestion.id ?? "unknown")")
        
        // 获取选中的卡片视图和图片
        guard let cardView = view.getSelectedCardView(),
              let image = cardView.displayedImage else {
            LMLogger.log("❌ Cannot enter composition selected state - no image loaded")
            AppTheme.Toast.showText("Please wait for image to load")
            return
        }
        
        // 保存当前选中的构图
        currentSuggestion = suggestion
        
        // 进入 Camera with Composition Selected 状态
        enterCompositionSelectedState(with: suggestion, image: image)
    }
}

// MARK: - Composition Selected State
extension LMCameraPage {
    
    /// 进入 Camera with Composition Selected 状态（从 Show Suggestions 进入）
    /// - Parameters:
    ///   - suggestion: 选中的构图方案
    ///   - image: 从卡片视图获取的已显示图片
    func enterCompositionSelectedState(with suggestion: LMCompositionSuggestion, image: UIImage) {
        guard currentCameraState == .showingSuggestions else {
            LMLogger.log("⚠️ [Composition Selected] Cannot enter - current state is not showingSuggestions")
            return
        }
        
        LMLogger.log("🎯 [Composition Selected] Entering state with suggestion: \(suggestion.id)")
        
        currentCameraState = .compositionSelected
        currentSuggestion = suggestion
        currentReferenceImage = image
        
        // 隐藏构图轮播
        hideSuggestionsCarousel()
        
        // 恢复底部控制栏高度
        bottomControlsHeightConstraint?.update(offset: LMCameraConstants.bottomControlsHeight)
        
        // 切换底部控制栏为正常模式
        cameraBottomControlsView.setLayoutMode(.normal, animated: true)
        
        // 显示参考图在左下角
        showReferenceImageInCorner(suggestion: suggestion)
        
        LMLogger.log("✅ [Composition Selected] Reference image loaded for AR Guidance")
        
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
        
        // 使用已加载的 currentReferenceImage
        guard let referenceImage = currentReferenceImage else {
            LMLogger.log("❌ currentReferenceImage is nil")
            return
        }
        
        // 根据实际图片尺寸计算宽高比（而不是使用 suggestion 数据中的 width/height）
        let aspectRatio = referenceImage.size.width / referenceImage.size.height
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
        imageView.image = referenceImage
        LMLogger.log("✅ Using currentReferenceImage for display, image size: \(referenceImage.size), aspect ratio: \(aspectRatio)")
        
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
            
            // 保存当前选中的构图 ID（用于恢复选中状态）
            // 使用 ID 而不是索引，因为在轮询期间 currentSuggestions 可能已经变化
            let previouslySelectedId = currentSuggestion?.id
            
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
                
                // 使用 ID 在更新后的列表中查找索引，确保数据安全
                if let selectedId = previouslySelectedId,
                   let newIndex = currentSuggestions.firstIndex(where: { $0.id == selectedId }),
                   newIndex < currentSuggestions.count {
                    // 延迟一点执行，确保轮播视图已经完成布局
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self = self,
                              let carouselView = self.suggestionsCarouselView else { return }
                        
                        // 再次验证索引有效性（防止在延迟期间数据再次变化）
                        if let finalIndex = self.currentSuggestions.firstIndex(where: { $0.id == selectedId }),
                           finalIndex < self.currentSuggestions.count {
                            carouselView.selectSuggestion(at: finalIndex, animated: true)
                            LMLogger.log("📐 Restored selection to index: \(finalIndex) (ID: \(selectedId))")
                        } else {
                            LMLogger.log("⚠️ Previously selected suggestion (ID: \(selectedId)) no longer exists in list")
                        }
                    }
                } else if let selectedId = previouslySelectedId {
                    LMLogger.log("⚠️ Previously selected suggestion (ID: \(selectedId)) not found in updated list")
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
