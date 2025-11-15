//
//  LMSubscriptionCountdownView.swift
//  processor
//
//  Created by muz on 2025/11/8.
//

import UIKit
import SnapKit

class LMSubscriptionCountdownView: UIView {
    
    // MARK: - UI Components
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let timerStackView = UIStackView()
    private let labelsStackView = UIStackView()
    
    // Timer labels
    private let daysLabel = UILabel()
    private let hoursLabel = UILabel()
    private let minutesLabel = UILabel()
    private let secondsLabel = UILabel()
    
    // Label texts
    private let dayLabel = UILabel()
    private let hourLabel = UILabel()
    private let minuteLabel = UILabel()
    private let secondLabel = UILabel()
    
    // MARK: - Properties
    private let textColor: UIColor
    
    // MARK: - Initialization
    init(textColor: UIColor) {
        self.textColor = textColor
        super.init(frame: .zero)
        configureSubviews()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Subview Configuration
    private func configureSubviews() {
        addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(timerStackView)
        containerView.addSubview(labelsStackView)
        
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        containerView.layer.cornerRadius = 12
        containerView.layer.masksToBounds = true
        
        titleLabel.text = LMText.subscription.limitedTimeOffer
        titleLabel.font = UIFont.systemFont(ofSize: 14)
        titleLabel.textColor = textColor.withAlphaComponent(0.9)
        titleLabel.textAlignment = .center
        
        timerStackView.axis = .horizontal
        timerStackView.spacing = 8
        timerStackView.alignment = .center
        timerStackView.distribution = .fill
        
        labelsStackView.axis = .horizontal
        labelsStackView.spacing = 4
        labelsStackView.distribution = .equalSpacing
        labelsStackView.alignment = .center
        
        // Setup timer containers
        let daysContainer = createTimerContainer(label: daysLabel)
        let hoursContainer = createTimerContainer(label: hoursLabel)
        let minutesContainer = createTimerContainer(label: minutesLabel)
        let secondsContainer = createTimerContainer(label: secondsLabel)
        
        let colon1 = createColonLabel()
        let colon2 = createColonLabel()
        let colon3 = createColonLabel()
        
        timerStackView.addArrangedSubview(daysContainer)
        timerStackView.addArrangedSubview(colon1)
        timerStackView.addArrangedSubview(hoursContainer)
        timerStackView.addArrangedSubview(colon2)
        timerStackView.addArrangedSubview(minutesContainer)
        timerStackView.addArrangedSubview(colon3)
        timerStackView.addArrangedSubview(secondsContainer)
        
        // Setup labels
        dayLabel.text = LMText.subscription.days
        hourLabel.text = LMText.subscription.hours
        minuteLabel.text = LMText.subscription.minutes
        secondLabel.text = LMText.subscription.seconds
        
        [dayLabel, hourLabel, minuteLabel, secondLabel].forEach { label in
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = textColor.withAlphaComponent(0.8)
            label.textAlignment = .center
            labelsStackView.addArrangedSubview(label)
        }
    }
    
    private func createTimerContainer(label: UILabel) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        container.layer.cornerRadius = 8
        container.layer.masksToBounds = true
        
        label.text = "00"
        label.font = UIFont.monospacedSystemFont(ofSize: 18, weight: .regular)
        label.textColor = textColor
        label.textAlignment = .center
        
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }
        
        container.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(40)
        }
        
        return container
    }
    
    private func createColonLabel() -> UILabel {
        let label = UILabel()
        label.text = ":"
        label.font = UIFont.systemFont(ofSize: 18)
        label.textColor = textColor.withAlphaComponent(0.7)
        return label
    }
    
    private func setupLayout() {
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        
        timerStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }
        
        labelsStackView.snp.makeConstraints { make in
            make.top.equalTo(timerStackView.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-12)
        }
    }
    
    // MARK: - Public Methods
    func updateCountdown(days: Int, hours: Int, minutes: Int, seconds: Int) {
        daysLabel.text = String(format: "%02d", days)
        hoursLabel.text = String(format: "%02d", hours)
        minutesLabel.text = String(format: "%02d", minutes)
        secondsLabel.text = String(format: "%02d", seconds)
        
        dayLabel.text = days == 1 ? LMText.subscription.day : LMText.subscription.days
        hourLabel.text = hours == 1 ? LMText.subscription.hour : LMText.subscription.hours
        minuteLabel.text = minutes == 1 ? LMText.subscription.minute : LMText.subscription.minutes
        secondLabel.text = seconds == 1 ? LMText.subscription.second : LMText.subscription.seconds
    }
}
