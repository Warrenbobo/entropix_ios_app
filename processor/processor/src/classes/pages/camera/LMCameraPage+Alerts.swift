//
//  LMCameraPage+Alerts.swift
//  processor
//
//  Unified alert and toast management
//

import UIKit

// MARK: - Alert Management
extension LMCameraPage {
    
    /// 提示样式
    enum AlertStyle {
        case error      // 模态错误对话框
        case toast      // 轻量 Toast 提示
        case warning    // 警告对话框
    }
    
    /// 统一的提示方法
    /// - Parameters:
    ///   - message: 提示消息
    ///   - style: 提示样式（默认为 toast）
    func showAlert(_ message: String, style: AlertStyle = .toast) {
        switch style {
        case .error:
            showErrorAlert(message)
        case .toast:
            showToastMessage(message)
        case .warning:
            showWarningAlert(message)
        }
    }
    
    // MARK: - Private Alert Methods
    
    /// 显示错误对话框
    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// 显示警告对话框
    private func showWarningAlert(_ message: String) {
        let alert = UIAlertController(
            title: "Warning",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// 显示 Toast 轻量提示
    private func showToastMessage(_ message: String, duration: TimeInterval = 2.0) {
        // 移除已存在的 toast
        view.subviews
            .filter { $0.tag == ViewTag.toastMessage }
            .forEach { $0.removeFromSuperview() }
        
        let toast = UILabel()
        toast.tag = ViewTag.toastMessage
        toast.text = message
        toast.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toast.textAlignment = .center
        toast.numberOfLines = 0
        toast.layer.cornerRadius = 8
        toast.clipsToBounds = true
        toast.alpha = 0
        
        view.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-100)
            make.leading.greaterThanOrEqualToSuperview().offset(40)
            make.trailing.lessThanOrEqualToSuperview().offset(-40)
            make.height.greaterThanOrEqualTo(40)
        }
        
        // 动画显示和隐藏
        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: duration, animations: {
                toast.alpha = 0
            }) { _ in
                toast.removeFromSuperview()
            }
        }
    }
}

// MARK: - Confirmation Dialogs
extension LMCameraPage {
    
    /// 显示离开 Show Suggestions 确认对话框
    func showLeaveConfirmation(completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "Leave Suggestions?",
            message: "You will lose these suggestions if you go back.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        })
        
        alert.addAction(UIAlertAction(title: "Leave", style: .destructive) { _ in
            completion(true)
        })
        
        present(alert, animated: true)
    }
    
    /// 显示离开 Composition Selected 确认对话框
    func showLeaveCompositionConfirmation(completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(
            title: "Leave Composition?",
            message: "You will lose the current composition guidance.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completion(false)
        })
        
        alert.addAction(UIAlertAction(title: "Leave", style: .destructive) { _ in
            completion(true)
        })
        
        present(alert, animated: true)
    }
}

// MARK: - ViewTag Extension
extension LMCameraPage.ViewTag {
    static var toastMessage: Int { return 8893 }
}
