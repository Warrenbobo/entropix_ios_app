//
//  LMIdeaInspirationSettingPage.swift
//  processor
//
//  Models sub-page for Idea Inspiration (Gemini). No enable_thinking controls.
//

import UIKit
import SnapKit

/// Idea Inspiration (Gemini) connection settings editor.
final class LMIdeaInspirationSettingPage: LMPageWrapper {

    override var usesMineNavigationBarStyle: Bool { true }

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let card = UIView()

    private let hintLabel = UILabel()
    private let providerTitleLabel = UILabel()
    private let providerValueLabel = UILabel()
    private let modelTitleLabel = UILabel()
    private let modelSegment = UISegmentedControl(items: [])
    private let baseURLField = LMValidatedInputField()
    private let apiKeyField = LMValidatedInputField()

    private let saveButton = UIButton(type: .system)
    private let restoreButton = UIButton(type: .system)

    private var selectedModel: LMGeminiImageModel = .flash31

    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.modelsSectionIdeaInspiration
        setupUI()
        configureLayout()
        loadSettings()
    }
}

private extension LMIdeaInspirationSettingPage {

    func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(card)
        contentView.addSubview(saveButton)
        contentView.addSubview(restoreButton)

        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 14

        hintLabel.font = .systemFont(ofSize: 13, weight: .regular)
        hintLabel.textColor = .secondaryLabel
        hintLabel.numberOfLines = 0
        hintLabel.text = LMText.settings.modelsIdeaInspirationHint

        providerTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        providerTitleLabel.textColor = .secondaryLabel
        providerTitleLabel.text = LMText.settings.modelsProvider
        providerValueLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        providerValueLabel.textColor = .label
        providerValueLabel.text = LMText.settings.modelsProviderGemini

        modelTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        modelTitleLabel.textColor = .secondaryLabel
        modelTitleLabel.text = LMText.settings.modelsModel
        modelSegment.removeAllSegments()
        modelSegment.insertSegment(withTitle: LMText.settings.gemini31FlashImage, at: 0, animated: false)
        modelSegment.insertSegment(withTitle: LMText.settings.gemini3ProImage, at: 1, animated: false)
        modelSegment.selectedSegmentIndex = 0
        modelSegment.addTarget(self, action: #selector(handleModelChanged), for: .valueChanged)

        baseURLField.configureInputFieldProperties(
            title: LMText.settings.modelsBaseURL,
            placeholder: AppConfigs.Gemini.defaultBaseURL,
            isSecure: false,
            keyboardType: .URL
        )
        baseURLField.maximumTextLength = 256
        apiKeyField.configureInputFieldProperties(
            title: LMText.settings.modelsAPIKey,
            placeholder: LMText.settings.modelsAPIKeyPlaceholder,
            isSecure: true,
            keyboardType: .default
        )
        apiKeyField.maximumTextLength = 256

        [
            hintLabel, providerTitleLabel, providerValueLabel,
            modelTitleLabel, modelSegment, baseURLField, apiKeyField
        ].forEach { card.addSubview($0) }

        saveButton.setTitle(LMText.common.save, for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.layer.cornerRadius = 14
        saveButton.addTarget(self, action: #selector(handleSave), for: .touchUpInside)

        restoreButton.setTitle(LMText.settings.modelsRestoreDefaults, for: .normal)
        restoreButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        restoreButton.setTitleColor(.systemRed, for: .normal)
        restoreButton.addTarget(self, action: #selector(handleRestore), for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(endEditing))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    func configureLayout() {
        scrollView.snp.makeConstraints { $0.edges.equalTo(view.safeAreaLayoutGuide) }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }
        card.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        hintLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        providerTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        providerValueLabel.snp.makeConstraints { make in
            make.top.equalTo(providerTitleLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        modelTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(providerValueLabel.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        modelSegment.snp.makeConstraints { make in
            make.top.equalTo(modelTitleLabel.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        baseURLField.snp.makeConstraints { make in
            make.top.equalTo(modelSegment.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        apiKeyField.snp.makeConstraints { make in
            make.top.equalTo(baseURLField.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(16)
        }
        saveButton.snp.makeConstraints { make in
            make.top.equalTo(card.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(50)
        }
        restoreButton.snp.makeConstraints { make in
            make.top.equalTo(saveButton.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview().offset(-24)
        }
    }

    func loadSettings() {
        let settings = LMLlmModuleSettingsStore.loadIdeaInspiration()
        baseURLField.text = settings.baseURL
        apiKeyField.text = settings.apiKey
        selectedModel = settings.model
        modelSegment.selectedSegmentIndex = settings.model == .flash31 ? 0 : 1
    }

    @objc func handleModelChanged() {
        selectedModel = modelSegment.selectedSegmentIndex == 0 ? .flash31 : .pro3
    }

    @objc func endEditing() {
        view.endEditing(true)
    }

    @objc func handleSave() {
        view.endEditing(true)
        if let error = LMLlmModuleSettingsStore.validateIdeaInspiration(
            baseURL: baseURLField.text ?? "",
            apiKey: apiKeyField.text ?? "",
            model: selectedModel
        ) {
            AppTheme.Toast.showText(error)
            return
        }
        LMLlmModuleSettingsStore.saveIdeaInspiration(
            LMIdeaInspirationSettings(
                baseURL: baseURLField.text ?? "",
                apiKey: apiKeyField.text ?? "",
                model: selectedModel
            )
        )
        AppTheme.Toast.showText(LMText.settings.modelsSaved, position: .top)
    }

    @objc func handleRestore() {
        LMLlmModuleSettingsStore.restoreDefaults(.ideaInspiration)
        loadSettings()
        AppTheme.Toast.showText(
            String(format: LMText.settings.modelsResetToDefaultFormat, LMText.settings.modelsSectionIdeaInspiration),
            position: .top
        )
    }
}
