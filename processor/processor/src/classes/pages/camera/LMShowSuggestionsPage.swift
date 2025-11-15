//
//  LMShowSuggestionsPage.swift
//  processor
//
//  Created by Kiro on 2025/11/9.
//

import UIKit
import SnapKit
import Kingfisher

class LMShowSuggestionsPage: LMPageWrapper {
    
    // MARK: - Properties
    private var taskId: String
    private var suggestions: [LMCompositionSuggestion] = []
    private var taskStatus: String = "processing"
    private var pollTimer: Timer?
    
    // MARK: - UI Components
    private let topBar = UIView()
    private let backButton = UIButton()
    private let titleLabel = UILabel()
    
    private let suggestionsCarouselView = LMSuggestionsCarouselView()
    private let statusLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    private let bottomBar = UIView()
    private let selectButton = UIButton()
    private let regenerateButton = UIButton()
    
    // MARK: - Initialization
    
    init(taskId: String, initialSuggestions: [LMCompositionSuggestion] = []) {
        self.taskId = taskId
        self.suggestions = initialSuggestions
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureViewHierarchy()
        setupConstraints()
        updateUI()
        startPolling()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPolling()
    }
    
    deinit {
        stopPolling()
    }
    
    // MARK: - View Hierarchy Configuration
    
    private func configureViewHierarchy() {
        view.backgroundColor = .black
        
        // Top Bar
        topBar.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        titleLabel.text = LMText.camera.compositionSuggestions
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        
        // Status Label
        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = .systemGray
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        
        // Loading Indicator
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        
        // Suggestions Carousel
        suggestionsCarouselView.delegate = self
        
        // Bottom Bar
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        
        selectButton.setTitle(LMText.subscription.selectAndContinue, for: .normal)
        selectButton.setTitleColor(.white, for: .normal)
        selectButton.setTitleColor(.systemGray, for: .disabled)
        selectButton.backgroundColor = .systemBlue
        selectButton.layer.cornerRadius = 12
        selectButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        selectButton.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        
        regenerateButton.setTitle(LMText.subscription.regenerate, for: .normal)
        regenerateButton.setTitleColor(.systemBlue, for: .normal)
        regenerateButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        regenerateButton.addTarget(self, action: #selector(regenerateButtonTapped), for: .touchUpInside)
        regenerateButton.isHidden = true // 暂时隐藏
        
        // Add subviews
        view.addSubview(topBar)
        topBar.addSubview(backButton)
        topBar.addSubview(titleLabel)
        
        view.addSubview(suggestionsCarouselView)
        view.addSubview(statusLabel)
        view.addSubview(loadingIndicator)
        
        view.addSubview(bottomBar)
        bottomBar.addSubview(selectButton)
        bottomBar.addSubview(regenerateButton)
    }
    
    private func setupConstraints() {
        // Top Bar
        topBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(AppTheme.Screen.safeAreaTop + 44)
        }
        
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.bottom.equalToSuperview().offset(-8)
            make.size.equalTo(40)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(backButton)
        }
        
