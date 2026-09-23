//
//  LMChatModuleSettingPage.swift
//  processor
//
//  Models sub-page for Scene Explore / AR Guidance (OpenAI-compatible).
//

import UIKit
import SnapKit

/// Per-module chat LLM settings editor (Save + Restore defaults).
final class LMChatModuleSettingPage: LMPageWrapper {

    override var usesMineNavigationBarStyle: Bool { true }

    private let module: LMLlmFeatureModule
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let card = UIView()

    private let hintLabel = UILabel()
    private let baseURLField = LMValidatedInputField()
    private let apiKeyField = LMValidatedInputField()
    private let modelNameField = LMValidatedInputField()

    private let thinkingTitleLabel = UILabel()
    private let thinkingSwitch = UISwitch()
    private let thinkingBudgetField = LMValidatedInputField()
    private let temperatureField = LMValidatedInputField()
    private let maxTokensField = LMValidatedInputField()

    private let saveButton = UIButton(type: .system)
    private let restoreButton = UIButton(type: .system)

    /**
     Creates a chat-module settings page.

     - Parameter module: `.sceneExplore` or `.arGuidance`.
     */
    init(module: LMLlmFeatureModule) {
        self.module = module
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = module == .sceneExplore
            ? LMText.settings.modelsSectionSceneExplore
            : LMText.settings.modelsSectionARGuidance
        setupUI()
        configureLayout()
        loadSettings()
    }
}

private extension LMChatModuleSettingPage {

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
        hintLabel.text = module == .sceneExplore
            ? LMText.settings.modelsSceneExploreHint
            : LMText.settings.modelsARGuidanceHint

        baseURLField.configureInputFieldProperties(
            title: LMText.settings.modelsBaseURL,
            placeholder: "https://…",
            isSecure: false,
            keyboardType: .URL
        )
        baseURLField.maximumTextLength = 256
        apiKeyField.configureInputFieldProperties(
            title: LMText.settings.modelsAPIKey,
            placeholder: "sk-…",
            isSecure: true,
            keyboardType: .default
        )
        apiKeyField.maximumTextLength = 256
        modelNameField.configureInputFieldProperties(
            title: LMText.settings.modelsModelName,
            placeholder: "model-id",
            isSecure: false,
            keyboardType: .default
        )
        modelNameField.maximumTextLength = 128
        thinkingBudgetField.configureInputFieldProperties(
            title: LMText.settings.modelsThinkingBudget,
            placeholder: "512",
            isSecure: false,
            keyboardType: .numberPad
        )
        temperatureField.configureInputFieldProperties(
            title: LMText.settings.modelsTemperature,
            placeholder: "0.7",
            isSecure: false,
            keyboardType: .decimalPad
        )
        maxTokensField.configureInputFieldProperties(
            title: LMText.settings.modelsMaxTokens,
            placeholder: "2048",
            isSecure: false,
            keyboardType: .numberPad
        )

        thinkingTitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        thinkingTitleLabel.textColor = .label
        thinkingTitleLabel.numberOfLines = 0
        thinkingTitleLabel.text = "\(LMText.settings.modelsEnableThinking) \(LMText.settings.modelsEnableThinkingRecommendOff)"
        thinkingSwitch.addTarget(self, action: #selector(handleThinkingChanged), for: .valueChanged)

        [
            hintLabel, baseURLField, apiKeyField, modelNameField,
            thinkingTitleLabel, thinkingSwitch,
            thinkingBudgetField, temperatureField, maxTokensField
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

        var previous: UIView = hintLabel
        hintLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }

        for field in [baseURLField, apiKeyField, modelNameField] as [UIView] {
            field.snp.makeConstraints { make in
                make.top.equalTo(previous.snp.bottom).offset(14)
                make.leading.trailing.equalToSuperview().inset(16)
            }
            previous = field
        }

        thinkingTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(previous.snp.bottom).offset(18)
            make.leading.equalToSuperview().inset(16)
            make.trailing.equalTo(thinkingSwitch.snp.leading).offset(-12)
        }
        thinkingSwitch.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalTo(thinkingTitleLabel)
        }
        previous = thinkingTitleLabel

        for field in [thinkingBudgetField, temperatureField, maxTokensField] as [UIView] {
            field.snp.makeConstraints { make in
                make.top.equalTo(previous.snp.bottom).offset(14)
                make.leading.trailing.equalToSuperview().inset(16)
            }
            previous = field
        }
        previous.snp.makeConstraints { make in
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
        let settings = module == .sceneExplore
            ? LMLlmModuleSettingsStore.loadSceneExplore()
            : LMLlmModuleSettingsStore.loadARGuidance()
        baseURLField.text = settings.baseURL
        apiKeyField.text = settings.apiKey
        modelNameField.text = settings.modelName
        thinkingSwitch.isOn = settings.enableThinking
        thinkingBudgetField.text = "\(settings.thinkingBudget)"
        temperatureField.text = String(format: "%.2f", settings.temperature)
        maxTokensField.text = "\(settings.maxTokens)"
        updateThinkingBudgetVisibility()
    }

    func updateThinkingBudgetVisibility() {
        thinkingBudgetField.alpha = thinkingSwitch.isOn ? 1 : 0.45
        thinkingBudgetField.isUserInteractionEnabled = thinkingSwitch.isOn
    }

    @objc func handleThinkingChanged() {
        updateThinkingBudgetVisibility()
    }

    @objc func endEditing() {
        view.endEditing(true)
    }

    @objc func handleSave() {
        view.endEditing(true)
        let budget = Int(thinkingBudgetField.text ?? "") ?? 512
        let temperature = Double(temperatureField.text ?? "") ?? 0.7
        let maxTokens = Int(maxTokensField.text ?? "") ?? 2048
        if let error = LMLlmModuleSettingsStore.validateChat(
            baseURL: baseURLField.text ?? "",
            apiKey: apiKeyField.text ?? "",
            modelName: modelNameField.text ?? "",
            thinkingBudget: budget,
            temperature: temperature,
            maxTokens: maxTokens
        ) {
            AppTheme.Toast.showText(error)
            return
        }
        let settings = LMChatModuleSettings(
            baseURL: baseURLField.text ?? "",
            apiKey: apiKeyField.text ?? "",
            modelName: modelNameField.text ?? "",
            enableThinking: thinkingSwitch.isOn,
            thinkingBudget: budget,
            temperature: temperature,
            maxTokens: maxTokens
        )
        if module == .sceneExplore {
            LMLlmModuleSettingsStore.saveSceneExplore(settings)
        } else {
            LMLlmModuleSettingsStore.saveARGuidance(settings)
        }
        AppTheme.Toast.showText(LMText.settings.modelsSaved, position: .top)
    }

    @objc func handleRestore() {
        LMLlmModuleSettingsStore.restoreDefaults(module)
        loadSettings()
        let section = module == .sceneExplore
            ? LMText.settings.modelsSectionSceneExplore
            : LMText.settings.modelsSectionARGuidance
        AppTheme.Toast.showText(
            String(format: LMText.settings.modelsResetToDefaultFormat, section),
            position: .top
        )
    }
}
