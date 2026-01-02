//
//  LMCompositionSuggestion.swift
//  processor
//
//  构图建议模型
//  Updated: 2025-01-16 - 所有属性改为 optional
//

import Foundation

struct LMCompositionSuggestion: Codable {
    var id: String?
    var sceneType: String?
    var source: String?
    var ready: Bool?
    var imageUrl: String?
    var width: Int?
    var height: Int?
    var rank: Int?
    var score: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case sceneType = "scene_type"
        case source
        case ready
        case imageUrl = "image_url"
        case width
        case height
        case rank
        case score
    }
    
    /// 是否为占位符
    var isPlaceholder: Bool {
        return source == "placeholder" || ready == false
    }
    
    /// 是否为检索结果
    var isRetrieved: Bool {
        return source == "retrieved"
    }
    
    /// 是否为生成结果
    var isGenerated: Bool {
        return source == "generated"
    }
    
    /// 是否为 AIGC 生成的图片（当 source = "generated" 时显示 AIGC 标签）
    var isAIGC: Bool {
        return source == "generated"
    }
    
    /// 获取宽高比，如果后端没有返回则根据宽高计算
    func getAspectRatio() -> Double {
        if let width = width, let height = height, height > 0 {
            return Double(width) / Double(height)
        }
        return 0.75 // 默认 3:4 = 0.75
    }
}

// MARK: - Type Alias for Backward Compatibility
typealias LMSuggestion = LMCompositionSuggestion
