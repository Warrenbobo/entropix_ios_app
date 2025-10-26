//
//  LMProcessorTopBar.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit

class LMProcessorTopBar: UIView {
    
    var title: String = "" {
        didSet {
            titleLabel.text = title
        }
    }
    
    var moreButtonAction: (() -> Void)?
    
    private let backgroundView = UIView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let moreButton = UIButton()
    
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
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = UIColor.label
        titleLabel.textAlignment = .left
        
        contentView.addSubview(moreButton)
        moreButton.setImage(UIImage(named: "more_option"), for: .normal)
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
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(moreButton.snp.leading).offset(-16)
        }
        moreButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
    }
    
    @objc private func moreButtonTapped() {
        moreButtonAction?()
    }
    
    func setTitle(_ title: String) {
        self.title = title
    }
    
    func setMoreButtonAction(_ action: @escaping () -> Void) {
        self.moreButtonAction = action
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
}
