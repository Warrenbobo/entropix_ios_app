//
//  LMProfileInfoTableViewCell.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

protocol LMProfileInfoTableViewCellDelegate: AnyObject {
    func profileInfoCellDidTapAccessoryButton(_ cell: LMProfileInfoTableViewCell, identifier: String)
    func profileInfoCellDidChangeText(_ cell: LMProfileInfoTableViewCell, identifier: String, newText: String)
}

class LMProfileInfoTableViewCell: UITableViewCell {
    
    // MARK: - UI Components
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let accessoryButton = UIButton()
    private let textField = UITextField()
    private let disclosureImageView = UIImageView()
    
    // MARK: - Properties
    weak var delegate: LMProfileInfoTableViewCellDelegate?
    private var itemIdentifier: String = ""
    private var isEditingMode = false
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCellComponents()
        configureLayoutConstraints()
        configureDefaultStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        resetCellState()
    }
}

// MARK: - Cell Setup Methods
extension LMProfileInfoTableViewCell {
    
    private func setupCellComponents() {
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(textField)
        contentView.addSubview(accessoryButton)
        contentView.addSubview(disclosureImageView)
        
        setupTitleLabel()
        setupValueLabel()
        setupTextField()
        setupAccessoryButton()
        setupDisclosureImageView()
    }
    
    private func setupTitleLabel() {
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor.secondaryLabel
        titleLabel.numberOfLines = 1
    }
    
    private func setupValueLabel() {
        valueLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        valueLabel.textColor = UIColor.label
        valueLabel.numberOfLines = 1
        valueLabel.textAlignment = .right
    }
    
    private func setupTextField() {
        textField.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        textField.textColor = UIColor.label
        textField.textAlignment = .right
        textField.borderStyle = .none
        textField.isHidden = true
        textField.returnKeyType = .done
        textField.delegate = self
        textField.addTarget(self, action: #selector(handleTextFieldEditingChanged), for: .editingChanged)
    }
    
    private func setupAccessoryButton() {
        accessoryButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        accessoryButton.isHidden = true
        accessoryButton.addTarget(self, action: #selector(handleAccessoryButtonTapped), for: .touchUpInside)
    }
    
    private func setupDisclosureImageView() {
        disclosureImageView.image = UIImage(systemName: "chevron.right")
        disclosureImageView.tintColor = UIColor.systemGray3
        disclosureImageView.contentMode = .scaleAspectFit
        disclosureImageView.isHidden = true
    }
}

// MARK: - Layout Configuration Methods
extension LMProfileInfoTableViewCell {
    
    private func configureLayoutConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.lessThanOrEqualTo(120)
        }
        
        valueLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(16)
        }
        
        textField.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(16)
            make.height.equalTo(40)
        }
        
        accessoryButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(16)
        }
        
        disclosureImageView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalToSuperview()
            make.size.equalTo(16)
        }
    }
}

// MARK: - Content Configuration Methods
extension LMProfileInfoTableViewCell {
    
    private func configureDefaultStyles() {
        backgroundColor = UIColor.systemBackground
        selectionStyle = .none
    }
    
    private func resetCellState() {
        titleLabel.text = ""
        valueLabel.text = ""
        textField.text = ""
        accessoryButton.setTitle("", for: .normal)
        
        valueLabel.isHidden = false
        textField.isHidden = true
        accessoryButton.isHidden = true
        disclosureImageView.isHidden = true
        
        isEditingMode = false
        itemIdentifier = ""
    }
    
    func configureCell(with item: LMProfileInfoItem) {
        itemIdentifier = item.identifier
        titleLabel.text = item.title
        
        // 重置所有accessory视图
        valueLabel.isHidden = true
        textField.isHidden = true
        accessoryButton.isHidden = true
        disclosureImageView.isHidden = true
        
        // 根据accessoryType配置相应的视图
        switch item.accessoryType {
        case .none:
            valueLabel.text = item.value
            valueLabel.isHidden = false
            
        case .disclosure:
            valueLabel.text = item.value
            valueLabel.isHidden = false
            disclosureImageView.isHidden = false
            
            // 调整valueLabel约束以为disclosure图标留出空间
            valueLabel.snp.updateConstraints { make in
                make.trailing.equalTo(disclosureImageView.snp.leading).offset(-8)
            }
            
        case .button(let title, let color):
            accessoryButton.setTitle(title, for: .normal)
            accessoryButton.setTitleColor(color, for: .normal)
            accessoryButton.isHidden = false
            
        case .editableText:
            if isEditingMode {
                textField.text = item.value
                textField.isHidden = false
            } else {
                valueLabel.text = item.value
                valueLabel.isHidden = false
            }
        }
    }
    
    func enterEditingMode() {
        guard !isEditingMode else { return }
        
        isEditingMode = true
        
        // 切换到编辑模式
        valueLabel.isHidden = true
        textField.isHidden = false
        textField.text = valueLabel.text
        textField.becomeFirstResponder()
    }
    
    func exitEditingMode() {
        guard isEditingMode else { return }
        
        isEditingMode = false
        
        // 退出编辑模式
        textField.resignFirstResponder()
        textField.isHidden = true
        valueLabel.isHidden = false
        valueLabel.text = textField.text
        
        // 通知代理文本已更改
        if let newText = textField.text {
            delegate?.profileInfoCellDidChangeText(self, identifier: itemIdentifier, newText: newText)
        }
    }
}

// MARK: - User Interaction Handler Methods
extension LMProfileInfoTableViewCell {
    
    @objc private func handleAccessoryButtonTapped() {
        delegate?.profileInfoCellDidTapAccessoryButton(self, identifier: itemIdentifier)
    }
    
    @objc private func handleTextFieldEditingChanged() {
        // 实时更新，可以在这里添加验证逻辑
    }
}

// MARK: - Text Field Delegate Methods
extension LMProfileInfoTableViewCell: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        exitEditingMode()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        exitEditingMode()
    }
}

// MARK: - Public Methods
extension LMProfileInfoTableViewCell {
    
    func getCurrentValue() -> String {
        return isEditingMode ? (textField.text ?? "") : (valueLabel.text ?? "")
    }
    
    func updateValue(_ newValue: String) {
        if isEditingMode {
            textField.text = newValue
        } else {
            valueLabel.text = newValue
        }
    }
}