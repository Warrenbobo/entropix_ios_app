//
//  LMDebugMenuPage.swift
//  processor
//
//  调试菜单页面
//

import UIKit
import SnapKit

class LMDebugMenuPage: UIViewController {
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.delegate = self
        table.dataSource = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        return table
    }()
    
    // MARK: - Data
    
    private let menuItems: [(title: String, action: () -> Void)] = []
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 刷新数据以显示最新的记录数量和测试模式状态
        navigationController?.setNavigationBarHidden(false,
                                                     animated: animated)
        tableView.reloadData()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Debug Menu"
        view.backgroundColor = .systemBackground
        
        // 添加关闭按钮（如果是 modal 展示）
        if presentingViewController != nil {
            let closeButton = UIBarButtonItem(
                title: "Close",
                style: .plain,
                target: self,
                action: #selector(closeButtonTapped)
            )
            navigationItem.leftBarButtonItem = closeButton
        }
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // MARK: - Menu Items
    
    private func getMenuItems() -> [(title: String, subtitle: String?, action: () -> Void)] {
        return [
            (
                title: "📝 Inspire Me Records",
                subtitle: "\(LMTestDataManager.shared.getAllInspireMeRecords().count) records",
                action: { [weak self] in
                    self?.openInspireMeRecords()
                }
            ),
            (
                title: "🧪 Test Mode Settings",
                subtitle: LMTestDataManager.shared.isTestModeEnabled ? "Enabled" : "Disabled",
                action: { [weak self] in
                    self?.openTestModeSettings()
                }
            ),
            (
                title: "🗑️ Clear All Records",
                subtitle: "Delete all Inspire Me records",
                action: { [weak self] in
                    self?.clearAllRecords()
                }
            )
        ]
    }
    
    // MARK: - Actions
    
    private func openInspireMeRecords() {
        let recordsPage = LMInspireMeRecordsPage()
        navigationController?.pushViewController(recordsPage, animated: true)
    }
    
    private func openTestModeSettings() {
        let alert = UIAlertController(
            title: "Test Mode Settings",
            message: "Current Status: \(LMTestDataManager.shared.isTestModeEnabled ? "Enabled" : "Disabled")",
            preferredStyle: .actionSheet
        )
        
        alert.addAction(UIAlertAction(title: "Enable Test Mode", style: .default) { _ in
            LMTestDataManager.shared.isTestModeEnabled = true
            LMTestDataManager.shared.printTestModeStatus()
            self.tableView.reloadData()
        })
        
        alert.addAction(UIAlertAction(title: "Disable Test Mode", style: .default) { _ in
            LMTestDataManager.shared.isTestModeEnabled = false
            LMTestDataManager.shared.printTestModeStatus()
            self.tableView.reloadData()
        })
        
        alert.addAction(UIAlertAction(title: "Switch to Free User", style: .default) { _ in
            LMTestDataManager.shared.switchTestUser(to: .free)
            self.tableView.reloadData()
        })
        
        alert.addAction(UIAlertAction(title: "Switch to Plus User", style: .default) { _ in
            LMTestDataManager.shared.switchTestUser(to: .plus)
            self.tableView.reloadData()
        })
        
        alert.addAction(UIAlertAction(title: "Switch to Lifelong User", style: .default) { _ in
            LMTestDataManager.shared.switchTestUser(to: .lifelong)
            self.tableView.reloadData()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func clearAllRecords() {
        let alert = UIAlertController(
            title: "Clear All Records",
            message: "Are you sure you want to delete all Inspire Me records?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
            LMTestDataManager.shared.clearAllInspireMeRecords()
            self.tableView.reloadData()
            
            let successAlert = UIAlertController(
                title: "Cleared",
                message: "All records have been deleted",
                preferredStyle: .alert
            )
            self.present(successAlert, animated: true)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                successAlert.dismiss(animated: true)
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension LMDebugMenuPage: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return getMenuItems().count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "Cell")
        let item = getMenuItems()[indexPath.row]
        
        cell.textLabel?.text = item.title
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        
        cell.detailTextLabel?.text = item.subtitle
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.font = .systemFont(ofSize: 14)
        
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension LMDebugMenuPage: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = getMenuItems()[indexPath.row]
        item.action()
    }
}

// MARK: - Global Access Helper

extension UIViewController {
    
    /// 显示调试菜单（可以从任何地方调用）
    func showDebugMenu() {
        let debugMenu = LMDebugMenuPage()
        let navController = UINavigationController(rootViewController: debugMenu)
        present(navController, animated: true)
    }
}
