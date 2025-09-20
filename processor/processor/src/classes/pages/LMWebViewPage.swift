//
//  LMWebViewPage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import WebKit

class LMWebViewPage: LMPageWrapper {
    
    /// 前往WebView页面
    public static func toWebView(_ path: String, title: String) {
        let webview = LMWebViewPage()
        webview.navigationItem.title = title
        webview.urlPath = path
        AppTheme.Screen.navigationController?.pushViewController(webview, animated: true)
    }
    
    private lazy var webview = {
        let configuration = WKWebViewConfiguration()
        let webview = WKWebView(frame: .zero, configuration: configuration)
        webview.scrollView.showsVerticalScrollIndicator = false
        webview.scrollView.showsHorizontalScrollIndicator = false
        return webview
    }()
    
    private var urlPath: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webview.navigationDelegate = self
        if #available(iOS 16.4, *) {
            webview.isInspectable = true
        }
        contentView.addSubview(webview)
        let navigatorBackgroundView = UIView()
        navigatorBackgroundView.backgroundColor = .white
        view.addSubview(navigatorBackgroundView)
        navigatorBackgroundView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(AppTheme.Screen.navigatorHeight)
        }
        webview.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        loadWebViewURLRequest(urlPath ?? "")
    }
    
    /// 加载内容
    private func loadWebViewURLRequest(_ path: String) {
        if let url = URL(string: path) {
            let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
            webview.load(request)
        } else {
            LMLogger.log("当前WebView的路径不合规： \(path)")
        }
    }
}

extension LMWebViewPage: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        LMLogger.log("start = \(String(describing: webView.url?.absoluteString))")
    }
}
