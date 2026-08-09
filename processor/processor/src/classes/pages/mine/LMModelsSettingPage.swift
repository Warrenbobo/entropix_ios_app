//
//  LMModelsSettingPage.swift
//  processor
//
//  Mine → Setting → Models — Gemini (Inspire Me) + Qwen (Agent) BYOK configuration.
//

import UIKit
import SnapKit

/// Settings page for Gemini Inspire Me and Qwen Agent LLM credentials.
final class LMModelsSettingPage: LMPageWrapper {

    override var usesMineNavigationBarStyle: Bool { true }

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // MARK: Gemini section

    private let geminiCard = UIView()
    private let geminiHeaderIcon = UIImageView()
    private let geminiHeaderIconBg = UIView()
    private let geminiSectionLabel = UILabel()
    private let geminiSectionHintLabel = UILabel()
    private let geminiDivider = UIView()
    private let geminiProviderTitleLabel = UILabel()
    private let geminiProviderValueLabel = UILabel()
    private let geminiModelTitleLabel = UILabel()
    private let geminiModelSegment = UISegmentedControl(items: [])
    private let geminiBaseURLField = LMValidatedInputField()
    private let geminiAPIKeyField = LMValidatedInputField()

    // MARK: Qwen section

    private let qwenCard = UIView()
    private let qwenHeaderIcon = UIImageView()
    private let qwenHeaderIconBg = UIView()
    private let qwenSectionLabel = UILabel()
    private let qwenSectionHintLabel = UILabel()
    private let qwenDivider = UIView()
    private let qwenProviderTitleLabel = UILabel()
    private let qwenProviderValueLabel = UILabel()
    private let qwenBaseURLField = LMValidatedInputField()
    private let qwenAPIKeyField = LMValidatedInputField()

    private let saveButton = UIButton(type: .system)

    private var selectedGeminiModel: LMGeminiImageModel = .flash31

    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.models
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        loadExistingSettings()
    }
}

// MARK: - Setup
extension LMModelsSettingPage {

    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(geminiCard)
        contentView.addSubview(qwenCard)
        contentView.addSubview(saveButton)

        setupGeminiCard()
        setupQwenCard()

