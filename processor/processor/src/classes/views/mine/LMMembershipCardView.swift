//
//  LMMembershipCardView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

class LMMembershipCardView: UIView {
    
    var watchAdsButtonAction: (() -> Void)?
    var upgradeButtonAction: (() -> Void)?
    var freeTrialButtonAction: (() -> Void)?
    
    private var isPlusUser: Bool = false
    private var currentExpiryDays: Int?
    private var currentInspirePoints: Int?
    private var hasFreeTrial: Bool = false
    private var currentSubscriptionType: SubscriptionType = .free
    
    func updateMembershipStatus(isPlusUser: Bool, inspirePoints: Int?, expiryDays: Int? = nil, hasFreeTrial: Bool = false, subscriptionType: SubscriptionType = .free) {
        self.isPlusUser = isPlusUser
        self.currentExpiryDays = expiryDays
        self.currentInspirePoints = inspirePoints
        self.hasFreeTrial = hasFreeTrial
        self.currentSubscriptionType = subscriptionType
        
        // 始终隐藏 Upgrade 按钮和 Watch Ads 按钮
        upgradeButton.isHidden = true
        watchAdsButton.isHidden = true
        expiryWarningIcon.isHidden = true
        
        // Free Trial 按钮始终显示，根据会员到期时间设置是否可点击
        // hasFreeTrial 为 true 表示会员有效期内（subscriptionEndDate 未过期），按钮置灰
        // hasFreeTrial 为 false 表示 subscriptionEndDate 为空或已过期，按钮可点击
        freeTrialButton.isHidden = false
        updateFreeTrialButtonState(hasFreeTrial: hasFreeTrial || isPlusUser)
        
        // 根据会员状态设置背景色
        // 当用户有会员时（isPlusUser 为 true），显示渐变色背景
        // 当用户会员过期或未领取会员时，显示亮灰色背景
        if isPlusUser {
            setupPlusUserStyle()
        } else {
            setupFreeUserStyle()
        }
        
        // 根据订阅类型显示标题
        titleLabel.text = subscriptionType.displayName
        subtitleLabel.text = LMText.profile.unlimitedInspires
        subtitleLabel.textColor = isPlusUser ? UIColor.white.withAlphaComponent(0.8) : UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1.0)
        mainLabel.text = LMText.profile.unlimited
        descLabel.text = LMText.profile.inspirePoints
        
