//
//  LMLanguagePage.swift
//  processor
//
//  Created by muz on 2025/10/6.
//

import UIKit
import SnapKit
import Toast_Swift

class LMLanguagePage: LMPageWrapper {
    
    // MARK: - UI Components
    private let contentView = UIView()
    
    // Select Language Section
    private let selectLanguageTitleLabel = UILabel()
    private let languageSelectionContainer = UIView()
    private let languageSelectionButton = UIButton()
    private let languageLabel = UILabel()
    private let dropdownArrowImageView = UIImageView()
    
    // MARK: - Properties
    private let availableLanguages: [LMLanguageType] = [.english, .simplifiedChinese, .traditionalChinese]
    private var currentLanguage: LMLanguageType {
        return LMLaunageManager.shared.currentLanguage
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.language
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        updateLanguageDisplay()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateLanguageDisplay()
    }
}

// MARK: - Setup Methods
extension LMLanguagePage {
    
    private func setupUserInterfaceComponents() {
        view.addSubview(contentView)
        
        contentView.addSubview(selectLanguageTitleLabel)
        contentView.addSubview(languageSelectionContainer)
        
        languageSelectionContainer.addSubview(languageSelectionButton)
        languageSelectionContainer.addSubview(languageLabel)
        languageSelectionContainer.addSubview(dropdownArrowImageView)
        
        setupSelectLanguageSection()
        setupLanguageSelectionContainer()
    }
    
    private func setupSelectLanguageSection() {
        selectLanguageTitleLabel.text = LMText.settings.selectLanguage
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
        
        contentView.snp.makeConstraints { make in
            make.top.equalTo(AppTheme.Screen.navigatorHeight)
            make.leading.trailing.equalToSuperview()
        }
        
        // Select Language Title
        selectLanguageTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
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
        contentView.backgroundColor = UIColor.white
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
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
    
    private func updateLanguageDisplay() {
        // 更新显示当前语言
        languageLabel.text = currentLanguage.displayName
    }
    
    private func showLanguageSelectionActionSheet() {
        let alert = UIAlertController(
            title: LMText.settings.selectLanguage,
            message: nil,
            preferredStyle: .actionSheet
        )
        
        // 添加所有可用语言选项
        for language in availableLanguages {
            let action = UIAlertAction(title: language.displayName, style: .default) { [weak self] _ in
                self?.selectLanguage(language)
            }
            
            // 标记当前选中的语言
            if language == currentLanguage {
                action.setValue(UIImage(systemName: "checkmark"), forKey: "image")
            }
            
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: LMText.common.cancel, style: .cancel))
        
        // iPad支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = languageSelectionContainer
            popover.sourceRect = languageSelectionContainer.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func selectLanguage(_ language: LMLanguageType) {
        // 如果选择的是当前语言，不做任何操作
        guard language != currentLanguage else {
            return
        }
        
        // 显示确认对话框
        showLanguageChangeConfirmation(for: language)
    }
    
    private func showLanguageChangeConfirmation(for language: LMLanguageType) {
        let alert = UIAlertController(
            title: LMText.settings.language,
            message: String(format: LMText.settings.switchToFormat, language.displayName),
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LMText.common.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: LMText.common.confirm, style: .default) { [weak self] _ in
            self?.performLanguageSwitch(to: language)
        })
        
        present(alert, animated: true)
    }
    
    private func performLanguageSwitch(to language: LMLanguageType) {
        // 添加选择动画
        animateLanguageSelection()
        
        // 切换语言
        LMLaunageManager.shared.switchLanguage(to: language)
        
        // 更新显示
        updateLanguageDisplay()
        
        // 更新页面标题
        barTitle = LMText.settings.language
        
        // 显示成功提示
        showLanguageChangedAlert()
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
    
    private func showLanguageChangedAlert() {
        let rootController = LMMinePage()
        LMPackageManager.switchWindowSceneContent(LMNavigationWrapper(rootViewController: rootController))
        AppTheme.Toast.showText(LMText.settings.languageChangedSuccess)
    }
}
