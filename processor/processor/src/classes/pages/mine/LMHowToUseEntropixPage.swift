//
//  LMHowToUseEntropixPage.swift
//  processor
//
//  Static Settings subpage: Journey tutorial content (Find Spot → Templates → Coaching).
//

import UIKit
import SnapKit

/// Settings → How to use Entropix — scrollable Journey steps (no camera popup).
class LMHowToUseEntropixPage: LMPageWrapper {

    override var usesMineNavigationBarStyle: Bool { true }

    // MARK: - UI

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let introLabel = UILabel()
    private let stepsStackView = UIStackView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.settings.howToUseEntropix
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        rebuildStepSections()

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
        barTitle = LMText.settings.howToUseEntropix
        introLabel.text = LMText.settings.howToUseEntropixIntro
        rebuildStepSections()
    }
}

// MARK: - Setup

extension LMHowToUseEntropixPage {

    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(introLabel)
        contentView.addSubview(stepsStackView)

        introLabel.text = LMText.settings.howToUseEntropixIntro
        introLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        introLabel.textColor = UIColor.secondaryLabel
        introLabel.numberOfLines = 0
        introLabel.textAlignment = .left

        stepsStackView.axis = .vertical
        stepsStackView.spacing = 24
        stepsStackView.alignment = .fill
        stepsStackView.distribution = .fill
    }

    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }

        introLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }

        stepsStackView.snp.makeConstraints { make in
            make.top.equalTo(introLabel.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-32)
        }
    }

    private func configureDefaultContentAndStyles() {
        view.backgroundColor = .systemGroupedBackground
        scrollView.backgroundColor = .systemGroupedBackground
        scrollView.showsVerticalScrollIndicator = true
        contentView.backgroundColor = .clear
    }

    /// Rebuilds step sections from `LMCameraJourneyStep` (titles, bodies, assets).
    private func rebuildStepSections() {
        stepsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for step in LMCameraJourneyStep.allCases {
            stepsStackView.addArrangedSubview(makeStepSection(for: step))
        }
    }

    /**
     Builds one Journey step block: badge + title + body + screenshot.
     - Parameter step: Journey step from the camera tutorial deck.
     - Returns: Configured container view.
     */
    private func makeStepSection(for step: LMCameraJourneyStep) -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 16
        container.clipsToBounds = true

        let badge = UILabel()
        badge.text = "\(step.index)"
        badge.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = .hexColor("#4F46E5")
        badge.layer.cornerRadius = 12
        badge.clipsToBounds = true

        let titleLabel = UILabel()
        titleLabel.text = step.title
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        let bodyLabel = UILabel()
        bodyLabel.text = step.description
        bodyLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.numberOfLines = 0

        let imageView = UIImageView()
        imageView.image = UIImage(named: step.assetName)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.layer.borderWidth = 1 / UIScreen.main.scale
        imageView.layer.borderColor = UIColor.separator.cgColor
        imageView.accessibilityLabel = step.title
        imageView.isAccessibilityElement = true

        container.addSubview(badge)
        container.addSubview(titleLabel)
        container.addSubview(bodyLabel)
        container.addSubview(imageView)

        badge.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().inset(16)
            make.width.height.equalTo(24)
        }

        titleLabel.snp.makeConstraints { make in
            make.centerY.equalTo(badge)
            make.leading.equalTo(badge.snp.trailing).offset(10)
            make.trailing.equalToSuperview().inset(16)
        }

        bodyLabel.snp.makeConstraints { make in
            make.top.equalTo(badge.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(16)
        }

        imageView.snp.makeConstraints { make in
            make.top.equalTo(bodyLabel.snp.bottom).offset(14)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(16)
            make.height.equalTo(imageView.snp.width).multipliedBy(1.55)
        }

        return container
    }
}
