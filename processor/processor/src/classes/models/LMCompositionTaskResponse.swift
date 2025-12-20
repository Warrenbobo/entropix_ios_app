//
//  LMCompositionTaskResponse.swift
//  processor
//
//  构图任务响应模型
//

import Foundation

struct LMCompositionTaskResponse: Codable {
    let taskId: String?
    let status: String?
    let suggestions: [LMCompositionSuggestion]?
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case status
        case suggestions
    }
}

// MARK: - Type Alias for Backward Compatibility
typealias CompositionTaskResponse = LMCompositionTaskResponse
