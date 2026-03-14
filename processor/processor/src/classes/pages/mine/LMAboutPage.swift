//
//  LMAboutPage.swift
//  processor
//
//  Created by muz on 2025/10/6.
//

import UIKit
import SnapKit

class LMAboutPage: LMPageWrapper {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // White background container with rounded corners
    private let backgroundContainer = UIView()
    
    // App Developer Section
    private let appDeveloperTitleLabel = UILabel()
    private let appDeveloperValueLabel = UILabel()
    private let appDeveloperContainer = UIView()
    
    // App Version Section
    private let appVersionTitleLabel = UILabel()
    private let appVersionValueLabel = UILabel()
    private let appUpdateButton = UIButton(type: .system)
    private let appVersionContainer = UIView()
    
    // Privacy Policy Section
    private let privacyPolicyTitleLabel = UILabel()
    private let privacyPolicyButton = UIButton()
    private let privacyPolicyContainer = UIView()
    
    // Terms of Service Section
    private let termsOfServiceTitleLabel = UILabel()
    private let termsOfServiceButton = UIButton()
    private let termsOfServiceContainer = UIView()
    
    // Separator lines
    private let separatorLine1 = UIView()
    private let separatorLine2 = UIView()
    private let separatorLine3 = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.about
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        updateAppUpdateUI(hasUpdate: LMPackageManager.hasAvailableAppUpdate)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        refreshAppUpdateState()
    }
}

