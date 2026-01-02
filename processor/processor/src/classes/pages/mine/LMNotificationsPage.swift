//
//  LMNotificationsPage.swift
//  processor
//
//  Created by muz on 2025/10/19.
//

import UIKit
import SnapKit

// MARK: - Notification Data Model
struct NotificationItem {
    let id: String
    let title: String
    let message: String
    let timeAgo: String
    let isUnread: Bool
    let iconType: NotificationIconType
    let fullContent: String
    
    enum NotificationIconType {
        case system
        case update
        case warning
        case info
        
        var iconName: String {
            switch self {
            case .system:
                return "megaphone.fill"
            case .update:
                return "arrow.down.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .info:
                return "info.circle.fill"
            }
        }
        
        var backgroundColor: UIColor {
            switch self {
            case .system:
                return UIColor.systemYellow.withAlphaComponent(0.2)
            case .update:
                return UIColor.systemBlue.withAlphaComponent(0.2)
            case .warning:
                return UIColor.systemOrange.withAlphaComponent(0.2)
            case .info:
                return UIColor.systemTeal.withAlphaComponent(0.2)
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
            }
        }
    }
}

class LMNotificationsPage: LMPageWrapper {
    
    // MARK: - UI Components
    private let tableView = UITableView()
    
    // MARK: - Properties
    private var notifications: [NotificationItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.notifications
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        loadNotificationData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}

// MARK: - Setup Methods
extension LMNotificationsPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(tableView)
        setupTableView()
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.register(LMNotificationTableViewCell.self, forCellReuseIdentifier: "NotificationCell")
    }
}

// MARK: - Layout Configuration
extension LMNotificationsPage {
    
    private func configureLayoutConstraints() {
        tableView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(12)
            make.trailing.equalTo(-12)
        }
    }
}

// MARK: - Data Loading
extension LMNotificationsPage {
    
    private func loadNotificationData() {
        notifications = [
            NotificationItem(
                id: "notif_1",
                title: "System Notification",
                message: "Welcome to InspireCam! We've added new AI composition features to help you take better photos. Try the new Premium Mode for unlimited access to all features.",
                timeAgo: "2 min ago",
                isUnread: true,
                iconType: .system,
                fullContent: """
                Welcome to InspireCam! We've added new AI composition features to help you take better photos. Try the new Premium Mode for unlimited access to all features.

                Here are some of the exciting new features you can explore:

                • AI Composition Analysis: Get real-time suggestions for better photo composition
                • Premium Mode: Access unlimited Inspire Points and advanced features
                • Smart Suggestions: AI-powered recommendations based on your shooting style
                • Enhanced Gallery: Better organization and management of your photos

                We're constantly working to improve your photography experience. If you have any feedback or suggestions, please don't hesitate to contact us through the app settings.

                Happy shooting!
                The InspireCam Team
                """
            ),
            NotificationItem(
                id: "notif_2",
                title: "System Notification",
                message: "Your Inspire Points are running low. Watch ads or upgrade to Plus Plan to get more points and continue using AI features.",
                timeAgo: "1 hour ago",
                isUnread: true,
                iconType: .warning,
                fullContent: """
                Your Inspire Points are running low. Watch ads or upgrade to Plus Plan to get more points and continue using AI features.

                Current Status:
                • Inspire Points: 1 remaining
                • Plan: Free Plan
                • Next renewal: N/A

                Options to get more points:
                • Watch ads: Get 1 point per ad (up to 3 per day)
                • Upgrade to Plus Plan: Get unlimited points
                • Complete daily challenges: Earn bonus points

                Don't let your creativity be limited! Upgrade now to continue using all AI features without interruption.
                """
            ),
            NotificationItem(
                id: "notif_3",
                title: "System Notification",
                message: "New composition suggestions are available! Check out the latest AI-generated ideas for your next photo session.",
                timeAgo: "1 day ago",
                isUnread: false,
                iconType: .info,
                fullContent: """
                New composition suggestions are available! Check out the latest AI-generated ideas for your next photo session.

                What's New:
                • 15 new composition templates
                • Seasonal photography tips
                • Portrait mode enhancements
                • Landscape composition guides

                These suggestions are based on trending photography styles and user preferences. Visit the Gallery section to explore these new ideas and improve your photography skills.
                """
            ),
            NotificationItem(
                id: "notif_4",
                title: "System Notification",
                message: "Thank you for using InspireCam! Your feedback helps us improve the app. Rate us on the App Store if you enjoy using our features.",
                timeAgo: "7 days ago",
                isUnread: false,
                iconType: .info,
                fullContent: """
                Thank you for using InspireCam! Your feedback helps us improve the app. Rate us on the App Store if you enjoy using our features.

                Your Support Matters:
                • Help other users discover InspireCam
                • Share your experience with the community
                • Contribute to app improvements
                • Get priority support as a valued user

                We appreciate every review and rating. Your feedback helps us understand what features you love and what we can improve.

                Thank you for being part of the InspireCam community!
                """
            ),
            NotificationItem(
                id: "notif_5",
                title: "System Notification",
                message: "App update available! Version 1.1.0 includes bug fixes and performance improvements. Update now for the best experience.",
                timeAgo: "30 days ago",
                isUnread: false,
                iconType: .update,
                fullContent: """
                App update available! Version 1.1.0 includes bug fixes and performance improvements. Update now for the best experience.

                What's New in Version 1.1.0:
                • Fixed camera preview lag on older devices
                • Improved AI processing speed
                • Enhanced user interface responsiveness
                • Better memory management
                • Fixed crash issues on iOS 15

                Update Instructions:
                1. Open the App Store
                2. Search for "InspireCam"
                3. Tap "Update" button
                4. Restart the app after update

                We recommend updating to the latest version for the best performance and stability.
                """
            )
        ]
        
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension LMNotificationsPage: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NotificationCell", for: indexPath) as! LMNotificationTableViewCell
        let notification = notifications[indexPath.row]
        cell.configure(with: notification, isLast: indexPath.row == notifications.count - 1)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension LMNotificationsPage: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let notification = notifications[indexPath.row]
        
        // 标记为已读
        if notification.isUnread {
            notifications[indexPath.row] = NotificationItem(
                id: notification.id,
                title: notification.title,
                message: notification.message,
                timeAgo: notification.timeAgo,
                isUnread: false,
                iconType: notification.iconType,
                fullContent: notification.fullContent
            )
            
            // 更新cell
            if let cell = tableView.cellForRow(at: indexPath) as? LMNotificationTableViewCell {
                cell.configure(with: notifications[indexPath.row], isLast: indexPath.row == notifications.count - 1)
            }
        }
        
        // 导航到详情页
        let detailPage = LMMessageDetailPage(notification: notification)
        navigationController?.pushViewController(detailPage, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}
