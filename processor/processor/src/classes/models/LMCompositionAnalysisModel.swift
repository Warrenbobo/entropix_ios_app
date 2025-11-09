//
//  LMCompositionAnalysisModel.swift
//  processor
//
//  Created by Kiro on 2025/11/9.
//

import Foundation

/// 构图分析响应模型
struct CompositionAnalysisResponse: Codable {
    
    /// 构图建议列表
    let suggestions: [CompositionSuggestion]
    
    /// 分析的图像ID
    let imageId: String?
    
    /// 分析时间戳
    let timestamp: Double?
    
    enum CodingKeys: String, CodingKey {
        case suggestions
        case imageId = "image_id"
        case timestamp
    }
}

/// 单个构图建议
struct CompositionSuggestion: Codable {
    
    /// 建议ID
    let id: String
    
    /// 建议标题
    let title: String
    
    /// 建议描述
    let description: String
    
    /// 参考图像URL
    let referenceImageUrl: String?
    
    /// 人物边界框（用于AR引导）
    let personBoundingBox: BoundingBox?
    
    /// 置信度分数 (0-1)
    let confidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case referenceImageUrl = "reference_image_url"
        case personBoundingBox = "person_bounding_box"
        case confidence
    }
}

/// 边界框模型
struct BoundingBox: Codable {
    
    /// 左上角 x 坐标（归一化 0-1）
    let x: Double
    
    /// 左上角 y 坐标（归一化 0-1）
    let y: Double
    
    /// 宽度（归一化 0-1）
    let width: Double
    
    /// 高度（归一化 0-1）
    let height: Double
}
