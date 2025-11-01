//
//  LMNotificationTableViewCell.swift
//  processor
//
//  Created by muz on 2025/11/1.
//

import UIKit

// MARK: - Custom Table View Cell
class LMNotificationTableViewCell: UITableViewCell {
    
    private let iconContainerView = UIView()
    private let iconImageView = UIImageView()
    private let unreadIndicator = UIView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let messageLabel = UILabel()
    private let separatorView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
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
        iconImageView.image = UIImage(named: "bullhorn_yellow")
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
    
    func configure(with notification: NotificationItem, isLast: Bool) {
        
        titleLabel.text = notification.title
        timeLabel.text = notification.timeAgo
        messageLabel.text = notification.message
        
        unreadIndicator.isHidden = !notification.isUnread
        separatorView.isHidden = isLast
        
        // 添加点击效果
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped))
//        addGestureRecognizer(tapGesture)
    }
    
    @objc private func cellTapped() {
        UIView.animate(withDuration: 0.1, animations: {
            self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.transform = CGAffineTransform.identity
            }
        }
    }
}
