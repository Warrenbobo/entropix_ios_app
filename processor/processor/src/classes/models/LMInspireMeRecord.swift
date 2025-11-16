//
//  LMInspireMeRecord.swift
//  processor
//
//  Inspire Me 数据记录模型
//

import UIKit

/// Inspire Me 数据记录
struct LMInspireMeRecord: Codable {
    let id: String
    let timestamp: Date
    let sceneFeature: [Float]?
    let imageData: Data?
    
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case sceneFeature
        case imageData
    }
    
    init(id: String = UUID().uuidString, timestamp: Date = Date(), sceneFeature: [Float]?, image: UIImage?) {
        self.id = id
        self.timestamp = timestamp
        self.sceneFeature = sceneFeature
        self.imageData = image?.jpegData(compressionQuality: 0.8)
    }
    
    /// 获取图片
    var image: UIImage? {
        guard let imageData = imageData else { return nil }
        return UIImage(data: imageData)
    }
    
    /// 格式化的时间戳
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}
