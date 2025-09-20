//
//  LMDialogWrapper.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit

class LMDialogWrapper<T: UIView>: UIView {

    /// 弹窗主体界面
    public var contentView: T?
    /// 关闭按钮
    public lazy var closeButton = { UIButton(type: .custom) }()
    
    /// 显示弹窗
    public func show() {
        guard let window = AppTheme.Screen.window(), !alreadyShowInWindow else { return }
        contentView?.alpha = 0
        contentView?.transform = CGAffineTransformMakeScale(0.1, 0.1)
        window.addSubview(self)
        alreadyShowInWindow = true
        UIView.animate(withDuration: 0.5) {
            self.contentView?.alpha = 1
            self.contentView?.transform = .identity
        }
    }
    
    /// 隐藏弹窗
    public func hiddenDialog() {
        alreadyShowInWindow = false
        isHidden = true
        removeFromSuperview()
    }
    
    /// 是否已经显示了
    private var alreadyShowInWindow: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black.withAlphaComponent(0.6)
        let dialogContentView = T()
        addSubview(dialogContentView)
        contentView = dialogContentView
        dialogContentView.snp.makeConstraints({ make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(26)
            make.trailing.equalTo(-26)
        })
        
        closeButton.isHidden = true
        addSubview(closeButton)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        endEditing(true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
