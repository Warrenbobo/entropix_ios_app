//
//  LMNotificationTableViewCell.swift
//  processor
//
//  通知列表Cell - 支持新的API数据模型
//

import UIKit
import SnapKit

class LMNotificationTableViewCell: UITableViewCell {
    
    // MARK: - UI Components
    private let iconContainerView = UIView()
    private let iconImageView = UIImageView()
    private let unreadIndicator = UIView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let messageLabel = UILabel()
    private let separatorView = UIView()
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
    // MARK: - Setup
    private func setupCell() {
        backgroundColor = UIColor.clear
        selectionStyle = .none
        
        contentView.addSubview(iconContainerView)
        iconContainerView.addSubview(iconImageView)
        iconContainerView.addSubview(unreadIndicator)
        contentView.addSubview(titleLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(messageLabel)
        contentView.addSubview(separatorView)
        
        setupIconContainer()
        setupLabels()
        setupSeparator()
        setupConstraints()
    }
    
    private func setupIconContainer() {
        iconContainerView.layer.cornerRadius = 8
        iconContainerView.backgroundColor = .hexColor("#FEF9C2")
        
        iconImageView.image = UIImage.lmSymbol("megaphone.fill", pointSize: 18)
        iconImageView.tintColor = .systemOrange
        iconImageView.contentMode = .center
        
        unreadIndicator.backgroundColor = UIColor.systemRed
        unreadIndicator.layer.cornerRadius = 6
        unreadIndicator.isHidden = true
    }
    
    private func setupLabels() {
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 1
        
        timeLabel.font = UIFont.systemFont(ofSize: 12)
        timeLabel.textColor = UIColor.systemGray2
        timeLabel.textAlignment = .right
        
        messageLabel.font = UIFont.systemFont(ofSize: 14)
        messageLabel.textColor = UIColor.systemGray
        messageLabel.numberOfLines = 2
        messageLabel.lineBreakMode = .byTruncatingTail
    }
    
    private func setupSeparator() {
        separatorView.backgroundColor = UIColor.systemGray6
    }
    
    private func setupConstraints() {
        iconContainerView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalToSuperview().offset(16)
            make.size.equalTo(40)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(20)
        }
        
        unreadIndicator.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(-2)
            make.trailing.equalToSuperview().offset(2)
            make.size.equalTo(12)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconContainerView.snp.trailing).offset(12)
            make.top.equalToSuperview().offset(16)
            make.trailing.lessThanOrEqualTo(timeLabel.snp.leading).offset(-8)
        }
        
        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(titleLabel)
            make.width.greaterThanOrEqualTo(60)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
        }
        
        separatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }
    
    // MARK: - Configuration (新API模型)
    func configure(with notification: LMNotificationModel, isLast: Bool) {
        titleLabel.text = notification.title
        timeLabel.text = notification.formattedTimeAgo
        messageLabel.text = notification.previewMessage
        
        // 更新图标样式
        let notificationType = notification.notificationType
        iconContainerView.backgroundColor = notificationType.backgroundColor
        
        // Prefer SF Symbol; fall back to raster only if a named asset still exists.
        if let symbol = UIImage(systemName: notificationType.iconName) {
            iconImageView.image = symbol.withRenderingMode(.alwaysTemplate)
            iconImageView.tintColor = notificationType.iconColor
        } else if let customIcon = UIImage(named: notificationType.iconName) {
            iconImageView.image = customIcon
        }
        
        // 未读状态
        unreadIndicator.isHidden = notification.isRead
        
        // 分隔线
        separatorView.isHidden = isLast
    }
    
    // MARK: - Highlight Effect
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        UIView.animate(withDuration: 0.1) {
            self.contentView.alpha = highlighted ? 0.7 : 1.0
        }
    }
}
