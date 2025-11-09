//
//  SuggestionItem.swift
//  processor
//
//  建议项模型（用于内部处理）
//

import Foundation

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

enum SuggestionSource: String, Codable {
    case retrieved = "retrieved"
    case generated = "generated"
    case placeholder = "placeholder"
}
