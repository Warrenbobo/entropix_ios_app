//
//  LMProfileItemView.swift
//  processor
//
//  Created by Kiro on 2025/12/20.
//

import UIKit
import SnapKit

/// Profile 项目类型
enum LMProfileItemType {
    case text       // 普通文本显示
    case button     // 可点击的按钮样式（蓝色带下划线）
}

/// Profile 项目视图代理
protocol LMProfileItemViewDelegate: AnyObject {
    func profileItemViewDidTap(_ itemView: LMProfileItemView)
}

/// Profile 单项视图
class LMProfileItemView: UIView {
    
    // MARK: - Constants
    private enum Constants {
        static let titleLabelWidth: CGFloat = 140
        static let itemHeight: CGFloat = 60
    }
    
    // MARK: - Properties
    weak var delegate: LMProfileItemViewDelegate?
    
    private(set) var itemType: LMProfileItemType = .text
    private(set) var title: String = ""
    private(set) var content: String = ""
    
    // MARK: - UI Components
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let separatorLine = UIView()
    private let tapButton = UIButton(type: .custom)
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        configureConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        configureConstraints()
    }
    
    /// 便捷初始化方法
    convenience init(title: String, content: String = "-", type: LMProfileItemType = .text) {
        self.init(frame: .zero)
        configure(title: title, content: content, type: type)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        // Title label - 左侧灰色标题
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        titleLabel.textColor = UIColor.systemGray
        
        // Content label - 右侧内容
        contentLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        contentLabel.textColor = UIColor.label
        contentLabel.textAlignment = .right
        
        // 底部分割线
        separatorLine.backgroundColor = UIColor.systemGray5
        
        // 点击按钮（覆盖整个视图，用于 button 类型）
        tapButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        tapButton.contentHorizontalAlignment = .right
        tapButton.addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        tapButton.isHidden = true
        
        addSubview(titleLabel)
        addSubview(contentLabel)
        addSubview(separatorLine)
        addSubview(tapButton)
    }
    
    private func configureConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(32)
            make.bottom.equalTo(-20)
            make.width.equalTo(Constants.titleLabelWidth)
        }
        
        contentLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalTo(titleLabel)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }
        
        tapButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalTo(titleLabel)
            make.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(8)
        }
        
        separatorLine.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
    }
    
    // MARK: - Public Methods
    
    /// 配置项目内容
    func configure(title: String, content: String, type: LMProfileItemType = .text) {
        self.title = title
        self.content = content
        self.itemType = type
        
        titleLabel.text = title
        updateContentStyle()
    }
    
    /// 更新内容文本
    func updateContent(_ content: String) {
        self.content = content
        updateContentStyle()
    }
    
    /// 更新类型
    func updateType(_ type: LMProfileItemType) {
        self.itemType = type
        updateContentStyle()
    }
    
    /// 隐藏分割线
    func hiddenLine(_ hidden: Bool) {
        separatorLine.isHidden = hidden
    }
    
    // MARK: - Private Methods
    
    /// 获取显示文本，空或empty时返回"-"
    private var displayContent: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }
    
    private func updateContentStyle() {
        let text = displayContent
        
        switch itemType {
        case .text:
            // 普通文本样式
            contentLabel.text = text
            contentLabel.textColor = UIColor.label
            contentLabel.isHidden = false
            tapButton.isHidden = true
            
        case .button:
            // 按钮样式 - 蓝色带下划线
            let attributedString = NSAttributedString(
                string: text,
                attributes: [
                    .foregroundColor: UIColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .font: UIFont.systemFont(ofSize: 16, weight: .medium)
                ]
            )
            tapButton.setAttributedTitle(attributedString, for: .normal)
            contentLabel.isHidden = true
            tapButton.isHidden = false
        }
    }
    
    // MARK: - Actions
    
    @objc private func handleTap() {
        delegate?.profileItemViewDidTap(self)
    }
}
