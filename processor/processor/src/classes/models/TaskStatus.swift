//
//  TaskStatus.swift
//  processor
//
//  任务状态枚举
//

import Foundation

enum TaskStatus: String, Codable {
    case processing = "processing"
    case completed = "completed"
    case failed = "failed"
    case timeout = "timeout"
}
