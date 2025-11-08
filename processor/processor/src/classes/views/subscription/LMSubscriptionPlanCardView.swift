//
//  LMSubscriptionPlanCardView.swift
//  processor
//
//  Created by muz on 2025/11/8.
//

import UIKit
import SnapKit

protocol LMSubscriptionPlanCardViewDelegate: AnyObject {
    func planCardView(_ view: LMSubscriptionPlanCardView, didTapButton plan: SubscriptionPlan)
    func planCardView(_ view: LMSubscriptionPlanCardView, didSwitchToFreePlan plan: SubscriptionPlan)
}

class LMSubscriptionPlanCardView: UIView {
    
    // MARK: - UI Components
    private let contentStack = UIStackView()
    private var gradientLayer: CAGradientLayer?
    private var countdownView: LMSubscriptionCountdownView?
    private var progressView: LMSubscriptionProgressView?
    
    // MARK: - Properties
    private let plan: SubscriptionPlan
    weak var delegate: LMSubscriptionPlanCardViewDelegate?
    
    // MARK: - Initialization
    init(plan: SubscriptionPlan) {
        self.plan = plan
        super.init(frame: .zero)
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
        layer.cornerRadius = 16
        // Only mask to bounds for gradient cards, not for Free Plan which needs shadow
        if plan.gradientColors.count > 1 {
            layer.masksToBounds = true
        }
        
        addSubview(contentStack)
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        
        // Popular Badge
        if let badgeText = plan.popularBadge {
            let badge = createPopularBadge(text: badgeText)
            addSubview(badge)
            badge.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(-8)
                make.trailing.equalToSuperview().offset(-16)
                make.height.equalTo(28)
                make.width.greaterThanOrEqualTo(80)
            }
        }
        
        // Title and Price Row
        let titlePriceRow = createTitlePriceRow()
        contentStack.addArrangedSubview(titlePriceRow)
        
        // Subtitle (for Free Plan)
        if let subtitle = plan.subtitle {
            let subtitleLabel = UILabel()
            subtitleLabel.text = subtitle
            subtitleLabel.font = UIFont.systemFont(ofSize: 14)
            subtitleLabel.textColor = plan.textColor.withAlphaComponent(0.7)
            contentStack.addArrangedSubview(subtitleLabel)
        }
        
        // Ads Info (for Free Plan)
        if let adsInfo = plan.adsInfo {
            let adsInfoLabel = UILabel()
            adsInfoLabel.text = adsInfo
            adsInfoLabel.font = UIFont.systemFont(ofSize: 12)
            adsInfoLabel.textColor = plan.textColor.withAlphaComponent(0.6)
            contentStack.addArrangedSubview(adsInfoLabel)
        }
        
        // Countdown Timer (for Plus Plan)
        if plan.showCountdown {
            let countdown = LMSubscriptionCountdownView(textColor: plan.textColor)
            countdownView = countdown
            contentStack.addArrangedSubview(countdown)
        }
        
        // Progress Bar (for Life-long Plan)
        if plan.showProgress, let progress = plan.progressValue, let progressText = plan.progressText {
            let progress = LMSubscriptionProgressView(progress: progress, text: progressText, textColor: plan.textColor)
            progressView = progress
            contentStack.addArrangedSubview(progress)
        }
        
        // Description
        if !plan.description.isEmpty {
            let descLabel = createDescriptionLabel()
            contentStack.addArrangedSubview(descLabel)
        }
        
        // Features
        let featuresStack = createFeaturesStack()
        contentStack.addArrangedSubview(featuresStack)
        
        // Button
        let button = createButton()
        contentStack.addArrangedSubview(button)
        
