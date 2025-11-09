//
//  BoundingBox.swift
//  processor
//
//  边界框模型
//

import Foundation

// 边界框模型
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
