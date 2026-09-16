//
//  LMFAQPage.swift
//  processor
//
//  Created by muz on 2025/10/19.
//

import UIKit
import SnapKit

class LMFAQPage: LMPageWrapper {
    
    override var usesMineNavigationBarStyle: Bool { true }
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let containerView = UIView()
    
    private let titleLabel = UILabel()
    private let faqStackView = UIStackView()
    private let contactSupportView = UIView()
    
    // MARK: - Properties
    // FAQ items are now loaded from language configuration
    private var faqItems: [LMFAQItem] {
        return LMText.settings.faqs
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.frequentQuestions
        
        // Debug: Check FAQ items count
        LMLogger.log("📋 FAQ Page - Loading FAQs")
        LMLogger.log("📋 FAQ items count: \(faqItems.count)")
        for (index, item) in faqItems.enumerated() {
            LMLogger.log("📋 FAQ \(index + 1): \(item.question)")
        }
        
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        setupFAQItems()
        setupContactSupportSection()
        
        // Register for language change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: LMLaunageManager.languageDidChangeNotification,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleLanguageChange() {
        // Update page title
        barTitle = LMText.settings.frequentQuestions
        
        // Update title label
        titleLabel.text = LMText.settings.faq
        
        // Reload FAQ items
        reloadFAQItems()
    }
    
    private func reloadFAQItems() {
        // Remove all existing FAQ views
        faqStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Re-add FAQ items with new language
        setupFAQItems()
    }
}

// MARK: - Setup Methods
extension LMFAQPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(containerView)
        
        containerView.addSubview(titleLabel)
        containerView.addSubview(faqStackView)
        containerView.addSubview(contactSupportView)
        
        setupTitleLabel()
        setupFAQStackView()
    }
    
    private func setupTitleLabel() {
        titleLabel.text = LMText.settings.faq
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.textAlignment = .left
    }
    
    private func setupFAQStackView() {
        faqStackView.axis = .vertical
        faqStackView.spacing = 0
        faqStackView.alignment = .fill
        faqStackView.distribution = .fill
    }
}

// MARK: - Layout Configuration
extension LMFAQPage {
    
    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        containerView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        faqStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        contactSupportView.snp.makeConstraints { make in
            make.top.equalTo(faqStackView.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-24)
        }
    }
}

// MARK: - Style Configuration
extension LMFAQPage {
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = UIColor.systemGroupedBackground
        scrollView.backgroundColor = UIColor.clear
        scrollView.showsVerticalScrollIndicator = false
        contentView.backgroundColor = UIColor.clear
        
        // Container styling
        containerView.backgroundColor = UIColor.systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.1
    }
}

// MARK: - FAQ Items Setup
extension LMFAQPage {
    
    private func setupFAQItems() {
        for (index, faqItem) in faqItems.enumerated() {
            let faqView = createFAQItemView(faqItem: faqItem, isLast: index == faqItems.count - 1)
            faqStackView.addArrangedSubview(faqView)
        }
    }
    
    private func createFAQItemView(faqItem: LMFAQItem, isLast: Bool) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.clear
        
        let questionLabel = UILabel()
        questionLabel.text = faqItem.question
        questionLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        questionLabel.textColor = UIColor.label
        questionLabel.numberOfLines = 0
        
        let answerLabel = UILabel()
        answerLabel.text = faqItem.answer
        answerLabel.font = UIFont.systemFont(ofSize: 14)
        answerLabel.textColor = UIColor.systemGray
        answerLabel.numberOfLines = 0
        answerLabel.lineBreakMode = .byWordWrapping
        
        containerView.addSubview(questionLabel)
        containerView.addSubview(answerLabel)
        
        questionLabel.snp.makeConstraints { make in
            make.top.equalTo(16)
            make.leading.trailing.equalToSuperview()
        }
        
        answerLabel.snp.makeConstraints { make in
            make.top.equalTo(questionLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(isLast ? 0 : -16)
        }
        
        // Add separator line if not the last item
        if !isLast {
            let separatorView = UIView()
            separatorView.backgroundColor = UIColor.systemGray6
            containerView.addSubview(separatorView)
            
            separatorView.snp.makeConstraints { make in
                make.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(1)
            }
        }
        
        return containerView
    }
}

// MARK: - Contact Support Section
extension LMFAQPage {
    
    private func setupContactSupportSection() {
        contactSupportView.backgroundColor = UIColor.systemGray6
        contactSupportView.layer.cornerRadius = 12
        
        let iconImageView = UIImageView()
        iconImageView.image = UIImage.lmSymbol("questionmark.circle", pointSize: 20)
        iconImageView.tintColor = .systemGray
        
        let titleLabel = UILabel()
        titleLabel.text = LMText.settings.stillHaveQuestions
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor.label
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = LMText.settings.contactSupport
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = UIColor.systemGray
        subtitleLabel.numberOfLines = 0
        
        let contactButton = UIButton()
        contactButton.setTitle(LMText.settings.contactUs, for: .normal)
        contactButton.setTitleColor(UIColor.systemBlue, for: .normal)
        contactButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        contactButton.addTarget(self, action: #selector(handleContactUsButtonTapped), for: .touchUpInside)
        
        
        contactSupportView.addSubview(iconImageView)
        contactSupportView.addSubview(titleLabel)
        contactSupportView.addSubview(subtitleLabel)
        contactSupportView.addSubview(contactButton)
        
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.equalTo(16)
            make.size.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconImageView)
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.trailing.equalTo(-16)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(titleLabel)
        }
        
        contactButton.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(8)
            make.leading.equalTo(subtitleLabel)
            make.bottom.equalTo(-16)
        }
    }
}

// MARK: - Action Handlers
extension LMFAQPage {
    
    @objc private func handleBackButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func handleContactUsButtonTapped() {
        let contactUsPage = LMContactUsPage()
        navigationController?.pushViewController(contactUsPage, animated: true)
    }
}

// MARK: - Public Methods
extension LMFAQPage {
    
    func addCustomFAQ(question: String, answer: String) {
        // Note: This method creates a temporary FAQ item for display only
        // It won't be persisted to the language configuration
        let customFAQ = LMFAQItem(question: question, answer: answer)
        let faqView = createFAQItemView(faqItem: customFAQ, isLast: true)
        
        // Update the last item to add a separator line
        if let lastView = faqStackView.arrangedSubviews.last {
            let separatorView = UIView()
            separatorView.backgroundColor = UIColor.systemGray6
            lastView.addSubview(separatorView)
            
            separatorView.snp.makeConstraints { make in
                make.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(1)
            }
        }
        
        faqStackView.addArrangedSubview(faqView)
    }
}
