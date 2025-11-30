//
//  LMCompositionAnalysisModel.swift
//  processor
//
//  Created by muz on 2025/11/9.
//

import Foundation

/// 构图分析响应模型
struct CompositionAnalysisResponse: Codable {
    
    /// 构图建议列表
    let suggestions: [LMCompositionSuggestion]
    
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


