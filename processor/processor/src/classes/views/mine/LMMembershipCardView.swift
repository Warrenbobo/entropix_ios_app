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
    
    private var isPlusUser: Bool = false
    
    func updateMembershipStatus(isPlusUser: Bool, inspirePoints: Int?) {
        self.isPlusUser = isPlusUser
        
        if isPlusUser {
            setupPlusUserStyle()
            titleLabel.text = LMText.profile.plusPlan
            subtitleLabel.text = LMText.profile.unlimitedInspires
            mainLabel.text = LMText.profile.unlimited
            descLabel.text = LMText.profile.inspirePoints
            watchAdsButton.setTitle(LMText.profile.watchAdsWithIcon, for: .normal)
            upgradeButton.isHidden = true
        } else {
            setupFreeUserStyle()
            titleLabel.text = LMText.profile.freePlan
            subtitleLabel.text = LMText.profile.limitedUsage
            mainLabel.text = "\(inspirePoints ?? 0)"
            descLabel.text = LMText.profile.inspirePoints
            watchAdsButton.setTitle(LMText.profile.watchAds, for: .normal)
            upgradeButton.isHidden = false
        }
    }
    
    func setWatchAdsButtonAction(_ action: @escaping () -> Void) {
        self.watchAdsButtonAction = action
    }
    
    func setUpgradeButtonAction(_ action: @escaping () -> Void) {
        self.upgradeButtonAction = action
    }
    
    private let cardView = UIView()
    private let subscriptionInfoContainer = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let upgradeButton = UIButton()
    private let pointsActionContainer = UIView()
    private let mainLabel = UILabel()
    private let descLabel = UILabel()
    private let watchAdsButton = UIButton()
    private let gradientLayer = CAGradientLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupMembershipViews()
        setupContentConstraints()
        configureDefaultContent()
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
        subscriptionInfoContainer.addSubview(upgradeButton)
        
        // Points and action section
        pointsActionContainer.addSubview(mainLabel)
        pointsActionContainer.addSubview(descLabel)
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
        
        // Setup upgrade button
        upgradeButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        upgradeButton.layer.cornerRadius = 16
        upgradeButton.addTarget(self, action: #selector(upgradeButtonTapped), for: .touchUpInside)
        
        // Setup main points label
        mainLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        mainLabel.textAlignment = .center
        
        // Setup description label
        descLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        descLabel.textAlignment = .center
        
        // Setup watch ads button
        watchAdsButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        watchAdsButton.layer.cornerRadius = 16
        watchAdsButton.addTarget(self, action: #selector(watchAdsButtonTapped), for: .touchUpInside)
        
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
        
        upgradeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalTo(30)
            make.width.equalTo(80)
            make.height.equalTo(32)
        }
        
        // Points and action container
        pointsActionContainer.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
            make.top.equalTo(subscriptionInfoContainer.snp.bottom)
        }
        
        mainLabel.snp.makeConstraints { make in
            make.centerX.equalTo(descLabel)
            make.bottom.equalTo(descLabel.snp.top).offset(-8)
        }
        
        descLabel.snp.makeConstraints { make in
            make.bottom.equalTo(-20)
            make.leading.equalTo(20)
        }
        
        watchAdsButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalTo(-30)
            make.height.equalTo(44)
            make.width.greaterThanOrEqualTo(120)
        }
    }
    
    private func configureDefaultContent() {
        titleLabel.text = LMText.profile.plusPlan
        subtitleLabel.text = LMText.profile.unlimitedInspires
        mainLabel.text = "0"
        descLabel.text = LMText.profile.inspirePoints
        watchAdsButton.setTitle(LMText.profile.watchAdsWithIcon, for: .normal)
        setupPlusUserStyle()
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
        iconImageView.image = UIImage(named: "crown_solid_white")
        iconImageView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        iconImageView.layer.cornerRadius = 12
        iconImageView.layer.masksToBounds = true
        
        // Text colors for plus plan
        titleLabel.textColor = .white
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        mainLabel.textColor = .white
        descLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        
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
        iconImageView.image = UIImage(named: "crown_solid_gray")
        iconImageView.backgroundColor = UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 0.2)
        iconImageView.layer.cornerRadius = 12
        iconImageView.layer.masksToBounds = true
        
        // Text colors for free plan
        titleLabel.textColor = UIColor(red: 0.22, green: 0.25, blue: 0.32, alpha: 1.0)  // #374151
        subtitleLabel.textColor = UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1.0)  // #6b7280
        mainLabel.textColor = UIColor(red: 0.22, green: 0.25, blue: 0.32, alpha: 1.0)
        descLabel.textColor = UIColor(red: 0.42, green: 0.45, blue: 0.5, alpha: 1.0)
        
        // Upgrade button styling
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
}
