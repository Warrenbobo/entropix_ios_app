//
//  LMContactUsPage.swift
//  processor
//
//  Created by muz on 2025/10/6.
//

import UIKit
import SnapKit

class LMContactUsPage: LMPageWrapper {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Get in Touch Section
    private let getInTouchTitleLabel = UILabel()
    
    // Discord Section
    private let discordContainer = UIView()
    private let discordIconView = UIView()
    private let discordIconImageView = UIImageView()
    private let discordTitleLabel = UILabel()
    private let discordSubtitleLabel = UILabel()
    private let discordInviteLinkLabel = UILabel()
    private let discordLinkLabel = UILabel()
    private let discordCopyButton = UIButton()
    
    // Email Section
    private let emailContainer = UIView()
    private let emailIconView = UIView()
    private let emailIconImageView = UIImageView()
    private let emailTitleLabel = UILabel()
    private let emailSubtitleLabel = UILabel()
    private let emailAddressLabel = UILabel()
    private let emailLinkLabel = UILabel()
    private let emailCopyButton = UIButton()
    
    // Need Help Section
    private let needHelpContainer = UIView()
    private let needHelpIconView = UIView()
    private let needHelpIconImageView = UIImageView()
    private let needHelpTitleLabel = UILabel()
    private let needHelpDescriptionLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = "Contact Us"
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
    }
}

// MARK: - Setup Methods
extension LMContactUsPage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add main components
        contentView.addSubview(getInTouchTitleLabel)
        contentView.addSubview(discordContainer)
        contentView.addSubview(emailContainer)
        contentView.addSubview(needHelpContainer)
        
        // Setup Discord container
        discordContainer.addSubview(discordIconView)
        discordIconView.addSubview(discordIconImageView)
        discordContainer.addSubview(discordTitleLabel)
        discordContainer.addSubview(discordSubtitleLabel)
        discordContainer.addSubview(discordInviteLinkLabel)
        discordContainer.addSubview(discordLinkLabel)
        discordContainer.addSubview(discordCopyButton)
        
        // Setup Email container
        emailContainer.addSubview(emailIconView)
        emailIconView.addSubview(emailIconImageView)
        emailContainer.addSubview(emailTitleLabel)
        emailContainer.addSubview(emailSubtitleLabel)
        emailContainer.addSubview(emailAddressLabel)
        emailContainer.addSubview(emailLinkLabel)
        emailContainer.addSubview(emailCopyButton)
        
        // Setup Need Help container
        needHelpContainer.addSubview(needHelpIconView)
        needHelpIconView.addSubview(needHelpIconImageView)
        needHelpContainer.addSubview(needHelpTitleLabel)
        needHelpContainer.addSubview(needHelpDescriptionLabel)
        
        setupGetInTouchSection()
        setupDiscordSection()
        setupEmailSection()
        setupNeedHelpSection()
    }
    
    private func setupGetInTouchSection() {
        getInTouchTitleLabel.text = "Get in Touch"
        getInTouchTitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        getInTouchTitleLabel.textColor = UIColor.label
        getInTouchTitleLabel.textAlignment = .left
    }
    
    private func setupDiscordSection() {
        // Container setup
        discordContainer.backgroundColor = UIColor.systemBackground
        discordContainer.layer.cornerRadius = 16
        discordContainer.layer.shadowColor = UIColor.black.cgColor
        discordContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        discordContainer.layer.shadowRadius = 8
        discordContainer.layer.shadowOpacity = 0.1
        
        // Icon setup
        discordIconView.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.2)
        discordIconView.layer.cornerRadius = 12
        
        discordIconImageView.image = UIImage(systemName: "message.fill")
        discordIconImageView.tintColor = UIColor.systemPurple
        discordIconImageView.contentMode = .scaleAspectFit
        
        // Labels setup
        discordTitleLabel.text = "Join Our Discord Channel"
        discordTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        discordTitleLabel.textColor = UIColor.label
        
        discordSubtitleLabel.text = "Connect with our community"
        discordSubtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        discordSubtitleLabel.textColor = UIColor.systemGray
        
        discordInviteLinkLabel.text = "Invite Link:"
        discordInviteLinkLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        discordInviteLinkLabel.textColor = UIColor.systemGray
        
        discordLinkLabel.text = "https://discord.gg/myerMyeCLM"
        discordLinkLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        discordLinkLabel.textColor = UIColor.systemBlue
        discordLinkLabel.numberOfLines = 0
        
        // Copy button setup
        discordCopyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        discordCopyButton.tintColor = UIColor.systemBlue
        discordCopyButton.addTarget(self, action: #selector(handleDiscordCopyButtonTapped), for: .touchUpInside)
        
        // Add tap gesture to container
        let discordTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDiscordContainerTapped))
        discordContainer.addGestureRecognizer(discordTapGesture)
        discordContainer.isUserInteractionEnabled = true
    }
    
    private func setupEmailSection() {
        // Container setup
        emailContainer.backgroundColor = UIColor.systemBackground
        emailContainer.layer.cornerRadius = 16
        emailContainer.layer.shadowColor = UIColor.black.cgColor
        emailContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        emailContainer.layer.shadowRadius = 8
        emailContainer.layer.shadowOpacity = 0.1
        
        // Icon setup
        emailIconView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        emailIconView.layer.cornerRadius = 12
        
        emailIconImageView.image = UIImage(systemName: "envelope.fill")
        emailIconImageView.tintColor = UIColor.systemBlue
        emailIconImageView.contentMode = .scaleAspectFit
        
        // Labels setup
        emailTitleLabel.text = "Email"
        emailTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        emailTitleLabel.textColor = UIColor.label
        
        emailSubtitleLabel.text = "Send us a message directly"
        emailSubtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        emailSubtitleLabel.textColor = UIColor.systemGray
        
        emailAddressLabel.text = "Email Address:"
        emailAddressLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        emailAddressLabel.textColor = UIColor.systemGray
        
        emailLinkLabel.text = "support@framaiist.com"
        emailLinkLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        emailLinkLabel.textColor = UIColor.systemBlue
        emailLinkLabel.numberOfLines = 0
        
        // Copy button setup
        emailCopyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        emailCopyButton.tintColor = UIColor.systemBlue
        emailCopyButton.addTarget(self, action: #selector(handleEmailCopyButtonTapped), for: .touchUpInside)
        
        // Add tap gesture to container
        let emailTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleEmailContainerTapped))
        emailContainer.addGestureRecognizer(emailTapGesture)
        emailContainer.isUserInteractionEnabled = true
    }
    
    private func setupNeedHelpSection() {
        // Container setup
        needHelpContainer.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        needHelpContainer.layer.cornerRadius = 16
        
        // Icon setup
        needHelpIconView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        needHelpIconView.layer.cornerRadius = 12
        
        needHelpIconImageView.image = UIImage(systemName: "info.circle.fill")
        needHelpIconImageView.tintColor = UIColor.systemBlue
        needHelpIconImageView.contentMode = .scaleAspectFit
        
        // Labels setup
        needHelpTitleLabel.text = "Need Help?"
        needHelpTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        needHelpTitleLabel.textColor = UIColor.systemBlue
        
        needHelpDescriptionLabel.text = "We typically respond within 24 hours."
        needHelpDescriptionLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        needHelpDescriptionLabel.textColor = UIColor.systemBlue
        needHelpDescriptionLabel.numberOfLines = 0
    }
}

