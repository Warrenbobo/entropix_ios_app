//
//  LMNotificationManager.swift
//  processor
//
//  通知管理器 - 负责通知的获取、缓存和已读状态管理
//

import Foundation

class LMNotificationManager {
    
    // MARK: - Singleton
    static let shared = LMNotificationManager()
    
    // MARK: - Properties
    
    /// 通知数据变化通知
    static let notificationsDidChangeNotification = Foundation.Notification.Name("LMNotificationsDidChange")
    
    /// 缓存的通知列表
    private(set) var notifications: [LMNotificationModel] = []
    
    /// 当前游标（用于分页）
    private var currentCursor: String?
    
    /// 是否还有更多数据
    private(set) var hasMore: Bool = true
    
    /// 是否正在加载
    private(set) var isLoading: Bool = false
    
    /// 本地已读游标（用于标记已读）
    private var localReadCursor: String? {
        get { UserDefaults.standard.string(forKey: "notification_read_cursor") }
        set { UserDefaults.standard.set(newValue, forKey: "notification_read_cursor") }
    }
    
    /// 本地已读ID集合
    private var localReadIds: Set<String> {
        get {
            let array = UserDefaults.standard.stringArray(forKey: "notification_read_ids") ?? []
            return Set(array)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "notification_read_ids")
        }
    }
    
    /// 未读通知数量
    var unreadCount: Int {
        return notifications.filter { !$0.isRead }.count
    }
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 获取通知列表（首次加载或刷新）
    func fetchNotifications(refresh: Bool = false, completion: @escaping (Result<[LMNotificationModel], Error>) -> Void) {
        guard !isLoading else {
            completion(.failure(NSError(domain: "LMNotificationManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Already loading"])))
            return
        }
        
        if refresh {
            currentCursor = nil
            hasMore = true
        }
        
        isLoading = true
        
        var params: [String: Any] = ["limit": 20]
        if let cursor = currentCursor {
            params["cursor"] = cursor
        }
        
        LMApiClient.request(
            LMApi.Notification.list,
            method: .get,
            params: params,
            type: LMNotificationListResponse.self
        ) { [weak self] response in
            guard let self = self else { return }
            self.isLoading = false
            
            if response.requestSuccess, let data = response.value {
                // 更新已读状态
                var updatedNotifications = data.notifications.map { notification -> LMNotificationModel in
                    var mutableNotification = notification
                    mutableNotification.isRead = self.localReadIds.contains(notification.id)
                    return mutableNotification
                }
                
                if refresh {
                    self.notifications = updatedNotifications
                } else {
                    self.notifications.append(contentsOf: updatedNotifications)
                }
                
                self.currentCursor = data.nextCursor
                self.hasMore = data.hasMore
                
                // 发送通知
                NotificationCenter.default.post(name: LMNotificationManager.notificationsDidChangeNotification, object: nil)
                
                completion(.success(self.notifications))
            } else {
                let error = NSError(
                    domain: "LMNotificationManager",
                    code: response.code ?? -1,
                    userInfo: [NSLocalizedDescriptionKey: response.message ?? "Failed to fetch notifications"]
                )
                completion(.failure(error))
            }
        }
    }
    
    /// 加载更多通知
    func loadMoreNotifications(completion: @escaping (Result<[LMNotificationModel], Error>) -> Void) {
        guard hasMore, !isLoading else {
            completion(.success(notifications))
            return
        }
        
        fetchNotifications(refresh: false, completion: completion)
    }
    
    /// 标记通知为已读（本地 + 异步同步到后端）
    func markAsRead(notification: LMNotificationModel) {
        // 本地标记已读
        var readIds = localReadIds
        readIds.insert(notification.id)
        localReadIds = readIds
        
        // 更新内存中的通知状态
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
        }
        
        // 发送通知
        NotificationCenter.default.post(name: LMNotificationManager.notificationsDidChangeNotification, object: nil)
        
        // 异步同步到后端（忽略失败）
        syncReadStatusToServer(cursor: notification.id)
    }
    
    /// 标记所有通知为已读
    func markAllAsRead() {
        var readIds = localReadIds
        for notification in notifications {
            readIds.insert(notification.id)
        }
        localReadIds = readIds
        
        // 更新内存中的通知状态
        for i in 0..<notifications.count {
            notifications[i].isRead = true
        }
        
        // 发送通知
        NotificationCenter.default.post(name: LMNotificationManager.notificationsDidChangeNotification, object: nil)
        
        // 同步最新的游标到后端
        if let latestNotification = notifications.first {
            syncReadStatusToServer(cursor: latestNotification.id)
        }
    }
    
    /// 清除缓存
    func clearCache() {
        notifications = []
        currentCursor = nil
        hasMore = true
    }
    
    // MARK: - Private Methods
    
    /// 同步已读状态到后端
    private func syncReadStatusToServer(cursor: String) {
        let params: [String: Any] = ["cursor": cursor]
        
        LMApiClient.request(
            LMApi.Notification.markRead,
            method: .post,
            params: params,
            type: LMMarkReadResponse.self
        ) { response in
            if response.requestSuccess {
                LMLogger.log("✅ Notification read status synced to server")
            } else {
                // 忽略失败，不影响用户体验
                LMLogger.log("⚠️ Failed to sync notification read status: \(response.message ?? "Unknown error")")
            }
        }
    }
}
