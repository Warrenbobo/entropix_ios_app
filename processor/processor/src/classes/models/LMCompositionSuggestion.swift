//
//  LMCompositionSuggestion.swift
//  processor
//
//  构图建议模型
//

import Foundation

struct LMCompositionSuggestion: Codable {
    let id: String
    let sceneType: String
    let source: String
    let ready: Bool
    let imageUrl: String?
    let similarImageUrl: String?
    let rank: Int
    let score: Double?
    let modelVersion: String
    let personBoundingBox: BoundingBox?
    let aspectRatio: Double?
    
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
        case personBoundingBox = "person_bounding_box"
        case aspectRatio = "aspect_ratio"
    }
    
    /// 获取宽高比，如果后端没有返回则使用默认值 3:4
    func getAspectRatio() -> Double {
        return aspectRatio ?? 0.75 // 默认 3:4 = 0.75
    }
}

// MARK: - Type Alias for Backward Compatibility
typealias LMSuggestion = LMCompositionSuggestion
