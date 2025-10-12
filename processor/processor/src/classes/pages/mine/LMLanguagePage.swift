//
//  LMLanguagePage.swift
//  processor
//
//  Created by muz on 2025/10/6.
//

import UIKit
import SnapKit

class LMLanguagePage: LMPageWrapper {
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Select Language Section
    private let selectLanguageTitleLabel = UILabel()
    private let languageSelectionContainer = UIView()
    private let languageSelectionButton = UIButton()
    private let languageLabel = UILabel()
    private let dropdownArrowImageView = UIImageView()
    
    // MARK: - Properties
    private let availableLanguages = [
        ("en", "English"),
        ("zh-Hans", "中文-简"),
        ("zh-Hant", "中文-繁"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("es", "Español"),
    ]
    
    private var selectedLanguageCode: String = "zh-Hans"
    private var selectedLanguageName: String = "中文-简"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = "Language"
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        loadCurrentLanguage()
    }
}

// MARK: - Setup Methods
extension LMLanguagePage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(selectLanguageTitleLabel)
        contentView.addSubview(languageSelectionContainer)
        
        languageSelectionContainer.addSubview(languageSelectionButton)
        languageSelectionContainer.addSubview(languageLabel)
        languageSelectionContainer.addSubview(dropdownArrowImageView)
        
        setupSelectLanguageSection()
        setupLanguageSelectionContainer()
    }
    
    private func setupSelectLanguageSection() {
        selectLanguageTitleLabel.text = "Select Language"
        selectLanguageTitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        selectLanguageTitleLabel.textColor = UIColor.label
        selectLanguageTitleLabel.textAlignment = .left
    }
    
    private func setupLanguageSelectionContainer() {
        // Container setup
        languageSelectionContainer.backgroundColor = UIColor.systemBackground
        languageSelectionContainer.layer.cornerRadius = 12
        languageSelectionContainer.layer.borderWidth = 1
        languageSelectionContainer.layer.borderColor = UIColor.systemGray4.cgColor
        languageSelectionContainer.layer.shadowColor = UIColor.black.cgColor
        languageSelectionContainer.layer.shadowOffset = CGSize(width: 0, height: 1)
        languageSelectionContainer.layer.shadowRadius = 3
        languageSelectionContainer.layer.shadowOpacity = 0.1
        
        // Language label setup
        languageLabel.text = selectedLanguageName
        languageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        languageLabel.textColor = UIColor.label
        languageLabel.textAlignment = .left
        
        // Dropdown arrow setup
        dropdownArrowImageView.image = UIImage(systemName: "chevron.down")
        dropdownArrowImageView.tintColor = UIColor.systemGray2
        dropdownArrowImageView.contentMode = .scaleAspectFit
        
        // Selection button setup (invisible overlay)
        languageSelectionButton.backgroundColor = UIColor.clear
        languageSelectionButton.addTarget(self, action: #selector(handleLanguageSelectionButtonTapped), for: .touchUpInside)
        
        // Add tap gesture for better user experience
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleLanguageSelectionButtonTapped))
        languageSelectionContainer.addGestureRecognizer(tapGesture)
        languageSelectionContainer.isUserInteractionEnabled = true
    }
}

// MARK: - Layout Configuration
extension LMLanguagePage {
    
    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        // Select Language Title
        selectLanguageTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(32)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        // Language Selection Container
        languageSelectionContainer.snp.makeConstraints { make in
            make.top.equalTo(selectLanguageTitleLabel.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
            make.height.equalTo(56)
            make.bottom.equalToSuperview().offset(-40)
        }
        
        // Language Selection Button (invisible overlay)
        languageSelectionButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Language Label
        languageLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalTo(dropdownArrowImageView.snp.leading).offset(-16)
        }
        
        // Dropdown Arrow
        dropdownArrowImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().offset(-16)
            make.size.equalTo(16)
        }
    }
}

// MARK: - Style Configuration
extension LMLanguagePage {
    
    private func configureDefaultContentAndStyles() {
        view.backgroundColor = UIColor.systemGroupedBackground
        scrollView.backgroundColor = UIColor.clear
        scrollView.showsVerticalScrollIndicator = false
        contentView.backgroundColor = UIColor.clear
    }
}

// MARK: - Action Handlers
extension LMLanguagePage {
    
    @objc private func handleBackButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func handleLanguageSelectionButtonTapped() {
        showLanguageSelectionActionSheet()
    }
}

// MARK: - Language Selection Methods
extension LMLanguagePage {
    
    private func loadCurrentLanguage() {
        // 获取当前设置的语言
        if let currentLanguages = UserDefaults.standard.object(forKey: "AppleLanguages") as? [String],
           let currentLanguage = currentLanguages.first {
            
            // 查找匹配的语言
            for (code, name) in availableLanguages {
                if currentLanguage.hasPrefix(code) {
                    selectedLanguageCode = code
                    selectedLanguageName = name
                    languageLabel.text = selectedLanguageName
                    return
                }
            }
        }
        
        // 默认语言
        selectedLanguageCode = "zh-Hans"
        selectedLanguageName = "中文-简"
        languageLabel.text = selectedLanguageName
    }
    
    private func showLanguageSelectionActionSheet() {
        let alert = UIAlertController(
            title: "Select Language",
            message: "Choose your preferred language",
            preferredStyle: .actionSheet
        )
        
        // 添加所有可用语言选项
        for (code, name) in availableLanguages {
            let action = UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.selectLanguage(code: code, name: name)
            }
            
            // 标记当前选中的语言
            if code == selectedLanguageCode {
                action.setValue(UIImage(systemName: "checkmark"), forKey: "image")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = languageSelectionContainer
            popover.sourceRect = languageSelectionContainer.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func selectLanguage(code: String, name: String) {
        // 更新UI
        selectedLanguageCode = code
        selectedLanguageName = name
        languageLabel.text = selectedLanguageName
        
        // 添加选择动画
        animateLanguageSelection()
        
        // 保存语言设置
        saveLanguagePreference(code: code)
        
        // 显示重启提示
        showRestartAlert()
    }
    
    private func animateLanguageSelection() {
        // 添加轻微的缩放动画来提供视觉反馈
        UIView.animate(withDuration: 0.1, animations: {
            self.languageSelectionContainer.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.languageSelectionContainer.transform = CGAffineTransform.identity
            }
        }
    }
    
    private func saveLanguagePreference(code: String) {
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    private func showRestartAlert() {
        let alert = UIAlertController(
            title: "Language Changed",
            message: "Please restart the app to apply the language change.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Utility Methods
extension LMLanguagePage {
    
    private func getLanguageDisplayName(for code: String) -> String {
        for (langCode, name) in availableLanguages {
            if langCode == code {
                return name
            }
        }
        return "English" // 默认返回英语
    }
    
    private func getCurrentSystemLanguage() -> String {
        return Locale.current.languageCode ?? "en"
    }
}