// MARK: - Layout Configuration
extension LMContactUsPage {
    
    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        // Get in Touch Title
        getInTouchTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        // Discord Container
        discordContainer.snp.makeConstraints { make in
            make.top.equalTo(getInTouchTitleLabel.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        discordIconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(20)
            make.size.equalTo(48)
        }
        
        discordIconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }
        
        discordTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalTo(discordIconView.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        discordSubtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(discordTitleLabel.snp.bottom).offset(4)
            make.leading.equalTo(discordTitleLabel)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        discordInviteLinkLabel.snp.makeConstraints { make in
            make.top.equalTo(discordSubtitleLabel.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        discordLinkLabel.snp.makeConstraints { make in
            make.top.equalTo(discordInviteLinkLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(discordCopyButton.snp.leading).offset(-8)
        }
        
        discordCopyButton.snp.makeConstraints { make in
            make.centerY.equalTo(discordLinkLabel)
            make.trailing.equalToSuperview().offset(-20)
            make.size.equalTo(24)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        // Email Container
        emailContainer.snp.makeConstraints { make in
            make.top.equalTo(discordContainer.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        
        emailIconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(20)
            make.size.equalTo(48)
        }
        
        emailIconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }
        
        emailTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalTo(emailIconView.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        emailSubtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(emailTitleLabel.snp.bottom).offset(4)
            make.leading.equalTo(emailTitleLabel)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        emailAddressLabel.snp.makeConstraints { make in
            make.top.equalTo(emailSubtitleLabel.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        emailLinkLabel.snp.makeConstraints { make in
            make.top.equalTo(emailAddressLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(emailCopyButton.snp.leading).offset(-8)
        }
        
        emailCopyButton.snp.makeConstraints { make in
            make.centerY.equalTo(emailLinkLabel)
            make.trailing.equalToSuperview().offset(-20)
            make.size.equalTo(24)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        // Need Help Container
        needHelpContainer.snp.makeConstraints { make in
            make.top.equalTo(emailContainer.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-40)
        }
        
        needHelpIconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(20)
            make.size.equalTo(48)
        }
        
        needHelpIconImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }
        
        needHelpTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.equalTo(needHelpIconView.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-20)
        }
        
        needHelpDescriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(needHelpTitleLabel.snp.bottom).offset(8)
            make.leading.equalTo(needHelpTitleLabel)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-20)
        }
    }
}

// MARK: - Style Configuration
extension LMContactUsPage {
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = UIColor.systemGroupedBackground
        scrollView.backgroundColor = UIColor.clear
        scrollView.showsVerticalScrollIndicator = false
        contentView.backgroundColor = UIColor.clear
    }
}

// MARK: - Action Handlers
extension LMContactUsPage {
    
    @objc private func handleBackButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func handleDiscordContainerTapped() {
        openDiscordInvite()
    }
    
    @objc private func handleDiscordCopyButtonTapped() {
        copyToClipboard(text: "https://discord.gg/myerMyeCLM", message: "Discord invite link copied!")
    }
    
    @objc private func handleEmailContainerTapped() {
        openEmailClient()
    }
    
    @objc private func handleEmailCopyButtonTapped() {
        copyToClipboard(text: "support@framaiist.com", message: "Email address copied!")
    }
}

// MARK: - Helper Methods
extension LMContactUsPage {
    
    private func openDiscordInvite() {
        guard let url = URL(string: "https://discord.gg/myerMyeCLM") else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            showAlert(title: "Unable to Open", message: "Please copy the invite link and open it in your browser.")
        }
    }
    
    private func openEmailClient() {
        guard let url = URL(string: "mailto:support@framaiist.com") else { return }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            showAlert(title: "Unable to Open", message: "Please copy the email address and use your preferred email client.")
        }
    }
    
    private func copyToClipboard(text: String, message: String) {
        UIPasteboard.general.string = text
        
        // Show success feedback
        let alert = UIAlertController(title: "Copied!", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
