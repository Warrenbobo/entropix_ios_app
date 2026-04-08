//
//  LMNotificationsPage.swift
//  processor
//
//  通知列表页面 - 支持分页加载、下拉刷新、已读状态管理
//

import UIKit
import SnapKit

class LMNotificationsPage: LMPageWrapper {
    
    override var usesMineNavigationBarStyle: Bool { true }
    
    // MARK: - UI Components
    private let tableView = UITableView()
    private let refreshControl = UIRefreshControl()
    private let emptyStateView = LMEmptyStateView()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    // MARK: - Properties
    private var notifications: [LMNotificationModel] = []
    private var isLoadingMore = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.notifications
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        setupObservers()
        loadNotificationData(refresh: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Setup Methods
extension LMNotificationsPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        setupTableView()
        setupEmptyStateView()
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.register(LMNotificationTableViewCell.self, forCellReuseIdentifier: "NotificationCell")
        
        // 下拉刷新
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        // 底部加载指示器
        loadingIndicator.hidesWhenStopped = true
        let footerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 50))
        loadingIndicator.center = footerView.center
        footerView.addSubview(loadingIndicator)
        tableView.tableFooterView = footerView
    }
    
    private func setupEmptyStateView() {
        emptyStateView.configure(
            icon: UIImage(systemName: "bell.slash"),
            title: LMText.settings.noNewNotification,
            message: nil
        )
        emptyStateView.isHidden = true
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(notificationsDidChange),
            name: LMNotificationManager.notificationsDidChangeNotification,
            object: nil
        )
    }
}

// MARK: - Layout Configuration
extension LMNotificationsPage {
    
    private func configureLayoutConstraints() {
        tableView.snp.makeConstraints { make in
            make.top.bottom.equalTo(view.safeAreaLayoutGuide)
            make.leading.equalTo(12)
            make.trailing.equalTo(-12)
        }
        
        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }
    }
}

// MARK: - Data Loading
extension LMNotificationsPage {
    
    private func loadNotificationData(refresh: Bool) {
        LMNotificationManager.shared.fetchNotifications(refresh: refresh) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.refreshControl.endRefreshing()
                
                switch result {
                case .success(let notifications):
                    self.notifications = notifications
                    self.tableView.reloadData()
                    self.updateEmptyState()
                    
                case .failure(let error):
                    LMLogger.log("❌ Failed to load notifications: \(error.localizedDescription)")
                    self.updateEmptyState()
                }
            }
        }
    }
    
    private func loadMoreNotifications() {
        guard !isLoadingMore, LMNotificationManager.shared.hasMore else { return }
        
        isLoadingMore = true
        loadingIndicator.startAnimating()
        
        LMNotificationManager.shared.loadMoreNotifications { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoadingMore = false
                self.loadingIndicator.stopAnimating()
                
                switch result {
                case .success(let notifications):
                    self.notifications = notifications
                    self.tableView.reloadData()
                    
                case .failure(let error):
                    LMLogger.log("❌ Failed to load more notifications: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !notifications.isEmpty
        tableView.isHidden = notifications.isEmpty
    }
    
    @objc private func handleRefresh() {
        loadNotificationData(refresh: true)
    }
    
    @objc private func notificationsDidChange() {
        notifications = LMNotificationManager.shared.notifications
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
        if !notification.isRead {
            LMNotificationManager.shared.markAsRead(notification: notification)
            notifications[indexPath.row].isRead = true
            
            // 更新cell
            if let cell = tableView.cellForRow(at: indexPath) as? LMNotificationTableViewCell {
                cell.configure(with: notifications[indexPath.row], isLast: indexPath.row == notifications.count - 1)
            }
        }
        
        // 导航到详情页
        let detailPage = LMNotificationDetailPage(notification: notification)
        navigationController?.pushViewController(detailPage, animated: true)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    // 滚动到底部时加载更多
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height
        
        if offsetY > contentHeight - frameHeight - 100 {
            loadMoreNotifications()
        }
    }
}

// MARK: - Empty State View
class LMEmptyStateView: UIView {
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(messageLabel)
        
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .systemGray3
        
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .systemGray
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .systemGray2
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        iconImageView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.size.equalTo(60)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview()
        }
        
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    func configure(icon: UIImage?, title: String, message: String?) {
        iconImageView.image = icon
        titleLabel.text = title
        messageLabel.text = message
        messageLabel.isHidden = message == nil
    }
}
