//
//  LMCompositionTaskDetailResponse.swift
//  processor
//
//  构图任务详情响应模型
//

import Foundation

struct LMCompositionTaskDetailResponse: Codable {
    var task: LMCompositionTaskInfo?
    
    enum CodingKeys: String, CodingKey {
        case task
    }
}

struct LMCompositionTaskInfo: Codable {
    var taskId: String?
    var status: String?
    var totalJobs: Int?
    var completedJobs: Int?
    var failedJobs: Int?
    var timeoutAt: String?
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case status
        case totalJobs = "total_jobs"
        case completedJobs = "completed_jobs"
        case failedJobs = "failed_jobs"
        case timeoutAt = "timeout_at"
    }
}
