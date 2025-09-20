//
//  LMMineUserInfoView.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit

class LMMineUserInfoView: UIView {
    
    var avatarTapAction: (() -> Void)?
    
    func updateUserInfo(name: String, email: String, avatar: UIImage? = nil) {
        nameLabel.text = name
        emailLabel.text = email
        if let avatar = avatar {
            avatarImageView.image = avatar
        }
    }
    
    func setAvatarTapAction(_ action: @escaping () -> Void) {
        self.avatarTapAction = action
    }
    
    func setAvatar(_ image: UIImage) {
        avatarImageView.image = image
    }
    
    // 用户头像
    private let avatarImageView = UIImageView()
    // 用户昵称
    private let nameLabel = UILabel()
    // 用户邮箱
    private let emailLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUserInfoContentViews()
        setupUserViewConstraints()
        configureDefaultContent()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUserInfoContentViews() {
        addSubview(avatarImageView)
        addSubview(nameLabel)
        addSubview(emailLabel)
        
        // 头像设置
        avatarImageView.backgroundColor = UIColor.systemGray4
        avatarImageView.layer.cornerRadius = 30
        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.isUserInteractionEnabled = true
        
        // 添加头像点击手势
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(avatarTapped))
        avatarImageView.addGestureRecognizer(tapGesture)
        
        // 姓名标签设置
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        nameLabel.textColor = UIColor.label
        
        // 邮箱标签设置
        emailLabel.font = UIFont.systemFont(ofSize: 14)
        emailLabel.textColor = UIColor.secondaryLabel
    }
    
    private func setupUserViewConstraints() {
        avatarImageView.snp.makeConstraints { make in
            make.top.equalTo(20)
            make.leading.equalToSuperview()
            make.size.equalTo(80)
            make.bottom.equalTo(-20)
        }
        
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(16)
            make.top.equalTo(avatarImageView).offset(8)
            make.trailing.equalToSuperview()
        }
        
        emailLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(4)
            make.trailing.equalToSuperview()
        }
    }
    
    private func configureDefaultContent() {
        nameLabel.text = "Alex Johnson"
        emailLabel.text = "alex.j@email.com"
        avatarImageView.image = UIImage(systemName: "person.circle.fill")
        avatarImageView.tintColor = UIColor.systemGray3
    }
    
    @objc private func avatarTapped() {
        avatarTapAction?()
    }
}
