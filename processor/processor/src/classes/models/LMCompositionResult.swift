//
//  LMCompositionResult.swift
//  processor
//
//  构图历史结果模型
//  Updated: 2025-01-16 - 所有属性改为 optional
//

import Foundation

struct LMCompositionResult: Codable {
    var taskId: String?
    var suggestionId: String?
    var imageUrl: String?
    var sceneType: String?
    var rank: Int?
    var score: Double?
    var modelVersion: String?
    var savedAt: String?
    
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