        // Button subtitle text
        if plan.planType == .plus || plan.planType == .lifelong {
            let subtitleLabel = createSubtitleLabel()
            contentStack.addArrangedSubview(subtitleLabel)
        }
    }
    
    private func createPopularBadge(text: String) -> UILabel {
        let badge = UILabel()
        badge.text = text
        badge.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = UIColor.hexColor("#ff6b6b")
        badge.textAlignment = .center
        badge.layer.cornerRadius = 12
        badge.layer.masksToBounds = true
        return badge
    }
    
    private func createTitlePriceRow() -> UIView {
        let titlePriceRow = UIView()
        let titleLabel = UILabel()
        titleLabel.text = plan.title
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = plan.textColor
        
        let priceContainer = UIView()
        let priceStack = UIStackView()
        priceStack.axis = .horizontal
        priceStack.spacing = 8
        priceStack.alignment = .center
        
        if let originalPrice = plan.originalPrice {
            let strikeLabel = UILabel()
            strikeLabel.text = originalPrice
            strikeLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            strikeLabel.textColor = plan.textColor.withAlphaComponent(0.8)
            let attributedString = NSMutableAttributedString(string: originalPrice)
            attributedString.addAttribute(.strikethroughStyle, value: 1, range: NSRange(location: 0, length: originalPrice.count))
            strikeLabel.attributedText = attributedString
            priceStack.addArrangedSubview(strikeLabel)
        }
        
        let priceLabel = UILabel()
        priceLabel.text = plan.price
        priceLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        priceLabel.textColor = plan.textColor
        priceStack.addArrangedSubview(priceLabel)
        
        if let discount = plan.discount {
            let discountBadge = UILabel()
            discountBadge.text = discount
            discountBadge.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
            // Plus Plan uses dark text on yellow background for better visibility
            // Life-long Plan uses white text on light red/pink background
            switch plan.planType {
            case .plus:
                discountBadge.textColor = UIColor.hexColor("#854d0e")  // Dark text on yellow background
                discountBadge.backgroundColor = UIColor.hexColor("#fef08a")
            case .lifelong:
                discountBadge.textColor = .white  // White text on light red background
                discountBadge.backgroundColor = UIColor.hexColor("#fca5a5")
            case .free:
                discountBadge.textColor = UIColor.hexColor("#854d0e")
                discountBadge.backgroundColor = UIColor.hexColor("#fef08a")
            }
            discountBadge.textAlignment = .center
            discountBadge.layer.cornerRadius = 6
            discountBadge.layer.masksToBounds = true
            discountBadge.snp.makeConstraints { make in
                make.height.equalTo(20)
                make.width.greaterThanOrEqualTo(60)
            }
            priceStack.addArrangedSubview(discountBadge)
        }
        
        let periodLabel = UILabel()
        periodLabel.text = plan.period
        periodLabel.font = UIFont.systemFont(ofSize: 14)
        periodLabel.textColor = plan.textColor.withAlphaComponent(0.8)
        
        priceContainer.addSubview(priceStack)
        priceContainer.addSubview(periodLabel)
        
        priceStack.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        
        periodLabel.snp.makeConstraints { make in
            make.top.equalTo(priceStack.snp.bottom).offset(4)
            make.leading.trailing.bottom.equalToSuperview()
            make.centerX.equalTo(priceStack)
        }
        
        titlePriceRow.addSubview(titleLabel)
        titlePriceRow.addSubview(priceContainer)
        
        titleLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.bottom.lessThanOrEqualToSuperview()
        }
        
        priceContainer.snp.makeConstraints { make in
            make.trailing.top.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(16)
            make.bottom.lessThanOrEqualToSuperview()
        }
        
        return titlePriceRow
    }
    
    private func createDescriptionLabel() -> UILabel {
        let descLabel = UILabel()
        descLabel.text = plan.description
        descLabel.font = UIFont.systemFont(ofSize: 14)
        descLabel.textColor = plan.textColor.withAlphaComponent(0.9)
        return descLabel
    }
    
    private func createFeaturesStack() -> UIStackView {
        let featuresStack = UIStackView()
        featuresStack.axis = .vertical
        featuresStack.spacing = 10
        for feature in plan.features {
            let featureRow = UIView()
            let checkIcon = UIImageView()
            checkIcon.image = UIImage(named: plan.textColor == .white ? "check_line_white" : "check_line_green")
            checkIcon.contentMode = .scaleAspectFit
            
            let featureLabel = UILabel()
            featureLabel.text = feature
            featureLabel.font = UIFont.systemFont(ofSize: 14)
            featureLabel.textColor = plan.textColor
            featureLabel.numberOfLines = 0
            
            featureRow.addSubview(checkIcon)
            featureRow.addSubview(featureLabel)
            
            checkIcon.snp.makeConstraints { make in
                make.leading.top.equalToSuperview().offset(2)
                make.width.height.equalTo(16)
            }
            
            featureLabel.snp.makeConstraints { make in
                make.leading.equalTo(checkIcon.snp.trailing).offset(10)
                make.trailing.top.bottom.equalToSuperview()
            }
            
            featuresStack.addArrangedSubview(featureRow)
        }
        return featuresStack
    }
    
    private func createButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(plan.buttonTitle, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 12
        
        // Button styles based on plan type
        switch plan.planType {
        case .free:
            // Free Plan always has border style
            button.backgroundColor = .clear
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.hexColor("#d1d5db").cgColor
            button.setTitleColor(UIColor.hexColor("#374151"), for: .normal)
            button.addTarget(self, action: #selector(handleSwitchToFreePlan), for: .touchUpInside)
        case .plus:
            if plan.isSelected {
                button.backgroundColor = plan.textColor == .white ? UIColor.white : UIColor.hexColor("#FEF9C2")
                button.setTitleColor(plan.textColor == .white ? UIColor.hexColor("#667eea") : UIColor.hexColor("#09244F"), for: .normal)
            } else if plan.isDisabled {
                button.backgroundColor = UIColor.hexColor("#d1d5db")
                button.setTitleColor(plan.textColor == .white ? UIColor.hexColor("#667eea") : UIColor.hexColor("#09244F"), for: .normal)
                button.isEnabled = false
            } else {
                button.backgroundColor = .white
                button.setTitleColor(UIColor.hexColor("#667eea"), for: .normal)
            }
            button.addTarget(self, action: #selector(handleSubscribe), for: .touchUpInside)
        case .lifelong:
            // Life-long Plan button: white background with red text
            button.backgroundColor = .white
            button.setTitleColor(UIColor.hexColor("#ef4444"), for: .normal)
            button.addTarget(self, action: #selector(handleSubscribe), for: .touchUpInside)
        }
        
        button.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        
        return button
    }
    
    private func createSubtitleLabel() -> UILabel {
        let subtitleLabel = UILabel()
        switch plan.planType {
        case .plus:
            subtitleLabel.text = "Auto-renews monthly, cancel anytime"
        case .lifelong:
            subtitleLabel.text = "One-time payment, yours forever"
        case .free:
            break
        }
        subtitleLabel.font = UIFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = plan.textColor.withAlphaComponent(0.8)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        return subtitleLabel
    }
    
    private func setupLayout() {
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(20)
        }
    }
    
    private func setupStyles() {
        // Add gradient background
        if plan.gradientColors.count > 1 {
            let gradient = CAGradientLayer()
            gradient.colors = plan.gradientColors.map { $0.cgColor }
            gradient.startPoint = CGPoint(x: 0, y: 0)
            gradient.endPoint = CGPoint(x: 1, y: 1)
            gradient.frame = bounds
            gradient.cornerRadius = 16
            layer.insertSublayer(gradient, at: 0)
            gradientLayer = gradient
        } else {
            backgroundColor = plan.gradientColors.first
            if plan.planType == .free {
                layer.borderWidth = 1
                layer.borderColor = UIColor.hexColor("#e5e7eb").cgColor
                // Add shadow for Free Plan
                layer.shadowColor = UIColor.black.cgColor
                layer.shadowOffset = CGSize(width: 0, height: 2)
                layer.shadowRadius = 4
                layer.shadowOpacity = 0.1
            }
        }
        
        // Remove border for Plus Plan (it has gradient background)
        if plan.planType == .plus {
            layer.borderWidth = 0
        }
    }
    
    private func updateGradientLayer() {
        gradientLayer?.frame = bounds
    }
    
    // MARK: - Actions
    @objc private func handleSubscribe() {
        delegate?.planCardView(self, didTapButton: plan)
    }
    
    @objc private func handleSwitchToFreePlan() {
        delegate?.planCardView(self, didSwitchToFreePlan: plan)
    }
    
    // MARK: - Public Methods
    func updateCountdown(days: Int, hours: Int, minutes: Int, seconds: Int) {
        countdownView?.updateCountdown(days: days, hours: hours, minutes: minutes, seconds: seconds)
    }
}