// MARK: - Setup Methods
extension LMAboutPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(backgroundContainer)
        
        // Add all containers to background container
        backgroundContainer.addSubview(appDeveloperContainer)
        backgroundContainer.addSubview(appVersionContainer)
        backgroundContainer.addSubview(privacyPolicyContainer)
        backgroundContainer.addSubview(termsOfServiceContainer)
        
        // Add separator lines
        backgroundContainer.addSubview(separatorLine1)
        backgroundContainer.addSubview(separatorLine2)
        backgroundContainer.addSubview(separatorLine3)
        
        // Add components to their respective containers
        appDeveloperContainer.addSubview(appDeveloperTitleLabel)
        appDeveloperContainer.addSubview(appDeveloperValueLabel)
        
        appVersionContainer.addSubview(appVersionTitleLabel)
        appVersionContainer.addSubview(appVersionValueLabel)
        appVersionContainer.addSubview(appUpdateButton)
        
        privacyPolicyContainer.addSubview(privacyPolicyTitleLabel)
        privacyPolicyContainer.addSubview(privacyPolicyButton)
        
        termsOfServiceContainer.addSubview(termsOfServiceTitleLabel)
        termsOfServiceContainer.addSubview(termsOfServiceButton)
        
        setupBackgroundContainer()
        setupSeparatorLines()
        setupAppDeveloperSection()
        setupAppVersionSection()
        setupPrivacyPolicySection()
        setupTermsOfServiceSection()
    }
    
    private func setupBackgroundContainer() {
        backgroundContainer.backgroundColor = UIColor.systemBackground
        backgroundContainer.layer.cornerRadius = 16
        backgroundContainer.layer.shadowColor = UIColor.black.cgColor
        backgroundContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        backgroundContainer.layer.shadowRadius = 8
        backgroundContainer.layer.shadowOpacity = 0.1
    }
    
    private func setupSeparatorLines() {
        [separatorLine1, separatorLine2, separatorLine3].forEach { line in
            line.backgroundColor = UIColor.separator
        }
    }
    
    private func setupAppDeveloperSection() {
        appDeveloperContainer.backgroundColor = UIColor.clear
        
        appDeveloperTitleLabel.text = LMText.settings.appDeveloper
        appDeveloperTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        appDeveloperTitleLabel.textColor = UIColor.systemGray
        appDeveloperTitleLabel.textAlignment = .left
        appDeveloperTitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        appDeveloperTitleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        appDeveloperValueLabel.text = LMText.settings.framAIstTeam
        appDeveloperValueLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        appDeveloperValueLabel.textColor = UIColor.label
        appDeveloperValueLabel.adjustsFontSizeToFitWidth = true
        appDeveloperValueLabel.textAlignment = .right
        appDeveloperValueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        appDeveloperValueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
    
    private func setupAppVersionSection() {
        appVersionContainer.backgroundColor = UIColor.clear
        
        appVersionTitleLabel.text = LMText.settings.appVersion
        appVersionTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        appVersionTitleLabel.textColor = UIColor.systemGray
        appVersionTitleLabel.textAlignment = .left
        appVersionTitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        appVersionTitleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        // 获取应用版本号
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        appVersionValueLabel.text = "v\(appVersion)"
        appVersionValueLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        appVersionValueLabel.textColor = UIColor.label
        appVersionValueLabel.textAlignment = .right
        appVersionValueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        appVersionValueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        appUpdateButton.setTitle(LMText.settings.appStoreUpdateLink, for: .normal)
        appUpdateButton.setTitleColor(.systemBlue, for: .normal)
        appUpdateButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        appUpdateButton.contentHorizontalAlignment = .right
        appUpdateButton.addTarget(self, action: #selector(handleAppUpdateButtonTapped), for: .touchUpInside)
        appUpdateButton.isHidden = true
    }
    
    private func setupPrivacyPolicySection() {
        privacyPolicyContainer.backgroundColor = UIColor.clear
        
        privacyPolicyTitleLabel.text = LMText.settings.privacyPolicy
        privacyPolicyTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        privacyPolicyTitleLabel.textColor = UIColor.systemGray
        privacyPolicyTitleLabel.textAlignment = .left
        privacyPolicyTitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        privacyPolicyTitleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        privacyPolicyButton.setTitle(LMText.settings.view, for: .normal)
        privacyPolicyButton.setTitleColor(UIColor.systemBlue, for: .normal)
        privacyPolicyButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        privacyPolicyButton.backgroundColor = UIColor.clear
        privacyPolicyButton.contentHorizontalAlignment = .right
        privacyPolicyButton.addTarget(self, action: #selector(handlePrivacyPolicyButtonTapped), for: .touchUpInside)
        privacyPolicyButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        privacyPolicyButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        // 添加点击手势到整个容器
        let privacyTapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePrivacyPolicyButtonTapped))
        privacyPolicyContainer.addGestureRecognizer(privacyTapGesture)
        privacyPolicyContainer.isUserInteractionEnabled = true
    }
    
    private func setupTermsOfServiceSection() {
        termsOfServiceContainer.backgroundColor = UIColor.clear
        
        termsOfServiceTitleLabel.text = LMText.settings.termsOfService
        termsOfServiceTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        termsOfServiceTitleLabel.textColor = UIColor.systemGray
        termsOfServiceTitleLabel.textAlignment = .left
        termsOfServiceTitleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        termsOfServiceTitleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        termsOfServiceButton.setTitle(LMText.settings.view, for: .normal)
        termsOfServiceButton.setTitleColor(UIColor.systemBlue, for: .normal)
        termsOfServiceButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        termsOfServiceButton.backgroundColor = UIColor.clear
        termsOfServiceButton.contentHorizontalAlignment = .right
        termsOfServiceButton.addTarget(self, action: #selector(handleTermsOfServiceButtonTapped), for: .touchUpInside)
        termsOfServiceButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        termsOfServiceButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        
        // 添加点击手势到整个容器
        let termsTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTermsOfServiceButtonTapped))
        termsOfServiceContainer.addGestureRecognizer(termsTapGesture)
        termsOfServiceContainer.isUserInteractionEnabled = true
    }
}

