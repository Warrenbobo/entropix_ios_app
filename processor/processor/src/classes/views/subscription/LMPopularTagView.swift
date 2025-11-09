//
//  LMPopularTagView.swift
//  processor
//
//  Created by muz on 2025/11/9.
//

import Foundation
import UIKit

class LMPopularTagView: UIView {
    
    public var tagText: UILabel {
        return badgeText
    }
    
    private let badgeText = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.masksToBounds = true
        badgeText.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        badgeText.textColor = .white
        badgeText.textAlignment = .center
        addSubview(badgeText)
        badgeText.snp.makeConstraints { make in
            make.leading.equalTo(12)
            make.trailing.equalTo(-12)
            make.top.equalToSuperview()
            make.bottom.equalTo(-3)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if layer.mask == nil && bounds != .zero {
            setCorners([.bottomLeft, .bottomRight], with: 16)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class LMDiscountBadgeView: UIView {
    
    public var tagText: UILabel {
        return badgeText
    }
    
    private let badgeText = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 6
        layer.masksToBounds = true
        badgeText.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        badgeText.textAlignment = .center
        addSubview(badgeText)
        badgeText.snp.makeConstraints { make in
            make.leading.equalTo(6)
            make.trailing.equalTo(-6)
            make.top.equalTo(2)
            make.bottom.equalTo(-2)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
