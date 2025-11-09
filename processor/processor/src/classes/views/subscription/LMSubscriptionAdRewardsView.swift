//
//  LMSubscriptionAdRewardsView.swift
//  processor
//
//  Created by muz on 2025/11/8.
//

import UIKit
import SnapKit

protocol LMSubscriptionAdRewardsViewDelegate: AnyObject {
    func adRewardsViewDidTapWatchAd(_ view: LMSubscriptionAdRewardsView)
}

class LMSubscriptionAdRewardsView: UIView {
    
    // MARK: - UI Components
    private let adRewardsIcon = UIImageView()
    private let adRewardsTitleLabel = UILabel()
    private let adRewardsDescLabel = UILabel()
    private let watchAdButton = UIButton()
    private var gradientLayer: CAGradientLayer?
    
    // MARK: - Properties
    weak var delegate: LMSubscriptionAdRewardsViewDelegate?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupLayout()
        setupStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateGradientLayer()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        addSubview(adRewardsIcon)
        addSubview(adRewardsTitleLabel)
        addSubview(adRewardsDescLabel)
        addSubview(watchAdButton)
        
        adRewardsIcon.image = UIImage(named: "gift_solid_white")
        adRewardsIcon.contentMode = .scaleAspectFit
        
        adRewardsTitleLabel.text = "Earn Free Uses"
        adRewardsTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        adRewardsTitleLabel.textColor = .white
        
        adRewardsDescLabel.text = "Watch ads to get 5 free AI suggestions"
        adRewardsDescLabel.font = UIFont.systemFont(ofSize: 14)
        adRewardsDescLabel.textColor = UIColor.white.withAlphaComponent(0.95)
        adRewardsDescLabel.numberOfLines = 0
        
        watchAdButton.setTitle("Watch Ad", for: .normal)
        watchAdButton.setImage(UIImage(named: "play_solid_green"), for: .normal)
        watchAdButton.imageView?.contentMode = .scaleAspectFit
        watchAdButton.titleLabel?.adjustsFontSizeToFitWidth = true
        watchAdButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        watchAdButton.backgroundColor = .white
        watchAdButton.setTitleColor(UIColor.hexColor("#10b981"), for: .normal)
        watchAdButton.layer.cornerRadius = 10
        watchAdButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        watchAdButton.imageEdgeInsets = UIEdgeInsets(top: 14, left: -8, bottom: 14, right: 8)
        watchAdButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        watchAdButton.semanticContentAttribute = .forceLeftToRight
        watchAdButton.addTarget(self, action: #selector(handleWatchAd), for: .touchUpInside)
    }
    
    private func setupLayout() {
        adRewardsTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(20)
            make.trailing.lessThanOrEqualTo(adRewardsIcon.snp.leading).offset(-16)
        }
        
        adRewardsDescLabel.snp.makeConstraints { make in
            make.top.equalTo(adRewardsTitleLabel.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(20)
            make.trailing.lessThanOrEqualTo(adRewardsIcon.snp.leading).offset(-16)
        }
        
        watchAdButton.snp.makeConstraints { make in
            make.top.equalTo(adRewardsDescLabel.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-20)
            make.height.equalTo(40)
        }
        
        adRewardsIcon.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(34)
        }
    }
    
    private func setupStyles() {
        layer.cornerRadius = 12
        layer.masksToBounds = true
        
        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.hexColor("#10b981").cgColor, UIColor.hexColor("#3b82f6").cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        layer.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }
    
    private func updateGradientLayer() {
        gradientLayer?.frame = bounds
    }
    
    // MARK: - Actions
    @objc private func handleWatchAd() {
        delegate?.adRewardsViewDidTapWatchAd(self)
    }
}
