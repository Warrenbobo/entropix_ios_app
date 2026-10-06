//
//  LMLegalReagreeView.swift
//  processor
//
//  Blocking re-agree sheet for Terms / Privacy (ios-legal-reagree-spec.md).
//

import UIKit
import SnapKit

protocol LMLegalReagreeViewDelegate: AnyObject {
    func legalReagreeViewDidAgree(_ view: LMLegalReagreeView)
    func legalReagreeViewDidReject(_ view: LMLegalReagreeView)
    func legalReagreeViewDidTapPrivacyPolicy(_ view: LMLegalReagreeView)
    func legalReagreeViewDidTapTermsOfService(_ view: LMLegalReagreeView)
}

/// Bottom-sheet style gate mirroring `LMPrivacyPermissionView`.
final class LMLegalReagreeView: UIView {

    weak var delegate: LMLegalReagreeViewDelegate?

    private let backgroundOverlay = UIView()
    private let contentContainer = UIView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let linksTextView = UITextView()
    private let agreeButton = UIButton(type: .system)
    private let rejectButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /**
     Configures title/body for which document(s) are pending.
     */
    func apply(pending: LMLegalReagreePendingDocs) {
        titleLabel.text = LMText.entrance.legalReagreeTitle
        switch pending {
        case .termsOnly:
            descriptionLabel.text = LMText.entrance.legalReagreeBodyTermsOnly
        case .privacyOnly:
            descriptionLabel.text = LMText.entrance.legalReagreeBodyPrivacyOnly
        case .both, .none:
            descriptionLabel.text = LMText.entrance.legalReagreeBodyBoth
        }
        setupLinksTextView()
    }

    private func setupUI() {
        backgroundOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        addSubview(backgroundOverlay)

        contentContainer.backgroundColor = .white
        contentContainer.layer.cornerRadius = 20
        contentContainer.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentContainer.clipsToBounds = true
        addSubview(contentContainer)

        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        contentContainer.addSubview(titleLabel)

        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .left
        contentContainer.addSubview(descriptionLabel)

        contentContainer.addSubview(linksTextView)

        agreeButton.setTitle(LMText.entrance.agree, for: .normal)
        agreeButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        agreeButton.setTitleColor(.white, for: .normal)
        agreeButton.backgroundColor = UIColor.systemBlue
        agreeButton.layer.cornerRadius = 25
        agreeButton.addTarget(self, action: #selector(agreeButtonTapped), for: .touchUpInside)
        contentContainer.addSubview(agreeButton)

        rejectButton.setTitle(LMText.entrance.rejectAndExit, for: .normal)
        rejectButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        rejectButton.setTitleColor(.secondaryLabel, for: .normal)
        rejectButton.backgroundColor = .clear
        rejectButton.addTarget(self, action: #selector(rejectButtonTapped), for: .touchUpInside)
        contentContainer.addSubview(rejectButton)
    }

    private func setupLinksTextView() {
        linksTextView.isEditable = false
        linksTextView.isScrollEnabled = false
        linksTextView.backgroundColor = .clear
        linksTextView.textContainerInset = .zero
        linksTextView.textContainer.lineFragmentPadding = 0

        let fullText = LMText.entrance.viewPrivacyAndTerms
        let attributedString = NSMutableAttributedString(string: fullText)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 5
        paragraphStyle.alignment = .left

        attributedString.addAttributes([
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraphStyle
        ], range: NSRange(location: 0, length: (fullText as NSString).length))

        highlightLink(in: attributedString, fullText: fullText, candidates: [
            "Privacy Policy", "隐私政策", "隱私政策"
        ], link: "privacy://")
        highlightLink(in: attributedString, fullText: fullText, candidates: [
            "Terms of Service", "Terms of Use", "服务条款", "服務條款"
        ], link: "terms://")

        linksTextView.attributedText = attributedString
        linksTextView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        linksTextView.delegate = self
    }

    private func highlightLink(
        in attributedString: NSMutableAttributedString,
        fullText: String,
        candidates: [String],
        link: String
    ) {
        for candidate in candidates {
            if let range = fullText.range(of: candidate) {
                let nsRange = NSRange(range, in: fullText)
                attributedString.addAttributes([
                    .foregroundColor: UIColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .link: link
                ], range: nsRange)
                return
            }
        }
    }

    private func setupConstraints() {
        backgroundOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(contentContainer).offset(30)
            make.leading.trailing.equalTo(contentContainer).inset(24)
        }
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.leading.trailing.equalTo(contentContainer).inset(24)
        }
        linksTextView.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(16)
            make.leading.trailing.equalTo(contentContainer).inset(24)
        }
        agreeButton.snp.makeConstraints { make in
            make.top.equalTo(linksTextView.snp.bottom).offset(36)
            make.leading.trailing.equalTo(contentContainer).inset(24)
            make.height.equalTo(50)
        }
        rejectButton.snp.makeConstraints { make in
            make.top.equalTo(agreeButton.snp.bottom).offset(12)
            make.centerX.equalTo(contentContainer)
            make.height.equalTo(30)
            make.bottom.equalTo(contentContainer.safeAreaLayoutGuide).offset(-20)
        }
        contentContainer.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
    }

    @objc private func agreeButtonTapped() {
        delegate?.legalReagreeViewDidAgree(self)
    }

    @objc private func rejectButtonTapped() {
        delegate?.legalReagreeViewDidReject(self)
    }

    func show(in parentView: UIView, animated: Bool = true) {
        parentView.addSubview(self)
        snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        if animated {
            alpha = 0
            contentContainer.transform = CGAffineTransform(translationX: 0, y: 300)
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                self.alpha = 1
                self.contentContainer.transform = .identity
            }
        }
    }

    func hide(animated: Bool = true, completion: (() -> Void)? = nil) {
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
                self.alpha = 0
                self.contentContainer.transform = CGAffineTransform(translationX: 0, y: 300)
            } completion: { _ in
                self.removeFromSuperview()
                completion?()
            }
        } else {
            removeFromSuperview()
            completion?()
        }
    }
}

extension LMLegalReagreeView: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        if URL.scheme == "privacy" {
            delegate?.legalReagreeViewDidTapPrivacyPolicy(self)
            return false
        }
        if URL.scheme == "terms" {
            delegate?.legalReagreeViewDidTapTermsOfService(self)
            return false
        }
        return true
    }
}
