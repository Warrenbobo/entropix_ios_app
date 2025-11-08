//
//  LMSubscriptionProgressView.swift
//  processor
//
//  Created by muz on 2025/11/8.
//

import UIKit
import SnapKit

class LMSubscriptionProgressView: UIView {
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let spotsContainer = UIView()
    private let spotsLabel = UILabel()
    private let progressBarContainer = UIView()
    private let progressBar = UIView()
    private let progressTextLabel = UILabel()
    
    // MARK: - Properties
    private let textColor: UIColor
    private let progress: Double
    private let progressText: String
    
    // MARK: - Initialization
    init(progress: Double, text: String, textColor: UIColor) {
        self.progress = progress
        self.progressText = text
        self.textColor = textColor
        super.init(frame: .zero)
        setupUI()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(progressBarContainer)
        containerView.addSubview(progressTextLabel)
        progressBarContainer.addSubview(progressBar)
        // Spots container should be on top of progress bar container
        containerView.addSubview(spotsContainer)
        spotsContainer.addSubview(spotsLabel)
        
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        containerView.layer.cornerRadius = 12
        containerView.layer.masksToBounds = true
        
        titleLabel.text = "Limited Spots Available:"
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.textColor = textColor.withAlphaComponent(0.9)
        titleLabel.textAlignment = .center
        
        spotsLabel.text = progressText
        spotsLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        spotsLabel.textColor = .white  // White text as per image
        spotsLabel.textAlignment = .center
        
        // Spots container - light grey background with white text for contrast
        // Using a medium grey that provides good contrast for white text
        spotsContainer.backgroundColor = UIColor.hexColor("#9ca3af").withAlphaComponent(0.9)  // Medium grey
        spotsContainer.layer.cornerRadius = 6
        spotsContainer.layer.masksToBounds = true
        
        // Progress bar container - light grey background
        progressBarContainer.backgroundColor = UIColor.hexColor("#e5e7eb")  // Light grey
        progressBarContainer.layer.cornerRadius = 8
        progressBarContainer.layer.masksToBounds = true
        
        // Progress bar - red fill
        progressBar.backgroundColor = UIColor.hexColor("#ef4444")  // Red
        progressBar.layer.cornerRadius = 8
        progressBar.layer.masksToBounds = true
        
        let spotsLeft = 100 - Int(progress * 100)
        progressTextLabel.text = "Only \(spotsLeft) spots left!"
        progressTextLabel.font = UIFont.systemFont(ofSize: 12)
        progressTextLabel.textColor = textColor.withAlphaComponent(0.9)
        progressTextLabel.textAlignment = .center
    }
    
    private func setupLayout() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        
        // Progress bar container
        progressBarContainer.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(16)
        }
        
        // Progress bar fill
        progressBar.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(progress)
        }
        
        // Spots badge positioned on top of progress bar, centered
        spotsContainer.snp.makeConstraints { make in
            make.centerX.equalTo(progressBarContainer)
            make.centerY.equalTo(progressBarContainer)
            make.height.equalTo(20)
        }
        
        spotsLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        }
        
        progressTextLabel.snp.makeConstraints { make in
            make.top.equalTo(progressBarContainer.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(12)
            make.bottom.equalToSuperview().offset(-12)
        }
    }
}
