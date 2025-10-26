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
    
    
    func updateMembershipStatus(isPlusUser: Bool, inspirePoints: Int?) {
        if isPlusUser {
            titleLabel.text = "Plus Plan"
            subtitleLabel.text = "Unlimited Inspires"
            mainLabel.text = "Unlimited"
            descLabel.text = "Inspire Points"
            watchAdsButton.setTitle("▶ Watch Ads", for: .normal)
            cardView.backgroundColor = UIColor.systemPurple
        } else {
            titleLabel.text = "Free Plan"
            subtitleLabel.text = "Limited Inspire Points"
            mainLabel.text = "\(inspirePoints ?? 0)"
            descLabel.text = "Inspire Points"
            watchAdsButton.setTitle("Upgrade", for: .normal)
            cardView.backgroundColor = UIColor.systemGray4
        }
    }
    
    func setWatchAdsButtonAction(_ action: @escaping () -> Void) {
        self.watchAdsButtonAction = action
    }
    
    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let mainLabel = UILabel()
    private let descLabel = UILabel()
    private let watchAdsButton = UIButton()
    
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
        
        cardView.addSubview(iconImageView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(mainLabel)
        cardView.addSubview(descLabel)
        cardView.addSubview(watchAdsButton)
        
        // 设置卡片背景
        cardView.backgroundColor = UIColor.systemPurple
        cardView.layer.cornerRadius = 16
        
        // 皇冠图标
        iconImageView.image = UIImage(systemName: "crown.fill")
        iconImageView.tintColor = UIColor.white
        
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor.white
        
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        
        mainLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        mainLabel.textColor = UIColor.white
        
        descLabel.font = UIFont.systemFont(ofSize: 12)
        descLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        
        watchAdsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        watchAdsButton.setTitleColor(UIColor.systemPurple, for: .normal)
        watchAdsButton.backgroundColor = UIColor.white
        watchAdsButton.layer.cornerRadius = 16
        watchAdsButton.addTarget(self, action: #selector(watchAdsButtonTapped), for: .touchUpInside)
    }
    
    private func setupContentConstraints() {
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(120)
        }
        
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.top.equalToSuperview().offset(16)
            make.size.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(8)
            make.centerY.equalTo(iconImageView)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
        }
        
        mainLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-32)
        }
        
        descLabel.snp.makeConstraints { make in
            make.leading.equalTo(mainLabel)
            make.top.equalTo(mainLabel.snp.bottom).offset(2)
        }
        
        watchAdsButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.equalTo(120)
            make.height.equalTo(32)
        }
    }
    
    private func configureDefaultContent() {
        titleLabel.text = "Plus Plan"
        subtitleLabel.text = "Unlimited Inspires"
        mainLabel.text = "Unlimited"
        descLabel.text = "Inspire Points"
        watchAdsButton.setTitle("▶ Watch Ads", for: .normal)
    }
    
    @objc private func watchAdsButtonTapped() {
        watchAdsButtonAction?()
    }
}
