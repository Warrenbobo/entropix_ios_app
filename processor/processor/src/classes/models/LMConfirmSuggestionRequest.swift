//
//  LMConfirmSuggestionRequest.swift
//  processor
//
//  确认建议请求模型
//

import Foundation

struct LMConfirmSuggestionRequest: Codable {
    let taskId: String
    let suggestionId: String
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case suggestionId = "suggestion_id"
    }
}
