//
//  LMCompositionJobListResponse.swift
//  processor
//
//  构图任务 Job 列表响应模型
//

import Foundation

struct LMCompositionJobListResponse: Codable {
    var taskId: String?
    var status: String?
    var totalJobs: Int?
    var completedJobs: Int?
    var failedJobs: Int?
    var timeoutAt: String?
    var jobIds: [String]?
    var allCompleted: Bool?
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case status
        case totalJobs = "total_jobs"
        case completedJobs = "completed_jobs"
        case failedJobs = "failed_jobs"
        case timeoutAt = "timeout_at"
        case jobIds = "job_ids"
        case allCompleted = "all_completed"
    }
}