        // 更新到期信息显示（仅对 Plus 用户显示）
        updateExpiryInfo(expiryDays: isPlusUser ? expiryDays : nil)
    }
    
    /// 更新到期信息显示
    private func updateExpiryInfo(expiryDays: Int?) {
        if let days = expiryDays, days >= 0 {
            // 显示到期天数
            expiryDaysLabel.isHidden = false
            expiryDescLabel.isHidden = false
            
            // 根据天数选择单复数格式
            if days == 1 {
                expiryDaysLabel.text = String(format: LMText.profile.dayFormat, days)
            } else {
                expiryDaysLabel.text = String(format: LMText.profile.daysFormat, days)
            }
            expiryDescLabel.text = LMText.profile.tilExpiration
            
            // 设置颜色（与 Plus 样式一致）
            expiryDaysLabel.textColor = .white
            expiryDescLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        } else {
            // 隐藏到期信息
            expiryDaysLabel.isHidden = true
            expiryDescLabel.isHidden = true
        }
    }
    
    /// 更新 Free Trial 按钮状态
    func updateFreeTrialButtonState(hasFreeTrial: Bool, isLoading: Bool = false) {
        self.hasFreeTrial = hasFreeTrial
        
        // 文案始终为 "Get Free Trial"
        if isLoading {
            freeTrialButton.setTitle(LMText.profile.claimingFreeTrial, for: .normal)
            freeTrialButton.isEnabled = false
            freeTrialButton.alpha = 0.6
        } else {
            freeTrialButton.setTitle(LMText.profile.getFreeTrial, for: .normal)
            if hasFreeTrial {
                // 会员有效期内（subscriptionEndDate 未过期），按钮置灰不可点击
                freeTrialButton.isEnabled = false
                freeTrialButton.alpha = 0.6
            } else {
                // subscriptionEndDate 为空或已过期，按钮可点击
                freeTrialButton.isEnabled = true
                freeTrialButton.alpha = 1.0
            }
        }
        
        // 根据会员状态调整按钮样式
        if isPlusUser {
            // Plus 用户：白色半透明背景
            freeTrialButton.backgroundColor = UIColor.white.withAlphaComponent(0.25)
            freeTrialButton.setTitleColor(.white, for: .normal)
            freeTrialButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .disabled)
            freeTrialButton.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        } else {
            // Free 用户：蓝色背景
            freeTrialButton.backgroundColor = UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0)
            freeTrialButton.setTitleColor(.white, for: .normal)
            freeTrialButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .disabled)
            freeTrialButton.layer.borderColor = UIColor.clear.cgColor
        }
    }
    
    func setWatchAdsButtonAction(_ action: @escaping () -> Void) {
        self.watchAdsButtonAction = action
    }
    
    func setUpgradeButtonAction(_ action: @escaping () -> Void) {
        self.upgradeButtonAction = action
    }
    
    func setFreeTrialButtonAction(_ action: @escaping () -> Void) {
        self.freeTrialButtonAction = action
    }
    
    private let cardView = UIView()
    private let subscriptionInfoContainer = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let expiryWarningIcon = UIImageView()  // 新增：到期警告图标
    private let upgradeButton = UIButton()
    private let freeTrialButton = UIButton()  // 新增：免费试用按钮
    private let pointsActionContainer = UIView()
    private let mainLabel = UILabel()
    private let descLabel = UILabel()
    // 新增：到期信息标签
    private let expiryDaysLabel = UILabel()
    private let expiryDescLabel = UILabel()
    private let watchAdsButton = UIButton()
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMembershipViews()
        setupContentConstraints()
        configureDefaultContent()
        setupLanguageObserver()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMembershipViews() {
        addSubview(cardView)
        
        // Add containers for better layout
        cardView.addSubview(subscriptionInfoContainer)
        cardView.addSubview(pointsActionContainer)
        
        // Subscription info section
        subscriptionInfoContainer.addSubview(iconImageView)
        subscriptionInfoContainer.addSubview(titleLabel)
        subscriptionInfoContainer.addSubview(subtitleLabel)
        subscriptionInfoContainer.addSubview(expiryWarningIcon)
        subscriptionInfoContainer.addSubview(upgradeButton)
        subscriptionInfoContainer.addSubview(freeTrialButton)
        
        // Points and action section
        pointsActionContainer.addSubview(mainLabel)
        pointsActionContainer.addSubview(descLabel)
        pointsActionContainer.addSubview(expiryDaysLabel)
        pointsActionContainer.addSubview(expiryDescLabel)
        pointsActionContainer.addSubview(watchAdsButton)
        
        // Setup card view
        cardView.layer.cornerRadius = 16
        cardView.clipsToBounds = true
        
        iconImageView.contentMode = .center
        
        // Setup gradient layer
        cardView.layer.insertSublayer(gradientLayer, at: 0)
        
        // Setup title label
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        
        // Setup subtitle label  
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        
        // Setup expiry warning icon
        expiryWarningIcon.image = UIImage(systemName: "exclamationmark.triangle.fill")
        expiryWarningIcon.tintColor = UIColor.systemYellow
        expiryWarningIcon.contentMode = .scaleAspectFit
        expiryWarningIcon.isHidden = true
        
        // Setup upgrade button
        upgradeButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        upgradeButton.layer.cornerRadius = 16
        upgradeButton.addTarget(self, action: #selector(upgradeButtonTapped), for: .touchUpInside)
        
        // Setup free trial button
        freeTrialButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        freeTrialButton.layer.cornerRadius = 16
        freeTrialButton.setTitle(LMText.profile.getFreeTrial, for: .normal)
        freeTrialButton.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        freeTrialButton.setTitleColor(.white, for: .normal)
        freeTrialButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .disabled)
        freeTrialButton.layer.borderWidth = 1
        freeTrialButton.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        freeTrialButton.addTarget(self, action: #selector(freeTrialButtonTapped), for: .touchUpInside)
        freeTrialButton.isHidden = true
        
        // Setup main points label
        mainLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        mainLabel.textAlignment = .left
        
        // Setup description label
        descLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        descLabel.textAlignment = .left
        
        // Setup expiry days label (bold, same style as mainLabel)
        expiryDaysLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        expiryDaysLabel.textAlignment = .left
        expiryDaysLabel.isHidden = true
        
        // Setup expiry description label (same style as descLabel)
        expiryDescLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        expiryDescLabel.textAlignment = .left
        expiryDescLabel.text = LMText.profile.tilExpiration
        expiryDescLabel.isHidden = true
        
        // Setup watch ads button
        watchAdsButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        watchAdsButton.layer.cornerRadius = 16
        watchAdsButton.addTarget(self, action: #selector(watchAdsButtonTapped), for: .touchUpInside)
        watchAdsButton.isHidden = true
        
        // Add shadow to card
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.1
    }
    
    private func setupContentConstraints() {
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(160)
        }
        
        // Subscription info container
        subscriptionInfoContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(60)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalTo(20)
            make.size.equalTo(40)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.top.equalTo(iconImageView).offset(4)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }
        
        expiryWarningIcon.snp.makeConstraints { make in
            make.leading.equalTo(subtitleLabel.snp.trailing).offset(6)
            make.centerY.equalTo(subtitleLabel)
            make.size.equalTo(14)
        }
        
        upgradeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalTo(30)
            make.width.equalTo(80)
            make.height.equalTo(32)
        }
        
        freeTrialButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalTo(30)
            make.width.equalTo(110)
            make.height.equalTo(32)
        }
        
        // Points and action container
        pointsActionContainer.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
            make.top.equalTo(subscriptionInfoContainer.snp.bottom)
        }
        
        // mainLabel 与会员图标左对齐
        mainLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView)
            make.bottom.equalTo(descLabel.snp.top).offset(-4)
        }
        
        // descLabel 与 mainLabel 居中对齐
        descLabel.snp.makeConstraints { make in
            make.bottom.equalTo(-20)
            make.centerX.equalTo(mainLabel)
        }
        
        // expiryDaysLabel 在 mainLabel 右侧，保持一定间距
        expiryDaysLabel.snp.makeConstraints { make in
            make.leading.equalTo(mainLabel.snp.trailing).offset(40)
            make.bottom.equalTo(mainLabel)
        }
        
        // expiryDescLabel 与 expiryDaysLabel 居中对齐
        expiryDescLabel.snp.makeConstraints { make in
            make.bottom.equalTo(descLabel)
            make.centerX.equalTo(expiryDaysLabel)
        }
        
        watchAdsButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalTo(-30)
            make.height.equalTo(44)
            make.width.greaterThanOrEqualTo(120)
        }
    }
    
    private func configureDefaultContent() {
        // 默认显示 Free Plan 样式（灰色背景）
        titleLabel.text = LMText.profile.plusPlan
        subtitleLabel.text = LMText.profile.unlimitedInspires
        mainLabel.text = LMText.profile.unlimited
        descLabel.text = LMText.profile.inspirePoints
        
        // 隐藏按钮
        watchAdsButton.isHidden = true
        upgradeButton.isHidden = true
        freeTrialButton.isHidden = true
        
        setupFreeUserStyle()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = cardView.bounds
    }
    
    private func setupPlusUserStyle() {
        // Plus plan gradient background (purple gradient)
        gradientLayer.colors = [
            UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0).cgColor,  // #667eea
            UIColor(red: 0.46, green: 0.29, blue: 0.64, alpha: 1.0).cgColor  // #764ba2
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        
        // Icon styling
        iconImageView.image = UIImage.lmSymbol("crown.fill", pointSize: 22)
        iconImageView.tintColor = .white
        iconImageView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        iconImageView.layer.cornerRadius = 12
        iconImageView.layer.masksToBounds = true
        
        // Text colors for plus plan
        titleLabel.textColor = .white
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        mainLabel.textColor = .white
        descLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        
        // 恢复 mainLabel 字体大小
        mainLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        
        // Watch ads button styling for plus plan
        watchAdsButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        watchAdsButton.setTitleColor(.white, for: .normal)
        watchAdsButton.layer.borderWidth = 1
        watchAdsButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
    }
    
    private func setupFreeUserStyle() {
        // Free plan subtle background
        gradientLayer.colors = [
            UIColor(red: 0.9, green: 0.91, blue: 0.92, alpha: 1.0).cgColor,  // #e5e7eb
            UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1.0).cgColor  // #d1d5db
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        
        // Icon styling for free plan
        iconImageView.image = UIImage.lmSymbol("crown.fill", pointSize: 22)
        iconImageView.tintColor = UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1.0)
        iconImageView.backgroundColor = UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 0.2)
        iconImageView.layer.cornerRadius = 12
        iconImageView.layer.masksToBounds = true
        
        // Text colors for free plan
        titleLabel.textColor = UIColor(red: 0.22, green: 0.25, blue: 0.32, alpha: 1.0)  // #374151
        subtitleLabel.textColor = UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1.0)  // #6b7280
        mainLabel.textColor = UIColor(red: 0.22, green: 0.25, blue: 0.32, alpha: 1.0)
        descLabel.textColor = UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1.0)
        
        // 调整 mainLabel 字体大小以适应 "Free Unlimited" 文字
        mainLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        
        // Upgrade button styling (虽然隐藏，但保留样式设置)
        upgradeButton.backgroundColor = UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0)  // #3b82f6
        upgradeButton.setTitleColor(.white, for: .normal)
        upgradeButton.setTitle(LMText.profile.upgrade, for: .normal)
        upgradeButton.layer.shadowColor = UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 0.3).cgColor
        upgradeButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        upgradeButton.layer.shadowRadius = 8
        upgradeButton.layer.shadowOpacity = 1.0
        
        // Watch ads button styling for free plan
        watchAdsButton.backgroundColor = UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0)
        watchAdsButton.setTitleColor(.white, for: .normal)
        watchAdsButton.layer.borderWidth = 0
        watchAdsButton.layer.shadowColor = UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 0.4).cgColor
        watchAdsButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        watchAdsButton.layer.shadowRadius = 15
        watchAdsButton.layer.shadowOpacity = 1.0
        
        // Add +5 indicator to watch ads button
        addPointsIndicatorToButton()
    }
    
    private func addPointsIndicatorToButton() {
        // Remove existing indicator if any
        watchAdsButton.subviews.forEach { subview in
            if subview.tag == 999 {
                subview.removeFromSuperview()
            }
        }
        
        let indicator = UILabel()
        indicator.tag = 999
        indicator.text = LMText.profile.plusIndicator
        indicator.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        indicator.textColor = .white
        indicator.backgroundColor = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0)  // #10b981
        indicator.textAlignment = .center
        indicator.layer.cornerRadius = 10
        indicator.layer.masksToBounds = true
        indicator.layer.borderWidth = 2
        indicator.layer.borderColor = UIColor.white.cgColor
        
        watchAdsButton.addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(-8)
            make.trailing.equalToSuperview().offset(8)
            make.width.height.equalTo(20)
        }
    }
    
    @objc private func watchAdsButtonTapped() {
        // Add button press animation
        UIView.animate(withDuration: 0.1, animations: {
            self.watchAdsButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.watchAdsButton.transform = CGAffineTransform.identity
            }
        }
        watchAdsButtonAction?()
    }
    
    @objc private func upgradeButtonTapped() {
        // Add button press animation
        UIView.animate(withDuration: 0.1, animations: {
            self.upgradeButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.upgradeButton.transform = CGAffineTransform.identity
            }
        }
        upgradeButtonAction?()
    }
    
    @objc private func freeTrialButtonTapped() {
        // Add button press animation
        UIView.animate(withDuration: 0.1, animations: {
            self.freeTrialButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.freeTrialButton.transform = CGAffineTransform.identity
            }
        }
        freeTrialButtonAction?()
    }
    
    // MARK: - Language Support
    
    private func setupLanguageObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: LMLaunageManager.languageDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func languageDidChange() {
        // 重新应用当前状态的文本
        updateMembershipStatus(
            isPlusUser: isPlusUser,
            inspirePoints: currentInspirePoints,
            expiryDays: currentExpiryDays,
            hasFreeTrial: hasFreeTrial,
            subscriptionType: currentSubscriptionType
        )
    }
}
