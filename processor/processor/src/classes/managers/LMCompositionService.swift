//
//  LMCompositionService.swift
//  processor
//
//  Created by muz on 2025/11/9.
//

import UIKit

enum LMCompositionTaskResultEventType: String {
    case like = "Like"
    case shot = "Shot"
}

class LMCompositionService {
    
    static let shared = LMCompositionService()
    
    private init() {}
    
    // MARK: - Type Aliases
    typealias CompositionTaskResponse = LMCompositionTaskResponse
    typealias CompositionStatusResponse = LMCompositionSuggestionsResponse
    typealias ConfirmSuggestionResponse = LMConfirmSuggestionResponse
    typealias CompositionHistoryResponse = LMCompositionResultsResponse
    typealias CompositionTaskResultResponse = LMEmptyModel
    
    // MARK: - 提交构图任务
    
    /// 提交构图任务
    /// - Parameters:
    ///   - originalImage: 原始场景图
    ///   - compressedImage: 压缩后的场景图（PRD 要求长边≤1080px）
    ///   - embeddings: 图像向量（768维）
    ///   - aspectRatio: 宽高比
    ///   - sceneType: 场景类型（可选）
    ///   - completion: 完成回调（使用统一的 LMApiCallback）
    func submitCompositionTask(
        originalImage: UIImage,
        compressedImage: UIImage,
        embeddings: [Float],
        aspectRatio: String,
        sceneType: String? = nil,
        completion: @escaping LMApiCallback<CompositionTaskResponse>
    ) {
        LMLogger.log("📤 Submitting composition task...")
        
        LMApiService.shared.submitCompositionTask(
            originalImage: originalImage,
            compressedImage: compressedImage,
            embeddings: embeddings,
            aspectRatio: aspectRatio,
            sceneType: sceneType,
            completion: completion
        )
    }
    
    // MARK: - 轮询任务状态
    
    /// 轮询任务状态
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - completion: 完成回调（使用统一的 LMApiCallback）
    func pollTaskStatus(
        taskId: String,
        completion: @escaping LMApiCallback<CompositionStatusResponse>
    ) {
        LMApiService.shared.getSuggestions(taskId: taskId, completion: completion)
    }
    
    // MARK: - 确认建议
    
    /// 确认选中的建议
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - suggestionId: 建议ID
    ///   - completion: 完成回调（使用统一的 LMApiCallback）
    func confirmSuggestion(
        taskId: String,
        suggestionId: String,
        completion: @escaping LMApiCallback<ConfirmSuggestionResponse>
    ) {
        LMApiService.shared.confirmSuggestion(
            taskId: taskId,
            suggestionId: suggestionId,
            completion: completion
        )
    }
    
    /// 上报 Suggestion 任务结果
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - eventType: 事件类型（如 Shot）
    ///   - suggestionId: 建议ID
    ///   - finalized: 是否为任务结束上报
    ///   - completion: 完成回调
    func reportSuggestionTaskResult(
        taskId: String,
        eventType: LMCompositionTaskResultEventType? = nil,
        suggestionId: String? = nil,
        finalized: Bool,
        completion: @escaping LMApiCallback<CompositionTaskResultResponse>
    ) {
        LMApiService.shared.reportSuggestionTaskResult(
            taskId: taskId,
            eventType: eventType,
            suggestionId: suggestionId,
            finalized: finalized,
            completion: completion
        )
    }
    
    // MARK: - 获取历史记录
    
    /// 获取历史构图结果
    /// - Parameters:
    ///   - page: 页码
    ///   - number: 每页数量
    ///   - completion: 完成回调（使用统一的 LMApiCallback）
    func fetchHistory(
        page: Int = 1,
        number: Int = 4,
        completion: @escaping LMApiCallback<CompositionHistoryResponse>
    ) {
        LMApiService.shared.getCompositionResults(
            page: page,
            number: number,
            completion: completion
        )
    }
}
