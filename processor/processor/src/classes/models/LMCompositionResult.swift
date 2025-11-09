//
//  LMCompositionResult.swift
//  processor
//
//  构图历史结果模型
//

import Foundation

struct LMCompositionResult: Codable {
    let taskId: String
    let suggestionId: String
    let imageUrl: String
    let sceneType: String
    let rank: Int
    let score: Double?
    let modelVersion: String
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
