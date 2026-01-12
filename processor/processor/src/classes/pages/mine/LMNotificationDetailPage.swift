//
//  LMNotificationDetailPage.swift
//  processor
//
//  通知详情页面 - 支持HTML内容渲染
//

import UIKit
import SnapKit
import WebKit

class LMNotificationDetailPage: LMPageWrapper {
    
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
    
    // Content components - 使用WKWebView渲染HTML
    private let webView = WKWebView()
    private var webViewHeightConstraint: Constraint?
    
    // MARK: - Properties
    private let notification: LMNotificationModel
    
    // MARK: - Initialization
    init(notification: LMNotificationModel) {
        self.notification = notification
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.notifications
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
extension LMNotificationDetailPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(containerView)
        
        containerView.addSubview(headerView)
        containerView.addSubview(webView)
        
        setupHeaderComponents()
        setupWebView()
    }
    
    private func setupHeaderComponents() {
        headerView.addSubview(iconContainerView)
        iconContainerView.addSubview(iconImageView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(timeLabel)
        
        // Icon container
        iconContainerView.layer.cornerRadius = 12
        iconContainerView.backgroundColor = notification.notificationType.backgroundColor
        
        // Icon image
        if let customIcon = UIImage(named: notification.notificationType.iconName) {
            iconImageView.image = customIcon
        } else {
            iconImageView.image = UIImage(systemName: notification.notificationType.iconName)
            iconImageView.tintColor = notification.notificationType.iconColor
        }
        iconImageView.contentMode = .center
        
        // Title label
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.numberOfLines = 0
        
        // Time label
        timeLabel.font = UIFont.systemFont(ofSize: 14)
        timeLabel.textColor = UIColor.systemGray2
        timeLabel.numberOfLines = 1
    }
    
    private func setupWebView() {
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
    }
}

// MARK: - Layout Configuration
extension LMNotificationDetailPage {
    
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
            make.leading.trailing.equalToSuperview().inset(16)
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
            make.bottom.equalToSuperview()
        }
        
        // WebView
        webView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(16)
            webViewHeightConstraint = make.height.equalTo(100).constraint
            make.bottom.equalToSuperview().offset(-24)
        }
    }
}

// MARK: - Style Configuration
extension LMNotificationDetailPage {
    
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
extension LMNotificationDetailPage {
    
    private func updateContentWithNotification() {
        // Update title and time
        titleLabel.text = notification.title
        timeLabel.text = notification.formattedTimeAgo
        
        // Load HTML content
        loadHTMLContent()
    }
    
    private func loadHTMLContent() {
        // 获取当前主题颜色
        let textColor = UIColor.label.hexString
        let backgroundColor = UIColor.systemBackground.hexString
        let linkColor = UIColor.systemBlue.hexString
        
        // 构建完整的HTML文档
        let htmlTemplate = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    font-size: 16px;
                    line-height: 1.6;
                    color: \(textColor);
                    background-color: transparent;
                    padding: 0;
                    word-wrap: break-word;
                }
                p {
                    margin-bottom: 12px;
                }
                a {
                    color: \(linkColor);
                    text-decoration: none;
                }
                ul, ol {
                    margin-left: 20px;
                    margin-bottom: 12px;
                }
                li {
                    margin-bottom: 6px;
                }
                h1, h2, h3, h4, h5, h6 {
                    margin-top: 16px;
                    margin-bottom: 8px;
                    font-weight: 600;
                }
                h1 { font-size: 24px; }
                h2 { font-size: 20px; }
                h3 { font-size: 18px; }
                img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    margin: 8px 0;
                }
                blockquote {
                    border-left: 3px solid \(linkColor);
                    padding-left: 12px;
                    margin: 12px 0;
                    color: #666;
                }
                code {
                    background-color: #f5f5f5;
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-family: monospace;
                }
                pre {
                    background-color: #f5f5f5;
                    padding: 12px;
                    border-radius: 8px;
                    overflow-x: auto;
                    margin: 12px 0;
                }
            </style>
        </head>
        <body>
            \(notification.body)
        </body>
        </html>
        """
        
        webView.loadHTMLString(htmlTemplate, baseURL: nil)
    }
}

// MARK: - WKNavigationDelegate
extension LMNotificationDetailPage: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // 获取内容高度并更新约束
        webView.evaluateJavaScript("document.body.scrollHeight") { [weak self] result, error in
            guard let self = self, let height = result as? CGFloat else { return }
            
            DispatchQueue.main.async {
                self.webViewHeightConstraint?.update(offset: height + 20)
                self.view.layoutIfNeeded()
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // 处理链接点击
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                UIApplication.shared.open(url)
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}

// MARK: - UIColor Extension
extension UIColor {
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let rgb: Int = (Int)(r * 255) << 16 | (Int)(g * 255) << 8 | (Int)(b * 255) << 0
        return String(format: "#%06x", rgb)
    }
}
