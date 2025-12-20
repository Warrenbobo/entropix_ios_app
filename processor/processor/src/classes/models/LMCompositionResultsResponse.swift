//
//  LMCompositionResultsResponse.swift
//  processor
//
//  构图历史结果列表响应模型
//  Updated: 2025-01-16 - 所有属性改为 optional
//

import Foundation

struct LMCompositionResultsResponse: Codable {
    var results: [LMCompositionResult]?
}
