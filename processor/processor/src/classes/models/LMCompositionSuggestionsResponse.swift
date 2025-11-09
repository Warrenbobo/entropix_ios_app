//
//  LMCompositionSuggestionsResponse.swift
//  processor
//
//  构图建议响应模型
//

import Foundation

struct LMCompositionSuggestionsResponse: Codable {
    let status: String
    let suggestions: [LMCompositionSuggestion]
}
