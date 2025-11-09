//
//  LMCompositionServiceModels.swift
//  processor
//
//  Created by Kiro on 2025/11/9.
//

import Foundation

// MARK: - 构图任务提交响应
struct CompositionTaskResponse: Codable {
    let taskId: String
    let status: TaskStatus
    let suggestions: [SuggestionItem]
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case status
        case suggestions
    }
}

// MARK: - 任务状态
enum TaskStatus: String, Codable {
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case timeout = "timeout"
}

// MARK: - 建议项
struct SuggestionItem: Codable {
    let id: String
    let sceneType: String?
    let source: SuggestionSource
    let ready: Bool
    let imageUrl: String?
    let similarImageUrl: String?
    let rank: Int
    let score: Double?
    let modelVersion: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case sceneType = "scene_type"
        case source
        case ready
        case imageUrl = "image_url"
        case similarImageUrl = "similar_image_url"
        case rank
        case score
        case modelVersion = "model_version"
    }
}

// MARK: - 建议来源
enum SuggestionSource: String, Codable {
    case retrieved = "retrieved"
    case generated = "generated"
    case placeholder = "placeholder"
}

// MARK: - 轮询任务状态响应
struct CompositionStatusResponse: Codable {
    let status: TaskStatus
    let suggestions: [SuggestionItem]
}

// MARK: - 确认建议请求
struct ConfirmSuggestionRequest: Codable {
    let taskId: String
    let suggestionId: String
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case suggestionId = "suggestion_id"
    }
}

// MARK: - 确认建议响应
struct ConfirmSuggestionResponse: Codable {
    let message: String
}

// MARK: - 历史构图结果
struct CompositionHistoryResponse: Codable {
    let results: [HistoryResult]
}

struct HistoryResult: Codable {
    let taskId: String
    let suggestionId: String
    let imageUrl: String
    let sceneType: String?
    let rank: Int
    let score: Double?
    let modelVersion: String?
    let savedAt: String
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case suggestionId = "suggestion_id"
        case imageUrl = "image_url"
        case sceneType = "scene_type"
        case rank
        case score
        case modelVersion = "model_version"
        case savedAt = "saved_at"
    }
}
