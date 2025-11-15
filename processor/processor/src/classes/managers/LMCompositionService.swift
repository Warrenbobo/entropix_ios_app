//
//  LMCompositionService.swift
//  processor
//
//  Created by Kiro on 2025/11/9.
//  Updated to use unified API service
//

import UIKit

class LMCompositionService {
    
    static let shared = LMCompositionService()
    
    private init() {}
    
    // MARK: - Type Aliases for Backward Compatibility
    typealias CompositionStatusResponse = LMCompositionSuggestionsResponse
    typealias ConfirmSuggestionResponse = LMConfirmSuggestionResponse
    typealias CompositionHistoryResponse = LMCompositionResultsResponse
    
    // MARK: - 提交构图任务
    
    /// 提交构图任务
    /// - Parameters:
    ///   - originalImage: 原始场景图
    ///   - optimizedImage: 预处理后的 960px 场景图
    ///   - embeddings: 图像向量（768维）
    ///   - aspectRatio: 宽高比
    ///   - sceneType: 场景类型（可选）
    ///   - completion: 完成回调
    func submitCompositionTask(
        originalImage: UIImage,
        optimizedImage: UIImage,
        embeddings: [Float],
        aspectRatio: String,
        sceneType: String? = nil,
        completion: @escaping (Result<CompositionTaskResponse, Error>) -> Void
    ) {
        LMLogger.log("📤 Submitting composition task...")
        
        // 验证向量维度
        guard embeddings.count == 768 else {
            let error = NSError(domain: "CompositionService", code: -1, 
                              userInfo: [NSLocalizedDescriptionKey: "Embeddings must be 768 dimensions"])
            completion(.failure(error))
            return
        }
        
        // 使用统一的 API 服务
        LMApiService.shared.submitCompositionTask(
            originalImage: originalImage,
            optimizedImage: optimizedImage,
            embeddings: embeddings,
            aspectRatio: aspectRatio,
            sceneType: sceneType
        ) { response in
            if response.requestSuccess, let data = response.value {
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "CompositionService",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Unknown error"]
                )
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 轮询任务状态
    
    /// 轮询任务状态
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - completion: 完成回调
    func pollTaskStatus(
        taskId: String,
        completion: @escaping (Result<CompositionStatusResponse, Error>) -> Void
    ) {
        LMApiService.shared.getSuggestions(taskId: taskId) { response in
            if response.requestSuccess, let data = response.value {
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "CompositionService",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Unknown error"]
                )
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 确认建议
    
    /// 确认选中的建议
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - suggestionId: 建议ID
    ///   - completion: 完成回调
    func confirmSuggestion(
        taskId: String,
        suggestionId: String,
        completion: @escaping (Result<ConfirmSuggestionResponse, Error>) -> Void
    ) {
        LMApiService.shared.confirmSuggestion(taskId: taskId, suggestionId: suggestionId) { response in
            if response.requestSuccess, let data = response.value {
                LMLogger.log("✅ Suggestion confirmed: \(suggestionId)")
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "CompositionService",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Unknown error"]
                )
                LMLogger.log("❌ Confirmation failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 获取历史记录
    
    /// 获取历史构图结果
    /// - Parameters:
    ///   - page: 页码
    ///   - number: 每页数量
    ///   - completion: 完成回调
    func fetchHistory(
        page: Int = 1,
        number: Int = 4,
        completion: @escaping (Result<CompositionHistoryResponse, Error>) -> Void
    ) {
        LMApiService.shared.getCompositionResults(page: page, number: number) { response in
            if response.requestSuccess, let data = response.value {
                completion(.success(data))
            } else {
                let error = NSError(
                    domain: "CompositionService",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Unknown error"]
                )
                completion(.failure(error))
            }
        }
    }
}