        saveButton.setTitle(LMText.common.save, for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.layer.cornerRadius = 14
        saveButton.addTarget(self, action: #selector(handleSaveTapped), for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func setupGeminiCard() {
        [
            geminiHeaderIconBg, geminiSectionLabel, geminiSectionHintLabel, geminiDivider,
            geminiProviderTitleLabel, geminiProviderValueLabel,
            geminiModelTitleLabel, geminiModelSegment,
            geminiBaseURLField, geminiAPIKeyField
        ].forEach { geminiCard.addSubview($0) }
        geminiHeaderIconBg.addSubview(geminiHeaderIcon)

        styleSectionCard(geminiCard)
        configureHeaderIcon(
            background: geminiHeaderIconBg,
            imageView: geminiHeaderIcon,
            systemName: "apple.intelligence",
            backgroundColor: .hexColor("#EDE9FE"),
            tintColor: .hexColor("#7C3AED")
        )
        configureSectionTitle(geminiSectionLabel, text: LMText.settings.modelsSectionGemini)
        configureSectionHint(geminiSectionHintLabel, text: LMText.settings.modelsGeminiHint)
        styleDivider(geminiDivider)
        configureCaption(geminiProviderTitleLabel, text: LMText.settings.modelsProvider)
        configureValue(geminiProviderValueLabel, text: LMText.settings.modelsProviderGemini)

        geminiModelTitleLabel.text = LMText.settings.modelsModel
        geminiModelTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        geminiModelTitleLabel.textColor = .secondaryLabel

        geminiModelSegment.removeAllSegments()
        geminiModelSegment.insertSegment(withTitle: LMText.settings.gemini31FlashImage, at: 0, animated: false)
        geminiModelSegment.insertSegment(withTitle: LMText.settings.gemini3ProImage, at: 1, animated: false)
        geminiModelSegment.selectedSegmentIndex = 0
        geminiModelSegment.addTarget(self, action: #selector(handleGeminiModelChanged), for: .valueChanged)

        configureTextField(
            geminiBaseURLField,
            title: LMText.settings.modelsBaseURL,
            placeholder: AppConfigs.Gemini.defaultBaseURL,
            isSecure: false,
            keyboard: .URL
        )
        configureTextField(
            geminiAPIKeyField,
            title: LMText.settings.modelsAPIKey,
            placeholder: LMText.settings.modelsAPIKeyPlaceholder,
            isSecure: true,
            keyboard: .asciiCapable
        )
    }

    private func setupQwenCard() {
        [
            qwenHeaderIconBg, qwenSectionLabel, qwenSectionHintLabel, qwenDivider,
            qwenProviderTitleLabel, qwenProviderValueLabel,
            qwenBaseURLField, qwenAPIKeyField
        ].forEach { qwenCard.addSubview($0) }
        qwenHeaderIconBg.addSubview(qwenHeaderIcon)

        styleSectionCard(qwenCard)
        configureHeaderIcon(
            background: qwenHeaderIconBg,
            imageView: qwenHeaderIcon,
            systemName: "text.bubble.fill",
            backgroundColor: .hexColor("#FFECD5"),
            tintColor: .hexColor("#EA580C")
        )
        configureSectionTitle(qwenSectionLabel, text: LMText.settings.modelsSectionQwen)
        configureSectionHint(qwenSectionHintLabel, text: LMText.settings.modelsQwenHint)
        styleDivider(qwenDivider)
        configureCaption(qwenProviderTitleLabel, text: LMText.settings.modelsProvider)
        configureValue(qwenProviderValueLabel, text: LMText.settings.modelsProviderQwen)

        configureTextField(
            qwenBaseURLField,
            title: LMText.settings.modelsBaseURL,
            placeholder: AppConfigs.AgentLLM.defaultBaseURL,
            isSecure: false,
            keyboard: .URL
        )
        configureTextField(
            qwenAPIKeyField,
            title: LMText.settings.modelsAPIKey,
            placeholder: LMText.settings.qwenAPIKeyPlaceholder,
            isSecure: true,
            keyboard: .asciiCapable
        )
    }

    private func styleSectionCard(_ card: UIView) {
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 16
        card.layer.masksToBounds = true
        card.layer.borderWidth = 1.0 / UIScreen.main.scale
        card.layer.borderColor = UIColor.separator.withAlphaComponent(0.35).cgColor
    }

    private func styleDivider(_ view: UIView) {
        view.backgroundColor = UIColor.separator.withAlphaComponent(0.45)
    }

    private func configureHeaderIcon(
        background: UIView,
        imageView: UIImageView,
        systemName: String,
        backgroundColor: UIColor,
        tintColor: UIColor
    ) {
        background.backgroundColor = backgroundColor
        background.layer.cornerRadius = 12
        imageView.image = UIImage(systemName: systemName)?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = tintColor
        imageView.contentMode = .scaleAspectFit
    }

    private func configureSectionTitle(_ label: UILabel, text: String) {
        label.text = text
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
    }

    private func configureSectionHint(_ label: UILabel, text: String) {
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
    }

    private func configureCaption(_ label: UILabel, text: String) {
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
    }

    private func configureValue(_ label: UILabel, text: String) {
        label.text = text
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 2
    }

    private func configureTextField(
        _ field: LMValidatedInputField,
        title: String,
        placeholder: String,
        isSecure: Bool,
        keyboard: UIKeyboardType
    ) {
        field.configureInputFieldProperties(
            title: title,
            placeholder: placeholder,
            isSecure: isSecure,
            keyboardType: keyboard
        )
        field.maximumTextLength = isSecure ? 256 : 200
        field.delegate = self
    }

    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        geminiCard.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        layoutGeminiCardContent()

        qwenCard.snp.makeConstraints { make in
            make.top.equalTo(geminiCard.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        layoutQwenCardContent()

        saveButton.snp.makeConstraints { make in
            make.top.equalTo(qwenCard.snp.bottom).offset(28)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(52)
            make.bottom.equalToSuperview().offset(-40)
        }
    }

    private func layoutGeminiCardContent() {
        let inset: CGFloat = 16

        geminiHeaderIconBg.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(inset)
            make.size.equalTo(40)
        }
        geminiHeaderIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(22)
        }
        geminiSectionLabel.snp.makeConstraints { make in
            make.top.equalTo(geminiHeaderIconBg)
            make.leading.equalTo(geminiHeaderIconBg.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(inset)
        }
        geminiSectionHintLabel.snp.makeConstraints { make in
            make.top.equalTo(geminiSectionLabel.snp.bottom).offset(2)
            make.leading.equalTo(geminiSectionLabel)
            make.trailing.equalToSuperview().inset(inset)
        }
        geminiDivider.snp.makeConstraints { make in
            make.top.equalTo(geminiHeaderIconBg.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(inset)
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        geminiProviderTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(geminiDivider.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(inset)
        }
        geminiProviderValueLabel.snp.makeConstraints { make in
            make.top.equalTo(geminiProviderTitleLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(inset)
        }
        geminiModelTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(geminiProviderValueLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(inset)
        }
        geminiModelSegment.snp.makeConstraints { make in
            make.top.equalTo(geminiModelTitleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(inset)
            make.height.equalTo(34)
        }
        geminiBaseURLField.snp.makeConstraints { make in
            make.top.equalTo(geminiModelSegment.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(inset)
        }
        geminiAPIKeyField.snp.makeConstraints { make in
            make.top.equalTo(geminiBaseURLField.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(inset)
            make.bottom.equalToSuperview().inset(inset)
        }
    }

    private func layoutQwenCardContent() {
        let inset: CGFloat = 16

        qwenHeaderIconBg.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(inset)
            make.size.equalTo(40)
        }
        qwenHeaderIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(20)
        }
        qwenSectionLabel.snp.makeConstraints { make in
            make.top.equalTo(qwenHeaderIconBg)
            make.leading.equalTo(qwenHeaderIconBg.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(inset)
        }
        qwenSectionHintLabel.snp.makeConstraints { make in
            make.top.equalTo(qwenSectionLabel.snp.bottom).offset(2)
            make.leading.equalTo(qwenSectionLabel)
            make.trailing.equalToSuperview().inset(inset)
        }
        qwenDivider.snp.makeConstraints { make in
            make.top.equalTo(qwenHeaderIconBg.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(inset)
            make.height.equalTo(1.0 / UIScreen.main.scale)
        }
        qwenProviderTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(qwenDivider.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(inset)
        }
        qwenProviderValueLabel.snp.makeConstraints { make in
            make.top.equalTo(qwenProviderTitleLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(inset)
        }
        qwenBaseURLField.snp.makeConstraints { make in
            make.top.equalTo(qwenProviderValueLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(inset)
        }
        qwenAPIKeyField.snp.makeConstraints { make in
            make.top.equalTo(qwenBaseURLField.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(inset)
            make.bottom.equalToSuperview().inset(inset)
        }
    }

    private func configureDefaultContentAndStyles() {
        view.backgroundColor = .systemGroupedBackground
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .onDrag
        contentView.backgroundColor = .clear
    }

    private func loadExistingSettings() {
        let gemini = LMGeminiModelSettingsStore.load()
        geminiBaseURLField.text = gemini.baseURL
        geminiAPIKeyField.text = gemini.apiKey
        selectedGeminiModel = gemini.model
        geminiModelSegment.selectedSegmentIndex = gemini.model == .flash31 ? 0 : 1

        let qwen = LMQwenModelSettingsStore.load()
        qwenBaseURLField.text = qwen.baseURL
        qwenAPIKeyField.text = qwen.apiKey
    }
}

// MARK: - Actions
extension LMModelsSettingPage {

    @objc private func handleGeminiModelChanged() {
        selectedGeminiModel = geminiModelSegment.selectedSegmentIndex == 0 ? .flash31 : .pro3
    }

    @objc private func handleBackgroundTap() {
        view.endEditing(true)
    }

    @objc private func handleSaveTapped() {
        view.endEditing(true)
        [
            geminiBaseURLField, geminiAPIKeyField,
            qwenBaseURLField, qwenAPIKeyField
        ].forEach { $0.clearErrorMessageDisplay() }

        let geminiBase = geminiBaseURLField.text ?? ""
        let geminiKey = geminiAPIKeyField.text ?? ""
        let qwenBase = qwenBaseURLField.text ?? ""
        let qwenKey = qwenAPIKeyField.text ?? ""

        if let error = LMGeminiModelSettingsStore.validate(
            baseURL: geminiBase,
            apiKey: geminiKey,
            model: selectedGeminiModel
        ) {
            if error == LMText.settings.modelsAPIKeyRequired {
                geminiAPIKeyField.displayErrorMessageWithText(error)
            } else {
                geminiBaseURLField.displayErrorMessageWithText(error)
            }
            AppTheme.Toast.showText(error)
            return
        }

        if let error = LMQwenModelSettingsStore.validate(baseURL: qwenBase, apiKey: qwenKey) {
            if error == LMText.settings.modelsAPIKeyRequired {
                qwenAPIKeyField.displayErrorMessageWithText(error)
            } else {
                qwenBaseURLField.displayErrorMessageWithText(error)
            }
            AppTheme.Toast.showText(error)
            return
        }

        LMGeminiModelSettingsStore.save(
            LMGeminiModelSettings(
                baseURL: geminiBase,
                apiKey: geminiKey,
                model: selectedGeminiModel
            )
        )
        LMQwenModelSettingsStore.save(
            LMQwenModelSettings(baseURL: qwenBase, apiKey: qwenKey)
        )
        AppTheme.Toast.showText(LMText.settings.modelsSaved)
    }
}

// MARK: - LMValidatedInputFieldDelegate
extension LMModelsSettingPage: LMValidatedInputFieldDelegate {

    func validatedInputFieldDidChangeText(_ inputField: LMValidatedInputField, text: String) {
        inputField.clearErrorMessageDisplay()
    }

    func validatedInputFieldDidBeginEditing(_ inputField: LMValidatedInputField) {}

    func validatedInputFieldDidEndEditing(_ inputField: LMValidatedInputField) {}

    func validatedInputFieldShouldReturn(_ inputField: LMValidatedInputField) -> Bool {
        let order: [LMValidatedInputField] = [
            geminiBaseURLField, geminiAPIKeyField,
            qwenBaseURLField, qwenAPIKeyField
        ]
        if let index = order.firstIndex(where: { $0 === inputField }),
           index + 1 < order.count {
            _ = order[index + 1].becomeFirstResponder()
        } else {
            _ = inputField.resignFirstResponder()
            handleSaveTapped()
        }
        return true
    }
}
