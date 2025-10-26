//
//  LMFAQPage.swift
//  processor
//
//  Created by muz on 2025/10/19.
//

import UIKit
import SnapKit

// MARK: - FAQ Data Model
struct FAQItem {
    let question: String
    let answer: String
    let id: String
}

class LMFAQPage: LMPageWrapper {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let containerView = UIView()
    
    private let titleLabel = UILabel()
    private let faqStackView = UIStackView()
    private let contactSupportView = UIView()
    
    // MARK: - Properties
    private let faqItems: [FAQItem] = [
        FAQItem(
            question: "1. How do I get more Inspire Points?",
            answer: "You can earn Inspire Points by watching ads, upgrading to our Plus Plan for unlimited points, or completing special challenges. Free users get 3 points upon signup and can earn more through ads.",
            id: "inspire_points"
        ),
        FAQItem(
            question: "2. What is the difference between Free and Plus plans?",
            answer: "Free plan includes basic camera features and limited Inspire Points. Plus plan offers unlimited Inspire Points, advanced AI features, priority support, and access to premium compositions.",
            id: "plans_difference"
        ),
        FAQItem(
            question: "3. How does the AI Guidance feature work?",
            answer: "AI Guidance helps you compose better photos by analyzing your camera view and providing real-time suggestions. It compares your current view with reference images and guides you to achieve similar compositions.",
            id: "ai_guidance"
        ),
        FAQItem(
            question: "4. Can I save my favorite compositions?",
            answer: "Yes! You can save any composition you like by tapping the heart icon. Saved compositions will appear in your \"Saved Ideas\" tab in the Profile section for easy access later.",
            id: "save_compositions"
        ),
        FAQItem(
            question: "5. How do I change my subscription plan?",
            answer: "Go to Profile > More Options > Account Profile, then tap on your subscription type. You can upgrade to Plus plan or manage your current subscription from there.",
            id: "change_subscription"
        ),
        FAQItem(
            question: "6. Why can't I access certain features?",
            answer: "Some advanced features require Inspire Points or a Plus subscription. Check your current plan and Inspire Points balance in your Profile. You can earn more points by watching ads or upgrading your plan.",
            id: "feature_access"
        ),
        FAQItem(
            question: "7. How do I delete my photos from the gallery?",
            answer: "In your Profile, go to the Gallery tab, tap on any photo, then tap the three dots menu and select \"Delete\". You'll be asked to confirm the deletion before it's permanently removed.",
            id: "delete_photos"
        ),
        FAQItem(
            question: "8. Is my data secure and private?",
            answer: "Yes, we take privacy seriously. Your photos are stored securely and we never share your personal data. You can read our full Privacy Policy in the About section for more details.",
            id: "data_security"
        )
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = "Frequent Questions"
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        setupFAQItems()
        setupContactSupportSection()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
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
        titleLabel.text = "Common Questions & Answers"
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
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
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
    
    private func createFAQItemView(faqItem: FAQItem, isLast: Bool) -> UIView {
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
            make.top.equalToSuperview()
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
        iconImageView.image = UIImage(systemName: "questionmark.circle")
        iconImageView.tintColor = UIColor.systemGray
        iconImageView.contentMode = .scaleAspectFit
        
        let contentStackView = UIStackView()
        contentStackView.axis = .vertical
        contentStackView.spacing = 4
        contentStackView.alignment = .leading
        
        let titleLabel = UILabel()
        titleLabel.text = "Still have questions?"
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor.label
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Contact our support team for personalized help."
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = UIColor.systemGray
        subtitleLabel.numberOfLines = 0
        
        let contactButton = UIButton()
        contactButton.setTitle("Contact Us", for: .normal)
        contactButton.setTitleColor(UIColor.systemBlue, for: .normal)
        contactButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        contactButton.addTarget(self, action: #selector(handleContactUsButtonTapped), for: .touchUpInside)
        
        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(subtitleLabel)
        
        contactSupportView.addSubview(iconImageView)
        contactSupportView.addSubview(contentStackView)
        contactSupportView.addSubview(contactButton)
        
        iconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        
        contentStackView.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(contactButton.snp.leading).offset(-16)
        }
        
        contactButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
        
        contactSupportView.snp.makeConstraints { make in
            make.height.greaterThanOrEqualTo(80)
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
    
    func scrollToFAQ(withId id: String) {
        // 滚动到特定的FAQ项目
        if let index = faqItems.firstIndex(where: { $0.id == id }) {
            let faqView = faqStackView.arrangedSubviews[index]
            scrollView.scrollRectToVisible(faqView.frame, animated: true)
        }
    }
    
    func addCustomFAQ(question: String, answer: String) {
        // 动态添加FAQ项目的方法
        let customFAQ = FAQItem(question: question, answer: answer, id: "custom_\(Date().timeIntervalSince1970)")
        let faqView = createFAQItemView(faqItem: customFAQ, isLast: true)
        
        // 更新最后一个项目，添加分隔线
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
