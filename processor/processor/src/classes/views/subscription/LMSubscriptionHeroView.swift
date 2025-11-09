//
//  LMSubscriptionHeroView.swift
//  processor
//
//  Created by muz on 2025/11/8.
//

import UIKit
import SnapKit

class LMSubscriptionHeroView: UIView {
    
    // MARK: - UI Components
    private let heroIcon = UIImageView()
    private let heroTitleLabel = UILabel()
    private let heroDescLabel = UILabel()
    private var gradientLayer: CAGradientLayer?
    
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
        addSubview(heroIcon)
        addSubview(heroTitleLabel)
        addSubview(heroDescLabel)
        
        heroIcon.image = UIImage(named: "crown_solid_white")
        heroIcon.contentMode = .scaleAspectFill
        
        heroTitleLabel.text = LMText.settings.unlockCreativePotential
        heroTitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        heroTitleLabel.textColor = .white
        heroTitleLabel.textAlignment = .center
        heroTitleLabel.numberOfLines = 0
        
        heroDescLabel.text = LMText.subscription.unlimitedAISuggestions
        heroDescLabel.font = UIFont.systemFont(ofSize: 14)
        heroDescLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        heroDescLabel.textAlignment = .center
        heroDescLabel.numberOfLines = 0
        
        layoutMargins = UIEdgeInsets(top: 32, left: 24, bottom: 32, right: 24)
    }
    
    private func setupLayout() {
        heroIcon.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(32)
            make.centerX.equalToSuperview()
            make.width.height.equalTo(50)
        }
        
        heroTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(heroIcon.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        heroDescLabel.snp.makeConstraints { make in
            make.top.equalTo(heroTitleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-32)
        }
    }
    
    private func setupStyles() {
        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.hexColor("#667eea").cgColor, UIColor.hexColor("#764ba2").cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)
        gradientLayer = gradient
    }
    
    private func updateGradientLayer() {
        gradientLayer?.frame = bounds
    }
}
