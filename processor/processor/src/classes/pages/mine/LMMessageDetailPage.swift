//
//  LMMessageDetailPage.swift
//  processor
//
//  Created by muz on 2025/10/19.
//

import UIKit
import SnapKit

class LMMessageDetailPage: LMPageWrapper {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let containerView = UIView()
    
    // Header components
    private let headerView = UIView()
    private let iconContainerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    
    // Content components
    private let contentLabel = UILabel()
    
    // MARK: - Properties
    private let notification: NotificationItem
    
    init(notification: NotificationItem) {
        self.notification = notification
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = "Notification"
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        updateContentWithNotification()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}

// MARK: - Setup Methods
extension LMMessageDetailPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(containerView)
        
        containerView.addSubview(headerView)
        containerView.addSubview(contentLabel)
        
        setupHeaderComponents()
        setupContentComponents()
    }
    
    private func setupHeaderComponents() {
        headerView.addSubview(iconContainerView)
        iconContainerView.addSubview(iconImageView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(timeLabel)
        
        // Icon container
        iconContainerView.layer.cornerRadius = 12
        
        // Icon image
        iconImageView.contentMode = .scaleAspectFit
        
        // Title label
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 0
        
        // Time label
        timeLabel.font = UIFont.systemFont(ofSize: 14)
        timeLabel.textColor = UIColor.systemGray2
        timeLabel.numberOfLines = 1
    }
    
    private func setupContentComponents() {
        contentLabel.font = UIFont.systemFont(ofSize: 16)
        contentLabel.textColor = UIColor.label
        contentLabel.numberOfLines = 0
        contentLabel.lineBreakMode = .byWordWrapping
        
        // Set line height for better readability
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 12
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        
        contentLabel.attributedText = NSAttributedString(string: "", attributes: attributes)
    }
}

// MARK: - Layout Configuration
extension LMMessageDetailPage {
    
    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-24)
        }
        
        // Header view
        headerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        iconContainerView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.size.equalTo(48)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconContainerView.snp.trailing).offset(16)
            make.top.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        
        timeLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-24)
        }
        
        // Content label
        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-24)
        }
    }
}

// MARK: - Style Configuration
extension LMMessageDetailPage {
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = UIColor.systemGroupedBackground
        scrollView.backgroundColor = UIColor.clear
        scrollView.showsVerticalScrollIndicator = false
        contentView.backgroundColor = UIColor.clear
        
        // Container styling
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.1
    }
}

// MARK: - Content Update
extension LMMessageDetailPage {
    
    private func updateContentWithNotification() {
        // Update icon
        iconContainerView.backgroundColor = notification.iconType.backgroundColor
        iconImageView.image = UIImage(systemName: notification.iconType.iconName)
        iconImageView.tintColor = notification.iconType.iconColor
        
        // Update title and time
        titleLabel.text = notification.title
        timeLabel.text = notification.timeAgo
        
        // Update content with formatted text
        updateContentText()
    }
    
    private func updateContentText() {
        let content = notification.fullContent
        
        // Create attributed string with proper formatting
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 12
        
        let attributedString = NSMutableAttributedString(string: content)
        
        // Apply base attributes
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        
        attributedString.addAttributes(baseAttributes, range: NSRange(location: 0, length: content.count))
        
        // Format bullet points
        formatBulletPoints(in: attributedString)
        
        // Format bold text
        formatBoldText(in: attributedString)
        
        // Format section headers
        formatSectionHeaders(in: attributedString)
        
        contentLabel.attributedText = attributedString
    }
    
    private func formatBulletPoints(in attributedString: NSMutableAttributedString) {
        let content = attributedString.string
        let bulletPattern = "• "
        
        var searchRange = NSRange(location: 0, length: content.count)
        
        while true {
            let range = (content as NSString).range(of: bulletPattern, options: [], range: searchRange)
            if range.location == NSNotFound { break }
            
            // Make bullet point bold and colored
            attributedString.addAttributes([
                .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                .foregroundColor: UIColor.systemBlue
            ], range: range)
            
            searchRange = NSRange(location: range.location + range.length, length: content.count - range.location - range.length)
        }
    }
    
    private func formatBoldText(in attributedString: NSMutableAttributedString) {
        let content = attributedString.string
        let boldPattern = "([A-Za-z\\s]+:)"
        
        do {
            let regex = try NSRegularExpression(pattern: boldPattern, options: [])
            let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: content.count))
            
            for match in matches {
                attributedString.addAttributes([
                    .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                    .foregroundColor: UIColor.label
                ], range: match.range)
            }
        } catch {
            print("Regex error: \(error)")
        }
    }
    
    private func formatSectionHeaders(in attributedString: NSMutableAttributedString) {
        let content = attributedString.string
        let lines = content.components(separatedBy: .newlines)
        
        var currentLocation = 0
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Check if line ends with colon (section header)
            if trimmedLine.hasSuffix(":") && !trimmedLine.hasPrefix("•") && trimmedLine.count > 1 {
                let range = NSRange(location: currentLocation, length: line.count)
                
                if range.location + range.length <= content.count {
                    attributedString.addAttributes([
                        .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                        .foregroundColor: UIColor.label
                    ], range: range)
                }
            }
            
            currentLocation += line.count + 1 // +1 for newline character
        }
    }
}

// MARK: - Public Methods
extension LMMessageDetailPage {
    
    func markAsRead() {
        // This method can be called to mark the notification as read
        // Implementation would depend on your data persistence layer
        print("Notification \(notification.id) marked as read")
    }
}