        // Suggestions Carousel
        suggestionsCarouselView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(400)
        }
        
        // Status Label
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(suggestionsCarouselView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        // Loading Indicator
        loadingIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(statusLabel.snp.bottom).offset(20)
        }
        
        // Bottom Bar
        bottomBar.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(AppTheme.Screen.safeAreaBottom + 80)
        }
        
        selectButton.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(50)
        }
        
        regenerateButton.snp.makeConstraints { make in
            make.top.equalTo(selectButton.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
            make.height.equalTo(40)
        }
    }
    
    // MARK: - Update UI
    
    private func updateUI() {
        // 转换为 SuggestionDisplayModel
        let displayModels = suggestions.map { suggestion -> SuggestionDisplayModel in
            return SuggestionDisplayModel(
                id: suggestion.id,
                title: suggestion.sceneType,
                description: "Rank: \(suggestion.rank), Score: \(String(format: "%.2f", suggestion.score ?? 0))",
                imageURL: suggestion.imageUrl,
                image: nil,
                personBoundingBox: suggestion.personBoundingBox,
                confidence: suggestion.score,
                isFavorite: false,
                isGenerating: !suggestion.ready
            )
        }
        
        suggestionsCarouselView.updateSuggestions(displayModels)
        
        // 更新状态
        switch taskStatus {
        case "processing":
            statusLabel.text = LMText.camera.generatingAISuggestions
            statusLabel.textColor = .systemYellow
            loadingIndicator.startAnimating()
            selectButton.isEnabled = hasReadySuggestions()
            
        case "completed":
            statusLabel.text = LMText.camera.allSuggestionsReady
            statusLabel.textColor = .systemGreen
            loadingIndicator.stopAnimating()
            selectButton.isEnabled = true
            
        case "failed":
            statusLabel.text = LMText.camera.generationFailed
            statusLabel.textColor = .systemRed
            loadingIndicator.stopAnimating()
            selectButton.isEnabled = hasReadySuggestions()
            
        case "timeout":
            statusLabel.text = LMText.camera.generationTimeout
            statusLabel.textColor = .systemOrange
            loadingIndicator.stopAnimating()
            selectButton.isEnabled = hasReadySuggestions()
            
        default:
            statusLabel.text = LMText.common.loading
            statusLabel.textColor = .systemGray
            loadingIndicator.startAnimating()
            selectButton.isEnabled = hasReadySuggestions()
        }
    }
    
    private func hasReadySuggestions() -> Bool {
        return suggestions.contains { $0.ready }
    }
    
    // MARK: - Polling
    
    private func startPolling() {
        guard taskStatus == "processing" else { return }
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollTaskStatus()
        }
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func pollTaskStatus() {
        LMCompositionService.shared.pollTaskStatus(taskId: taskId) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let response):
                self.taskStatus = response.status
                self.suggestions = response.suggestions
                self.updateUI()
                
                // 如果任务完成或失败，停止轮询
                if response.status == "completed" || response.status == "failed" || response.status == "timeout" {
                    self.stopPolling()
                }
                
            case .failure(let error):
                LMLogger.log("❌ Poll failed: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func backButtonTapped() {
        let alert = UIAlertController(
            title: "Leave Suggestions?",
            message: "You will lose these suggestions if you go back.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Leave", style: .destructive) { _ in
            self.navigationController?.popViewController(animated: true)
        })
        
        present(alert, animated: true)
    }
    
    @objc private func selectButtonTapped() {
        // 获取当前选中的建议
        guard let selectedSuggestion = getCurrentSelectedSuggestion() else {
            showError("Please select a suggestion")
            return
        }
        
        // 确认选择
        LMCompositionService.shared.confirmSuggestion(
            taskId: taskId,
            suggestionId: selectedSuggestion.id
        ) { [weak self] result in
            switch result {
            case .success:
                LMLogger.log("✅ Suggestion confirmed")
                self?.navigateToCamera(with: selectedSuggestion)
                
            case .failure(let error):
                LMLogger.log("❌ Confirmation failed: \(error.localizedDescription)")
                self?.showError("Failed to confirm suggestion")
            }
        }
    }
    
    @objc private func regenerateButtonTapped() {
        LMLogger.log("🔄 Regenerate button tapped")
        
        let alert = UIAlertController(
            title: "Regenerate Suggestions",
            message: "This will generate new composition suggestions. Continue?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Regenerate", style: .default) { [weak self] _ in
            // TODO: Implement actual regeneration API call
            LMLogger.log("🔄 Regeneration requested")
            self?.showError("Regeneration feature coming soon")
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - Navigation
    
    private func navigateToCamera(with suggestion: LMCompositionSuggestion) {
        // 转换为 SuggestionDisplayModel
        let displayModel = SuggestionDisplayModel(
            id: suggestion.id,
            title: suggestion.sceneType,
            description: "Rank: \(suggestion.rank)",
            imageURL: suggestion.imageUrl,
            image: nil,
            personBoundingBox: suggestion.personBoundingBox,
            confidence: suggestion.score,
            isFavorite: false,
            isGenerating: false
        )
        
        // 返回相机页面并传递选中的建议
        if let cameraPage = navigationController?.viewControllers.first(where: { $0 is LMCameraPage }) as? LMCameraPage {
            // TODO: 添加方法将建议传递给相机页面
            navigationController?.popToViewController(cameraPage, animated: true)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentSelectedSuggestion() -> LMCompositionSuggestion? {
        // 从轮播视图获取当前选中的索引
        // TODO: 需要在 LMSuggestionsCarouselView 中添加获取当前索引的方法
        guard !suggestions.isEmpty else { return nil }
        return suggestions.first { $0.ready }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - LMSuggestionsCarouselViewDelegate
extension LMShowSuggestionsPage: LMSuggestionsCarouselViewDelegate {
    
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didSelectSuggestion suggestion: LMCompositionSuggestion, at index: Int) {
        LMLogger.log("📱 Selected suggestion at index: \(index)")
        // 更新选择状态
    }
    
    func suggestionsCarouselView(_ view: LMSuggestionsCarouselView, didToggleFavorite suggestion: LMCompositionSuggestion, at index: Int) {
        LMLogger.log("❤️ Toggling favorite for suggestion: \(suggestion.id)")
        
        // TODO: Call API to save/unsave suggestion
        // For now, just show feedback
        let message = "Suggestion saved to favorites"
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
    
    func suggestionsCarouselViewDidRequestMoreSuggestions(_ view: LMSuggestionsCarouselView) {
        LMLogger.log("🔄 Requesting more suggestions")
        
        // TODO: Implement pagination or regeneration
        showError("No more suggestions available. Try regenerating.")
    }
}
