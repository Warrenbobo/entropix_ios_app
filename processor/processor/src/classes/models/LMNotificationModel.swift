//
//  LMNotificationModel.swift
//  processor
//
//  通知相关数据模型
//

import UIKit

// MARK: - Notification Response Model (API响应)

/// 通知列表响应模型
struct LMNotificationListResponse: Codable {
    let notifications: [LMNotificationModel]
    let nextCursor: String?
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case notifications
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        notifications = try container.decode([LMNotificationModel].self, forKey: .notifications)
        hasMore = try container.decode(Bool.self, forKey: .hasMore)
        
        // next_cursor 可能是 String 或 Int64，需要兼容处理
        if let stringCursor = try? container.decode(String.self, forKey: .nextCursor) {
            nextCursor = stringCursor
        } else if let intCursor = try? container.decode(Int64.self, forKey: .nextCursor) {
            nextCursor = String(intCursor)
        } else {
            nextCursor = nil
        }
    }
}

/// 单条通知模型
struct LMNotificationModel: Codable {
    let id: String
    let type: String
    let title: String
    let body: String
    let payload: String?
    let createdAt: String
    
    // 本地状态（非API字段）
    var isRead: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case title
        case body
        case payload
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decode(String.self, forKey: .body)
        payload = try container.decodeIfPresent(String.self, forKey: .payload)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        isRead = false
    }
    
    init(id: String, type: String, title: String, body: String, payload: String?, createdAt: String, isRead: Bool = false) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.payload = payload
        self.createdAt = createdAt
        self.isRead = isRead
    }
    
    /// 通知类型枚举
    var notificationType: NotificationType {
        return NotificationType(rawValue: type) ?? .system
    }
    
    /// 格式化的时间显示
    var formattedTimeAgo: String {
        return LMNotificationModel.formatTimeAgo(from: createdAt)
    }
    
    /// 预览消息（去除HTML标签，截取前100字符）
    var previewMessage: String {
        let plainText = body.stripHTMLTags()
        if plainText.count > 100 {
            return String(plainText.prefix(100)) + "..."
        }
        return plainText
    }
    
    /// 格式化时间为相对时间
    static func formatTimeAgo(from dateString: String) -> String {
        let dateFormatters: [DateFormatter] = {
            let formats = ["yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss'Z'"]
            return formats.map { format in
                let formatter = DateFormatter()
                formatter.dateFormat = format
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(identifier: "UTC")
                return formatter
            }
        }()
        
        var date: Date?
        for formatter in dateFormatters {
            if let parsedDate = formatter.date(from: dateString) {
                date = parsedDate
                break
            }
        }
        
        guard let notificationDate = date else {
            return dateString
        }
        
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: notificationDate, to: now)
        
        if let days = components.day, days >= 30 {
            return "30 days ago"
        } else if let days = components.day, days >= 1 {
            return "\(days) day\(days > 1 ? "s" : "") ago"
        } else if let hours = components.hour, hours >= 1 {
            return "\(hours) hour\(hours > 1 ? "s" : "") ago"
        } else if let minutes = components.minute, minutes >= 1 {
            return "\(minutes) minute\(minutes > 1 ? "s" : "") ago"
        } else {
            return "1 minute ago"
        }
    }
}

// MARK: - Notification Type

enum NotificationType: String, Codable {
    case system = "system"
    case update = "update"
    case warning = "warning"
    case info = "info"
    case promotion = "promotion"
    
    var iconName: String {
        switch self {
        case .system:
            return "bullhorn_yellow"
        case .update:
            return "arrow.down.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        case .promotion:
            return "gift.fill"
        }
    }
    
    var backgroundColor: UIColor {
        switch self {
        case .system:
            return .hexColor("#FEF9C2")
        case .update:
            return UIColor.systemBlue.withAlphaComponent(0.2)
        case .warning:
            return UIColor.systemOrange.withAlphaComponent(0.2)
        case .info:
            return UIColor.systemTeal.withAlphaComponent(0.2)
        case .promotion:
            return UIColor.systemPink.withAlphaComponent(0.2)
        }
    }
    
    var iconColor: UIColor {
        switch self {
        case .system:
            return UIColor.systemYellow
        case .update:
            return UIColor.systemBlue
        case .warning:
            return UIColor.systemOrange
        case .info:
            return UIColor.systemTeal
        case .promotion:
            return UIColor.systemPink
        }
    }
}

// MARK: - Mark Read Request/Response

/// 标记已读请求模型
struct LMMarkReadRequest: Codable {
    let cursor: String
}

/// 标记已读响应模型（空响应）
struct LMMarkReadResponse: Codable {
    // 空响应
}

// MARK: - String Extension for HTML

extension String {
    /// 去除HTML标签
    func stripHTMLTags() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        
        // 备用方案：使用正则表达式
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
