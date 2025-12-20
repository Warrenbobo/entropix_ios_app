//
//  LMCompositionSuggestionsResponse.swift
//  processor
//
//  构图建议响应模型
//  Updated: 2025-01-16 - 所有属性改为 optional
//

import Foundation

struct LMCompositionSuggestionsResponse: Codable {
    var status: String?
    var suggestions: [LMCompositionSuggestion]?
}
