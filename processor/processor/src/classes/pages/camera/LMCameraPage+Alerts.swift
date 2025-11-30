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
        let config = LMAlertDialogConfig(
            title: "Error",
            message: message,
            cancelButtonText: "",
            confirmButtonText: "OK",
            confirmButtonStyle: .normal,
            onConfirm: {}
        )
        // Hide cancel button by making it invisible
        let dialog = LMAlertDialog(config: config)
        dialog.show(on: self)
    }
    
    /// 显示警告对话框
    private func showWarningAlert(_ message: String) {
        let config = LMAlertDialogConfig(
            title: "Warning",
            message: message,
            cancelButtonText: "",
            confirmButtonText: "OK",
            confirmButtonStyle: .normal,
            onConfirm: {}
        )
        let dialog = LMAlertDialog(config: config)
        dialog.show(on: self)
    }
    
    /// 显示 Toast 轻量提示
    private func showToastMessage(_ message: String, duration: TimeInterval = 2.0) {
        showToast(message, duration: duration)
    }
}

// MARK: - Confirmation Dialogs
extension LMCameraPage {
    
    /// 显示离开 Show Suggestions 确认对话框
    func showLeaveConfirmation(completion: @escaping (Bool) -> Void) {
        let config = LMAlertDialogConfig(
            image: UIImage(named: "exclamation_triangle_orange"),
            title: "Give Up Inspires?",
            message: "You will return to the camera. This action cannot be undone.",
            cancelButtonText: LMLaunageManager.shared.common.cancel,
            confirmButtonText: "Leave",
            confirmButtonStyle: .destructive,
            onCancel: { completion(false) },
            onConfirm: { completion(true) }
        )
        let customDialog = LMAlertDialog(config: config)
        customDialog.show(on: self)
    }
}

// MARK: - ViewTag Extension
extension LMCameraPage.ViewTag {
    static var toastMessage: Int { return 8893 }
}
