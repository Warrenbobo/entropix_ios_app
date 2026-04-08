//
//  LMProcessorTopBar.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

enum LMProfileNavigationMetrics {
    static let horizontalInset: CGFloat = 20
    static let buttonSize: CGFloat = 44
    static let titleLeadingWithoutBack: CGFloat = 20
    static let titleLeadingWithBack: CGFloat = 56
    static let backButtonLeadingCompensation: CGFloat = 4
    static let backButtonImageInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 24)
    static let moreButtonImageInsets = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 0)
    static let titleFont = UIFont.systemFont(ofSize: 24, weight: .bold)
    static let titleColor = UIColor.label
    
    static var titleItemWidth: CGFloat {
        max(220, AppTheme.Screen.width - 96)
    }
}

class LMProcessorTopBar: UIView {
    
    var title: String = "" {
        didSet {
            titleLabel.text = title
        }
    }
    
    var moreButtonAction: (() -> Void)?
    var backButtonAction: (() -> Void)?
    
    private let backgroundView = UIView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .custom)
    private let moreButton = UIButton(type: .custom)
    private var titleLeadingConstraint: Constraint?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupProcessorTopBarViews()
        setupContentConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupProcessorTopBarViews() {
        backgroundColor = UIColor.clear
        addSubview(backgroundView)
        backgroundView.backgroundColor = UIColor.systemBackground
        
        backgroundView.addSubview(contentView)
        
        contentView.addSubview(titleLabel)
        titleLabel.font = LMProfileNavigationMetrics.titleFont
        titleLabel.textColor = LMProfileNavigationMetrics.titleColor
        titleLabel.textAlignment = .left

        contentView.addSubview(backButton)
        backButton.setImage(UIImage(named: "left_arrow_dark"), for: .normal)
        backButton.tintColor = LMProfileNavigationMetrics.titleColor
        backButton.backgroundColor = .clear
        backButton.adjustsImageWhenHighlighted = false
        backButton.contentHorizontalAlignment = .leading
        backButton.contentVerticalAlignment = .center
        backButton.imageView?.contentMode = .scaleAspectFit
        backButton.imageEdgeInsets = LMProfileNavigationMetrics.backButtonImageInsets
        backButton.isHidden = true
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)

        contentView.addSubview(moreButton)
        moreButton.setImage(UIImage(named: "more_option"), for: .normal)
        moreButton.backgroundColor = .clear
        moreButton.adjustsImageWhenHighlighted = false
        moreButton.contentHorizontalAlignment = .trailing
        moreButton.contentVerticalAlignment = .center
        moreButton.imageView?.contentMode = .scaleAspectFit
        moreButton.imageEdgeInsets = LMProfileNavigationMetrics.moreButtonImageInsets
        moreButton.addTarget(self, action: #selector(moreButtonTapped), for: .touchUpInside)
    }
    
    private func setupContentConstraints() {
        
        backgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        contentView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(AppTheme.Screen.safeAreaTop)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(44)
            make.bottom.equalToSuperview()
        }
        backButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(LMProfileNavigationMetrics.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(LMProfileNavigationMetrics.buttonSize)
        }
        titleLabel.snp.makeConstraints { make in
            titleLeadingConstraint = make.leading.equalToSuperview().offset(LMProfileNavigationMetrics.titleLeadingWithoutBack).constraint
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(moreButton.snp.leading).offset(-16)
        }
        moreButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-LMProfileNavigationMetrics.horizontalInset)
            make.centerY.equalToSuperview()
            make.size.equalTo(LMProfileNavigationMetrics.buttonSize)
        }
    }
    
    @objc private func moreButtonTapped() {
        moreButtonAction?()
    }

    @objc private func backButtonTapped() {
        backButtonAction?()
    }
    
    func setTitle(_ title: String) {
        self.title = title
    }
    
    func setMoreButtonAction(_ action: @escaping () -> Void) {
        self.moreButtonAction = action
    }
    
    func setTrailingButtonAction(_ action: @escaping () -> Void) {
        setMoreButtonAction(action)
    }

    func setBackButtonAction(_ action: @escaping () -> Void) {
        self.backButtonAction = action
    }

    func setBackButtonHidden(_ hidden: Bool) {
        backButton.isHidden = hidden
        titleLeadingConstraint?.update(
            offset: hidden ? LMProfileNavigationMetrics.titleLeadingWithoutBack : LMProfileNavigationMetrics.titleLeadingWithBack
        )
    }

    func setMoreButtonHidden(_ hidden: Bool) {
        moreButton.isHidden = hidden
    }
    
    func setTrailingButtonHidden(_ hidden: Bool) {
        setMoreButtonHidden(hidden)
    }
    
    func setTrailingButtonEnabled(_ enabled: Bool) {
        moreButton.isEnabled = enabled
        moreButton.isUserInteractionEnabled = enabled
        moreButton.alpha = enabled ? 1.0 : 0.5
    }
    
    func setBackgroundColor(_ color: UIColor) {
        backgroundView.backgroundColor = color
    }
    
    func setTitleColor(_ color: UIColor) {
        titleLabel.textColor = color
    }
    
    func setMoreButtonTintColor(_ color: UIColor) {
        moreButton.tintColor = color
    }
    
    func setTrailingButtonTitle(_ title: String?) {
        moreButton.setTitle(title, for: .normal)
        if title?.isEmpty == false {
            moreButton.setImage(nil, for: .normal)
            moreButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            moreButton.setTitleColor(AppTheme.ThemeColor.buttonText, for: .normal)
            moreButton.contentHorizontalAlignment = .trailing
        }
    }
    
    func setTrailingButtonTitleColor(_ color: UIColor) {
        moreButton.setTitleColor(color, for: .normal)
    }
    
    func setTrailingButtonFont(_ font: UIFont) {
        moreButton.titleLabel?.font = font
    }
    
    func setTrailingButtonImage(_ image: UIImage?) {
        moreButton.setTitle(nil, for: .normal)
        moreButton.setImage(image, for: .normal)
        moreButton.contentHorizontalAlignment = .trailing
        moreButton.imageEdgeInsets = LMProfileNavigationMetrics.moreButtonImageInsets
    }
}