// MARK: - Layout Configuration
extension LMAboutPage {
    
    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        // Background container with rounded corners
        backgroundContainer.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-24)
        }
        
        // App Developer Container - Equal height
        appDeveloperContainer.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(60)
        }
        
        appDeveloperTitleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(24)
        }
        
        appDeveloperValueLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-24)
            make.leading.greaterThanOrEqualTo(appDeveloperTitleLabel.snp.trailing).offset(16)
        }
        
        // First separator line
        separatorLine1.snp.makeConstraints { make in
            make.top.equalTo(appDeveloperContainer.snp.bottom)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.height.equalTo(0.5)
        }
        
        // App Version Container - Equal height
        appVersionContainer.snp.makeConstraints { make in
            make.top.equalTo(separatorLine1.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(60)
        }
        
        appVersionTitleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(24)
        }
        
        appUpdateButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-24)
            make.height.equalTo(44)
        }
        
        appVersionValueLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalTo(appUpdateButton.snp.leading).offset(-12)
            make.leading.greaterThanOrEqualTo(appVersionTitleLabel.snp.trailing).offset(16)
        }
        
        // Second separator line
        separatorLine2.snp.makeConstraints { make in
            make.top.equalTo(appVersionContainer.snp.bottom)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.height.equalTo(0.5)
        }
        
        // Privacy Policy Container - Equal height
        privacyPolicyContainer.snp.makeConstraints { make in
            make.top.equalTo(separatorLine2.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(60)
        }
        
        privacyPolicyTitleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(24)
        }
        
        privacyPolicyButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-24)
            make.leading.greaterThanOrEqualTo(privacyPolicyTitleLabel.snp.trailing).offset(16)
            make.height.equalTo(44)
        }
        
        // Third separator line
        separatorLine3.snp.makeConstraints { make in
            make.top.equalTo(privacyPolicyContainer.snp.bottom)
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.height.equalTo(0.5)
        }
        
        // Terms of Service Container - Equal height
        termsOfServiceContainer.snp.makeConstraints { make in
            make.top.equalTo(separatorLine3.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(60)
            make.bottom.equalToSuperview()
        }
        
        termsOfServiceTitleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(24)
        }
        
        termsOfServiceButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-24)
            make.leading.greaterThanOrEqualTo(termsOfServiceTitleLabel.snp.trailing).offset(16)
            make.height.equalTo(44)
        }
    }
}

// MARK: - Style Configuration
extension LMAboutPage {
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = UIColor.systemGroupedBackground
        scrollView.backgroundColor = UIColor.clear
        scrollView.showsVerticalScrollIndicator = false
        contentView.backgroundColor = UIColor.clear
    }
}

extension LMAboutPage {
    
    private func refreshAppUpdateState() {
        updateAppUpdateUI(hasUpdate: LMPackageManager.hasAvailableAppUpdate)
        LMPackageManager.refreshAppUpdateStatus { [weak self] hasUpdate in
            DispatchQueue.main.async {
                self?.updateAppUpdateUI(hasUpdate: hasUpdate)
            }
        }
    }
    
    private func updateAppUpdateUI(hasUpdate: Bool) {
        appUpdateButton.isHidden = !hasUpdate
        appUpdateButton.setTitle(hasUpdate ? LMText.settings.appStoreUpdateLink : nil, for: .normal)
    }
}

// MARK: - Action Handlers
extension LMAboutPage {
    
    @objc private func handleBackButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func handlePrivacyPolicyButtonTapped() {
        showPrivacyPolicy()
    }
    
    @objc private func handleTermsOfServiceButtonTapped() {
        showTermsOfService()
    }
    
    @objc private func handleAppUpdateButtonTapped() {
        LMPackageManager.openCurrentAvailableUpdateURL()
    }
}

// MARK: - Navigation Methods
extension LMAboutPage {
    
    private func showPrivacyPolicy() {
        // 可以打开网页或显示本地内容
        if let url = URL(string: LMApi.Terms.privacy) {
            openWebPage(url: url)
        } else {
            showLocalPrivacyPolicy()
        }
    }
    
    private func showTermsOfService() {
        // 可以打开网页或显示本地内容
        if let url = URL(string: LMApi.Terms.service) {
            openWebPage(url: url)
        } else {
            showLocalTermsOfService()
        }
    }
    
    private func openWebPage(url: URL) {
        // 这里可以使用Safari或者内置的WebView
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }
    }
    
    private func showLocalPrivacyPolicy() {
        let alert = UIAlertController(
            title: LMText.settings.privacyPolicy,
            message: LMText.settings.privacyPolicyUnavailableMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LMText.common.ok, style: .default))
        present(alert, animated: true)
    }
    
    private func showLocalTermsOfService() {
        let alert = UIAlertController(
            title: LMText.settings.termsOfService,
            message: LMText.settings.termsOfServiceUnavailableMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LMText.common.ok, style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Utility Methods
extension LMAboutPage {
    
    /// 获取应用的详细版本信息
    private func getDetailedAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }
    
    /// 获取应用名称
    private func getAppName() -> String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
               Bundle.main.infoDictionary?["CFBundleName"] as? String ??
               "FramAIst"
    }
}
