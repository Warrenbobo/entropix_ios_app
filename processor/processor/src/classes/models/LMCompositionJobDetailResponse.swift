//
//  LMCompositionJobDetailResponse.swift
//  processor
//
//  构图任务 Job 详情响应模型
//

import Foundation

struct LMCompositionJobDetailResponse: Codable {
    var job: LMCompositionJobInfo?
    var suggestions: [LMCompositionSuggestion]?
    var paging: LMPagingInfo?
    
    enum CodingKeys: String, CodingKey {
        case job
        case suggestions
        case paging
    }
}

struct LMCompositionJobInfo: Codable {
    var jobId: String?
    var status: String?
    var expectedVariants: Int?
    var generatedVariants: Int?
    var submittedAt: String?
    var completedAt: String?
    var timeoutAt: String?
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case expectedVariants = "expected_variants"
        case generatedVariants = "generated_variants"
        case submittedAt = "submitted_at"
        case completedAt = "completed_at"
        case timeoutAt = "timeout_at"
    }
}

struct LMPagingInfo: Codable {
    var offset: Int?
    var limit: Int?
    var hasMore: Bool?
    
    enum CodingKeys: String, CodingKey {
        case offset
        case limit
        case hasMore = "has_more"
    }
}
