//
//  LMInspireMeRecordsPage.swift
//  processor
//
//  Inspire Me 数据记录展示页面
//

import UIKit
import SnapKit

class LMInspireMeRecordsPage: UIViewController {
    
    // MARK: - Properties
    
    private var records: [LMInspireMeRecord] = []
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.delegate = self
        table.dataSource = self
        table.register(LMInspireMeRecordCell.self, forCellReuseIdentifier: "RecordCell")
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 200
        table.separatorStyle = .singleLine
        table.backgroundColor = .systemBackground
        return table
    }()
    
    private lazy var emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No records yet\nUse Inspire Me to create records"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 16)
        label.isHidden = true
        return label
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadRecords()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false,
                                                     animated: animated)
        loadRecords()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Inspire Me Records"
        view.backgroundColor = .systemBackground
        
        // 添加清除按钮
        let clearButton = UIBarButtonItem(
            title: "Clear All",
            style: .plain,
            target: self,
            action: #selector(clearAllRecords)
        )
        clearButton.tintColor = .systemRed
        navigationItem.rightBarButtonItem = clearButton
        
        // 添加子视图
        view.addSubview(tableView)
        view.addSubview(emptyStateLabel)
        
        // 布局
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        emptyStateLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadRecords() {
        LMTestDataManager.shared.loadRecordsFromUserDefaults()
        records = LMTestDataManager.shared.getAllInspireMeRecords().reversed() // 最新的在前
        
        emptyStateLabel.isHidden = !records.isEmpty
        tableView.reloadData()
        
        LMLogger.log("📂 Loaded \(records.count) Inspire Me records")
    }
    
    // MARK: - Actions
    
    @objc private func clearAllRecords() {
        let alert = UIAlertController(
            title: "Clear All Records",
            message: "Are you sure you want to delete all Inspire Me records? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            LMTestDataManager.shared.clearAllInspireMeRecords()
            self?.loadRecords()
        })
        
        present(alert, animated: true)
    }
    
    private func deleteRecord(at indexPath: IndexPath) {
        let record = records[indexPath.row]
        LMTestDataManager.shared.deleteInspireMeRecord(id: record.id)
        loadRecords()
    }
    
    private func copySceneFeature(at indexPath: IndexPath) {
        let record = records[indexPath.row]
        UIPasteboard.general.string = String(describing: record.sceneFeature)
        
        // 显示提示
        let alert = UIAlertController(
            title: "Copied",
            message: "Scene feature copied to clipboard",
            preferredStyle: .alert
        )
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
    
    private func copyAllData(at indexPath: IndexPath) {
        let record = records[indexPath.row]
        let text = """
        ID: \(record.id)
        Timestamp: \(record.formattedTimestamp)
        Scene Feature: \(record.sceneFeature ?? [])
        """
        
        UIPasteboard.general.string = text
        
        // 显示提示
        let alert = UIAlertController(
            title: "Copied",
            message: "All data copied to clipboard",
            preferredStyle: .alert
        )
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
}

// MARK: - UITableViewDataSource

extension LMInspireMeRecordsPage: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return records.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RecordCell", for: indexPath) as! LMInspireMeRecordCell
        cell.configure(with: records[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension LMInspireMeRecordsPage: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let alert = UIAlertController(title: "Actions", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Copy Scene Feature", style: .default) { [weak self] _ in
            self?.copySceneFeature(at: indexPath)
        })
        
        alert.addAction(UIAlertAction(title: "Copy All Data", style: .default) { [weak self] _ in
            self?.copyAllData(at: indexPath)
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteRecord(at: indexPath)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.deleteRecord(at: indexPath)
            completion(true)
        }
        
        let copyAction = UIContextualAction(style: .normal, title: "Copy") { [weak self] _, _, completion in
            self?.copySceneFeature(at: indexPath)
            completion(true)
        }
        copyAction.backgroundColor = .systemBlue
        
        return UISwipeActionsConfiguration(actions: [deleteAction, copyAction])
    }
}

// MARK: - LMInspireMeRecordCell

class LMInspireMeRecordCell: UITableViewCell {
    
    // MARK: - UI Components
    
    private lazy var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray5
        return imageView
    }()
    
    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private lazy var idLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 1
        return label
    }()
    
    private lazy var sceneFeatureLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private var currentRecord: LMInspireMeRecord?
    
    // MARK: - Initialization
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        contentView.addSubview(thumbnailImageView)
        contentView.addSubview(timestampLabel)
        contentView.addSubview(idLabel)
        contentView.addSubview(sceneFeatureLabel)
        contentView.addSubview(copyButton)
        
        thumbnailImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(12)
            make.width.height.equalTo(80)
            make.bottom.lessThanOrEqualToSuperview().offset(-12)
        }
        
        timestampLabel.snp.makeConstraints { make in
            make.leading.equalTo(thumbnailImageView.snp.trailing).offset(12)
            make.top.equalTo(thumbnailImageView)
            make.trailing.equalTo(copyButton.snp.leading).offset(-8)
        }
        
        idLabel.snp.makeConstraints { make in
            make.leading.equalTo(timestampLabel)
            make.top.equalTo(timestampLabel.snp.bottom).offset(4)
            make.trailing.equalTo(copyButton.snp.leading).offset(-8)
        }
        
        sceneFeatureLabel.snp.makeConstraints { make in
            make.leading.equalTo(timestampLabel)
            make.top.equalTo(idLabel.snp.bottom).offset(8)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-12)
        }
        
        copyButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalToSuperview().offset(12)
            make.width.height.equalTo(44)
        }
    }
    
    // MARK: - Configuration
    
    func configure(with record: LMInspireMeRecord) {
        currentRecord = record
        
        timestampLabel.text = record.formattedTimestamp
        idLabel.text = "ID: \(record.id.prefix(8))..."
        sceneFeatureLabel.text = "数据长度 \(String(describing: record.sceneFeature?.count ?? 0))个"
        
        if let image = record.image {
            thumbnailImageView.image = image
        } else {
            thumbnailImageView.image = UIImage(systemName: "photo")
            thumbnailImageView.tintColor = .systemGray3
        }
    }
    
    // MARK: - Actions
    
    @objc private func copyButtonTapped() {
        guard let record = currentRecord else { return }
        UIPasteboard.general.string = String(describing: record.sceneFeature ?? [])
        
        // 视觉反馈
        copyButton.alpha = 0.5
        UIView.animate(withDuration: 0.2) {
            self.copyButton.alpha = 1.0
        }
    }
}
