//
//  LMCompositionResultsResponse.swift
//  processor
//
//  构图历史结果列表响应模型
//

import Foundation

struct LMCompositionResultsResponse: Codable {
    let results: [LMCompositionResult]
}
