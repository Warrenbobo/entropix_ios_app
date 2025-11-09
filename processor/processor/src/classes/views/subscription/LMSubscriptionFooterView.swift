//
//  LMSubscriptionFooterView.swift
//  processor
//
//  Created by muz on 2025/11/8.
//

import UIKit
import SnapKit

protocol LMSubscriptionFooterViewDelegate: AnyObject {
    func footerViewDidTapTerms(_ view: LMSubscriptionFooterView)
    func footerViewDidTapPrivacy(_ view: LMSubscriptionFooterView)
}

class LMSubscriptionFooterView: UIView {
    
    // MARK: - UI Components
    private let footerLabel = UILabel()
    private let footerLinksStackView = UIStackView()
    private let termsButton = UIButton()
    private let privacyButton = UIButton()
    
    // MARK: - Properties
    weak var delegate: LMSubscriptionFooterViewDelegate?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        addSubview(footerLabel)
        addSubview(footerLinksStackView)
        
        footerLabel.text = LMText.subscription.autoRenewNotice
        footerLabel.font = UIFont.systemFont(ofSize: 12)
        footerLabel.textColor = UIColor.hexColor("#6b7280")
        footerLabel.textAlignment = .center
        footerLabel.numberOfLines = 0
        
        termsButton.setTitle(LMText.subscription.termsOfService, for: .normal)
        termsButton.setTitleColor(UIColor.hexColor("#2563eb"), for: .normal)
        termsButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        termsButton.addTarget(self, action: #selector(handleTerms), for: .touchUpInside)
        
        privacyButton.setTitle(LMText.subscription.privacyPolicy, for: .normal)
        privacyButton.setTitleColor(UIColor.hexColor("#2563eb"), for: .normal)
        privacyButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        privacyButton.addTarget(self, action: #selector(handlePrivacy), for: .touchUpInside)
        
        footerLinksStackView.axis = .horizontal
        footerLinksStackView.spacing = 16
        footerLinksStackView.distribution = .fill
        footerLinksStackView.addArrangedSubview(termsButton)
        footerLinksStackView.addArrangedSubview(privacyButton)
    }
    
    private func setupLayout() {
        footerLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        
        footerLinksStackView.snp.makeConstraints { make in
            make.top.equalTo(footerLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    // MARK: - Actions
    @objc private func handleTerms() {
        delegate?.footerViewDidTapTerms(self)
    }
    
    @objc private func handlePrivacy() {
        delegate?.footerViewDidTapPrivacy(self)
    }
}
