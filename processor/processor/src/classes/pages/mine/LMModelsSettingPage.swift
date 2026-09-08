//
//  LMModelsSettingPage.swift
//  processor
//
//  Mine → Setting → Models overview — three module rows (no global thinking switch).
//

import UIKit
import SnapKit

/// Models overview: Scene Explore / Idea Inspiration / AR Guidance.
final class LMModelsSettingPage: LMPageWrapper {

    override var usesMineNavigationBarStyle: Bool { true }

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.models
        setupUI()
        configureLayout()
        reloadRows()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadRows()
    }
}

// MARK: - Setup
private extension LMModelsSettingPage {

    func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stack)

        stack.axis = .vertical
        stack.spacing = 12
    }

    func configureLayout() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }
        stack.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().offset(-24)
        }
    }

    func reloadRows() {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let modules: [(LMLlmFeatureModule, String, String)] = [
            (.sceneExplore, LMText.settings.modelsSectionSceneExplore, LMText.settings.modelsProtocolOpenAICompatible),
            (.ideaInspiration, LMText.settings.modelsSectionIdeaInspiration, LMText.settings.modelsProtocolGemini),
            (.arGuidance, LMText.settings.modelsSectionARGuidance, LMText.settings.modelsProtocolOpenAICompatible)
        ]

        for (module, title, protocolSubtitle) in modules {
            let row = makeModuleRow(module: module, title: title, protocolSubtitle: protocolSubtitle)
            stack.addArrangedSubview(row)
        }
    }

    func makeModuleRow(module: LMLlmFeatureModule, title: String, protocolSubtitle: String) -> UIView {
        let card = UIControl()
        card.backgroundColor = UIColor.secondarySystemGroupedBackground
        card.layer.cornerRadius = 14
        card.accessibilityIdentifier = module.rawValue
        card.addTarget(self, action: #selector(handleModuleTapped(_:)), for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.text = title

        let subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 2
        subtitleLabel.text = protocolSubtitle

        let statusLabel = UILabel()
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.numberOfLines = 2
        if LMLlmModuleSettingsStore.isConfigured(module) {
            let modelId: String
            switch module {
            case .sceneExplore:
                modelId = LMLlmModuleSettingsStore.loadSceneExplore().modelName
            case .arGuidance:
                modelId = LMLlmModuleSettingsStore.loadARGuidance().modelName
            case .ideaInspiration:
                modelId = LMLlmModuleSettingsStore.loadIdeaInspiration().modelName
            }
            statusLabel.textColor = .systemGreen
            statusLabel.text = "\(LMText.settings.modelsConfigured) · \(modelId)"
        } else {
            statusLabel.textColor = .systemOrange
            statusLabel.text = LMText.settings.modelsNotConfigured
        }

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = .tertiaryLabel
        chevron.contentMode = .scaleAspectFit

        [titleLabel, subtitleLabel, statusLabel, chevron].forEach { card.addSubview($0) }

        titleLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16)
            make.trailing.equalTo(chevron.snp.leading).offset(-8)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
        }
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(8)
            make.leading.equalTo(titleLabel)
            make.trailing.equalTo(titleLabel)
            make.bottom.equalToSuperview().inset(16)
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(14)
        }

        return card
    }

    @objc func handleModuleTapped(_ sender: UIControl) {
        guard let raw = sender.accessibilityIdentifier,
              let module = LMLlmFeatureModule(rawValue: raw) else { return }
        pushModulePage(module)
    }

    func pushModulePage(_ module: LMLlmFeatureModule) {
        let page: LMPageWrapper
        switch module {
        case .sceneExplore:
            page = LMChatModuleSettingPage(module: .sceneExplore)
        case .arGuidance:
            page = LMChatModuleSettingPage(module: .arGuidance)
        case .ideaInspiration:
            page = LMIdeaInspirationSettingPage()
        }
        navigationController?.pushViewController(page, animated: true)
    }
}

extension LMModelsSettingPage {
    /// Opens a specific Models sub-page (missing-config deep link).
    static func makeSubPage(for module: LMLlmFeatureModule) -> LMPageWrapper {
        switch module {
        case .sceneExplore: return LMChatModuleSettingPage(module: .sceneExplore)
        case .arGuidance: return LMChatModuleSettingPage(module: .arGuidance)
        case .ideaInspiration: return LMIdeaInspirationSettingPage()
        }
    }
}
