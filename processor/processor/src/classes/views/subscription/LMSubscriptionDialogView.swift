//
//  LMSubscriptionDialogView.swift
//  processor
//
//  Created by muz on 2025/11/8.
//

import UIKit
import SnapKit

protocol LMSubscriptionDialogViewDelegate: AnyObject {
    func dialogViewDidTapCancel(_ view: LMSubscriptionDialogView)
    func dialogViewDidTapConfirm(_ view: LMSubscriptionDialogView)
}

class LMSubscriptionDialogView: UIView {
    
    // MARK: - UI Components
    private let dialogOverlay = UIView()
    private let dialogContainer = UIView()
    private let dialogTitleLabel = UILabel()
    private let dialogMessageLabel = UILabel()
    private let dialogCancelButton = UIButton()
    private let dialogConfirmButton = UIButton()
    
    // MARK: - Properties
    weak var delegate: LMSubscriptionDialogViewDelegate?
    var isVisible: Bool = false
    
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
        addSubview(dialogOverlay)
        dialogOverlay.addSubview(dialogContainer)
        dialogContainer.addSubview(dialogTitleLabel)
        dialogContainer.addSubview(dialogMessageLabel)
        dialogContainer.addSubview(dialogCancelButton)
        dialogContainer.addSubview(dialogConfirmButton)
        
        dialogOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        dialogOverlay.isHidden = true
        dialogOverlay.alpha = 0
        
        dialogContainer.backgroundColor = .white
        dialogContainer.layer.cornerRadius = 16
        
        dialogTitleLabel.text = "Give up Free Trial?"
        dialogTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        dialogTitleLabel.textColor = UIColor.hexColor("#333333")
        dialogTitleLabel.textAlignment = .center
        
        dialogMessageLabel.text = "When you switch to free plan, you give up this free trial opportunity. You will not be able to get free trial again until a new offer is provided."
        dialogMessageLabel.font = UIFont.systemFont(ofSize: 14)
        dialogMessageLabel.textColor = UIColor.hexColor("#666666")
        dialogMessageLabel.textAlignment = .center
        dialogMessageLabel.numberOfLines = 0
        
        dialogCancelButton.setTitle("Cancel", for: .normal)
        dialogCancelButton.setTitleColor(UIColor.hexColor("#333333"), for: .normal)
        dialogCancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        dialogCancelButton.backgroundColor = UIColor.hexColor("#f0f0f0")
        dialogCancelButton.layer.cornerRadius = 12
        dialogCancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        
        dialogConfirmButton.setTitle("Give up", for: .normal)
        dialogConfirmButton.setTitleColor(.white, for: .normal)
        dialogConfirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        dialogConfirmButton.backgroundColor = UIColor.hexColor("#ef4444")
        dialogConfirmButton.layer.cornerRadius = 12
        dialogConfirmButton.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
    }
    
    private func setupLayout() {
        dialogOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        dialogContainer.snp.makeConstraints { make in
            make.centerX.centerY.equalToSuperview()
            make.width.equalTo(350)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        dialogTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(24)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        dialogMessageLabel.snp.makeConstraints { make in
            make.top.equalTo(dialogTitleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(24)
        }
        
        dialogCancelButton.snp.makeConstraints { make in
            make.top.equalTo(dialogMessageLabel.snp.bottom).offset(24)
            make.leading.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-24)
            make.height.equalTo(44)
            make.trailing.equalTo(dialogContainer.snp.centerX).offset(-7.5)
        }
        
        dialogConfirmButton.snp.makeConstraints { make in
            make.top.equalTo(dialogMessageLabel.snp.bottom).offset(24)
            make.leading.equalTo(dialogContainer.snp.centerX).offset(7.5)
            make.trailing.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-24)
            make.height.equalTo(44)
        }
    }
    
    // MARK: - Actions
    @objc private func handleCancel() {
        delegate?.dialogViewDidTapCancel(self)
    }
    
    @objc private func handleConfirm() {
        delegate?.dialogViewDidTapConfirm(self)
    }
    
    // MARK: - Public Methods
    func show() {
        isVisible = true
        dialogOverlay.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.dialogOverlay.alpha = 1.0
        }
    }
    
    func hide() {
        isVisible = false
        UIView.animate(withDuration: 0.3, animations: {
            self.dialogOverlay.alpha = 0.0
        }) { _ in
            self.dialogOverlay.isHidden = true
        }
    }
}
