//
//  LMSubscriptionPage.swift
//  processor
//
//  Created by muz on 2025/11/8.
//

import Foundation
import UIKit
import SnapKit
import Toast_Swift

class LMSubscriptionPage: LMPageWrapper {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Hero Section
    private let heroView = LMSubscriptionHeroView()
    
    // Plans Section
    private let plansStackView = UIStackView()
    private var planCardViews: [LMSubscriptionPlanCardView] = []
    
    // Ad Rewards Section
    private let adRewardsView = LMSubscriptionAdRewardsView()
    
    // Footer Section
    private let footerView = LMSubscriptionFooterView()
    
    // Dialog
    private let dialogView = LMSubscriptionDialogView()
    
    // Countdown Timer
    private var countdownTimer: Timer?
    private var promotionEndDate: Date?
    
    // Purchase Processing
    private var isProcessingPurchase = false
    private var loadingOverlay: UIView?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.subscription.chooseYourPlan
        viewAdapter(scrollView)
        configureViewHierarchy()
        setupLayout()
        setupStyles()
        setupDelegates()
        setupCountdown()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false,
                                                     animated: animated)
        updateUIForSubscriptionStatus()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        countdownTimer?.invalidate()
    }
    
    // MARK: - View Hierarchy Configuration
    private func configureViewHierarchy() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(heroView)
        contentView.addSubview(plansStackView)
        contentView.addSubview(adRewardsView)
        contentView.addSubview(footerView)
        view.addSubview(dialogView)
        
        // Configure scroll view
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        
        // Plans Stack View
        plansStackView.axis = .vertical
        plansStackView.spacing = 20
        plansStackView.alignment = .fill
        plansStackView.distribution = .fill
        
        // Create plan cards
        createPlanCards()
        
        // Set promotion end date (7 days from now)
        promotionEndDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        dialogView.isHidden = true
    }
    
    private func setupDelegates() {
        adRewardsView.delegate = self
        footerView.delegate = self
        dialogView.delegate = self
    }
    
    private func createPlanCards() {
        // Free Plan
        let freePlan = SubscriptionPlan(
            planType: .free,
            title: SubscriptionPlanType.free.title,
            subtitle: "Perfect for trying out",
            price: "$0",
            originalPrice: nil,
            discount: nil,
            period: "Forever",
            adsInfo: "Google AdSense + 5 Request / ad-session",
            description: "",
            features: [
                "Up to 15 suggestions including 2 'on-location suggestions' for each request",
                "AR Camera"
            ],
            gradientColors: [.white, .white],
            textColor: UIColor.hexColor("#09244F"),
            buttonTitle: "Current Plan",
            isSelected: false,
            isDisabled: false,
            popularBadge: nil,
            showCountdown: false,
            showProgress: false,
            progressValue: nil,
            progressText: nil
        )
        
        // Plus Plan
        let plusPlan = SubscriptionPlan(
            planType: .plus,
            title: SubscriptionPlanType.plus.title,
            subtitle: nil,
            price: "$9",
            originalPrice: "$15",
            discount: "40% OFF",
            period: "per month",
            adsInfo: nil,
            description: "Monthly Auto-Renewable Subscription",
            features: [
                "Unlimited Inspires",
                "Unlimited suggestions including 5 'on-location suggestions' for each Inspire",
                "AR Camera with advanced features",
                "Premium real-time image filters",
                "Ad-free experience",
                "Priority support"
            ],
            gradientColors: [UIColor.hexColor("#667eea"), UIColor.hexColor("#764ba2")],
            textColor: .white,
            buttonTitle: "Start Monthly Subscription",
            isSelected: true,
            isDisabled: false,
            popularBadge: "Most Popular",
            showCountdown: true,
            showProgress: false,
            progressValue: nil,
            progressText: nil
        )
        
        // Life-long Plan
        let lifeLongPlan = SubscriptionPlan(
            planType: .lifelong,
            title: SubscriptionPlanType.lifelong.title,
            subtitle: nil,
            price: "$79",
            originalPrice: "$199",
            discount: "60% OFF",
            period: "one-time payment",
            adsInfo: nil,
            description: "Lifetime access to all features",
            features: [
                "Everything in all plans",
                "Lifetime access to all current and future features for no extra cost",
                "Exclusive AI models and advanced features in the future",
                "VIP support and early access to new features",
                "Never expires or downgrades"
            ],
            gradientColors: [UIColor.hexColor("#ff6b6b"), UIColor.hexColor("#ee5a24")],
            textColor: .white,
            buttonTitle: "Get Lifetime Access",
            isSelected: false,
            isDisabled: false,
            popularBadge: "Co-founder Promotion",
            showCountdown: false,
            showProgress: true,
            progressValue: 0.67,
            progressText: "67/100"
        )
        
        let plans = [freePlan, plusPlan, lifeLongPlan]
        planCardViews = plans.map { plan in
            let cardView = LMSubscriptionPlanCardView(plan: plan)
            cardView.delegate = self
            return cardView
        }
        planCardViews.forEach { plansStackView.addArrangedSubview($0) }
    }
    
    // MARK: - Layout Setup
    private func setupLayout() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.top.leading.trailing.bottom.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        heroView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(AppTheme.Screen.navigatorHeight)
            make.leading.trailing.equalToSuperview()
        }
        
        plansStackView.snp.makeConstraints { make in
            make.top.equalTo(heroView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        adRewardsView.snp.makeConstraints { make in
            make.top.equalTo(plansStackView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
    
        footerView.snp.makeConstraints { make in
            make.top.equalTo(adRewardsView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-32)
        }
        
        dialogView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    // MARK: - Style Setup
    private func setupStyles() {
        view.backgroundColor = UIColor.hexColor("#f9fafb")
        scrollView.backgroundColor = .clear
        contentView.backgroundColor = .clear
    }
    
    // MARK: - Countdown Setup
    private func setupCountdown() {
        guard let endDate = promotionEndDate else { return }
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCountdown(endDate: endDate)
        }
        
        // Initial update
        updateCountdown(endDate: endDate)
    }
    
    private func updateCountdown(endDate: Date) {
        let now = Date()
        let timeInterval = endDate.timeIntervalSince(now)
        
        if timeInterval > 0 {
            let days = Int(timeInterval) / 86400
            let hours = (Int(timeInterval) % 86400) / 3600
            let minutes = (Int(timeInterval) % 3600) / 60
            let seconds = Int(timeInterval) % 60
            
            // Update countdown in Plus Plan card (index 1)
            if let plusPlanCard = planCardViews[safe: 1] {
                plusPlanCard.updateCountdown(days: days, hours: hours, minutes: minutes, seconds: seconds)
            }
        } else {
            // Timer expired
            if let plusPlanCard = planCardViews[safe: 1] {
                plusPlanCard.updateCountdown(days: 0, hours: 0, minutes: 0, seconds: 0)
            }
            countdownTimer?.invalidate()
        }
    }
}

// MARK: - LMSubscriptionAdRewardsViewDelegate
extension LMSubscriptionPage: LMSubscriptionAdRewardsViewDelegate {
    func adRewardsViewDidTapWatchAd(_ view: LMSubscriptionAdRewardsView) {
        // Handle watch ad action
        print("Watch ad tapped")
    }
    }
    
// MARK: - LMSubscriptionFooterViewDelegate
extension LMSubscriptionPage: LMSubscriptionFooterViewDelegate {
    func footerViewDidTapTerms(_ view: LMSubscriptionFooterView) {
        // Handle terms of service
        print("Terms of Service tapped")
    }
    
    func footerViewDidTapPrivacy(_ view: LMSubscriptionFooterView) {
        // Handle privacy policy
        print("Privacy Policy tapped")
    }
}

// MARK: - LMSubscriptionPlanCardViewDelegate
extension LMSubscriptionPage: LMSubscriptionPlanCardViewDelegate {
    func planCardView(_ view: LMSubscriptionPlanCardView, didTapButton plan: SubscriptionPlan) {
        Task {
            await handlePurchase(for: plan)
        }
    }
    
    func planCardView(_ view: LMSubscriptionPlanCardView, didSwitchToFreePlan plan: SubscriptionPlan) {
        dialogView.show()
    }
}

// MARK: - LMSubscriptionDialogViewDelegate
extension LMSubscriptionPage: LMSubscriptionDialogViewDelegate {
    func dialogViewDidTapCancel(_ view: LMSubscriptionDialogView) {
        dialogView.hide()
    }
    
    func dialogViewDidTapConfirm(_ view: LMSubscriptionDialogView) {
        dialogView.hide()
        // Handle switch to free plan
        print("Switched to free plan")
    }

    // MARK: - Purchase Handling
    private func handlePurchase(for plan: SubscriptionPlan) async {
        // Prevent duplicate purchases
        guard !isProcessingPurchase else { return }
        
        // Get product identifier
        guard let productIdentifier = plan.planType.productIdentifier else {
            LMLogger.log("⚠️ No product identifier for plan: \(plan.title)")
            return
        }
        
        // Get product from store manager
        guard let product = LMStoreManager.shared.getProduct(for: productIdentifier) else {
            await MainActor.run {
                showPurchaseError(StoreError.productNotFound)
            }
            return
        }
        
        isProcessingPurchase = true
        await MainActor.run {
            showLoadingOverlay(message: "Processing purchase...")
        }
        
        do {
            // Initiate purchase
            let transaction = try await LMStoreManager.shared.purchase(product)
            
            // Purchase successful
            await MainActor.run {
                hideLoadingOverlay()
                showPurchaseSuccess(plan: plan)
                updateUIForSubscriptionStatus()
            }
            
            LMLogger.log("✅ Purchase completed: \(transaction.id)")
        } catch StoreError.purchaseCancelled {
            // User cancelled - no error message needed
            await MainActor.run {
                hideLoadingOverlay()
            }
            LMLogger.log("⚠️ Purchase cancelled by user")
        } catch {
            // Show error
            await MainActor.run {
                hideLoadingOverlay()
                showPurchaseError(error)
            }
            LMLogger.log("❌ Purchase failed: \(error.localizedDescription)")
        }
        
        isProcessingPurchase = false
    }
    
    private func showLoadingOverlay(message: String) {
        // Remove existing overlay if any
        hideLoadingOverlay()
        
        // Create overlay
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        // Create container
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 16
        
        // Create activity indicator
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = UIColor.hexColor("#667eea")
        activityIndicator.startAnimating()
        
        // Create message label
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        messageLabel.textColor = UIColor.hexColor("#374151")
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        // Add subviews
        container.addSubview(activityIndicator)
        container.addSubview(messageLabel)
        overlay.addSubview(container)
        view.addSubview(overlay)
        
        // Layout
        overlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        container.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(280)
        }
        
        activityIndicator.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(32)
            make.centerX.equalToSuperview()
        }
        
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(activityIndicator.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-32)
        }
        
        loadingOverlay = overlay
    }
    
    private func hideLoadingOverlay() {
        loadingOverlay?.removeFromSuperview()
        loadingOverlay = nil
    }
    
    private func showPurchaseSuccess(plan: SubscriptionPlan) {
        let message = String(format: LMText.subscription.purchaseSuccessFormat, plan.title)
        AppTheme.Toast.showText(message)
    }
    
    private func showPurchaseError(_ error: Error) {
        let errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        
        AppTheme.Toast.showText(errorMessage)
    }
    
    private func updateUIForSubscriptionStatus() {
        let status = LMStoreManager.shared.currentSubscriptionStatus
        
        // Update plan cards based on subscription status
        for (index, cardView) in planCardViews.enumerated() {
            // This is a simplified version - in production, you'd need to update
            // the card view's button state and title based on the current subscription
            // For now, we just log the status
            LMLogger.log("📊 Current subscription status: \(status.rawValue)")
        }
    }
}

// MARK: - Array Extension for Safe Access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
