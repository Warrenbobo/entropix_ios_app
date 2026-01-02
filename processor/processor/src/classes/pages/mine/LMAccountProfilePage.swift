//
//  LMAccountProfilePage.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import SnapKit
import AVFoundation
import Photos

class LMAccountProfilePage: LMPageWrapper {
    
    // MARK: - Properties
    private var userProfileData = LMUserModel.sample(userId: "")
    private var isEditingMode = false
    private var imagePicker: UIImagePickerController?
    private var isSaving = false
    private var isUploadingAvatar = false
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    // Custom Navigation Bar Right
    private let actionButton = UIButton()
    
    // View State Views
    private let displayView = LMProfileDisplayView()
    private let editView = LMProfileEditView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        barTitle = LMText.profile.accountProfile
        setupCustomNavigationBar()
        setupUserInterfaceComponents()
        configureLayoutConstraints()
        configureDefaultContentAndStyles()
        setupDelegates()
        loadUserData()
        showDisplayView()
        
        // 监听语言变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: LMLaunageManager.languageDidChangeNotification,
            object: nil
        )
        
        // 监听用户数据变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDataDidChange),
            name: LMUserManager.userDataDidChangeNotification,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        // 添加键盘通知监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // 移除键盘通知监听
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    override func backButtonItemOnTap() {
        if isEditingMode {
            // 如果在编辑模式，检查是否有未保存的修改
            if editView.hasUnsavedChanges() {
                // 显示确认弹窗
                showDiscardChangesAlert()
            } else {
                // 没有修改，直接返回显示模式
                showDisplayView()
            }
        } else {
            // 如果在显示模式，返回上一页
            navigationController?.popViewController(animated: true)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Localization
    
    @objc private func languageDidChange() {
        updateTexts()
    }
    
    private func updateTexts() {
        barTitle = LMText.profile.accountProfile
        actionButton.setTitle(LMText.common.save, for: .normal)
    }
    
    @objc private func userDataDidChange() {
        loadUserData()
    }
    
    /// 从 LMUserManager 加载用户数据
    private func loadUserData() {
        if let userModel = LMUserManager.userModel {
            userProfileData = userModel
            updateViewsWithData()
        }
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard isEditingMode,
              let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardHeight, right: 0)
        
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset = contentInsets
            self.scrollView.scrollIndicatorInsets = contentInsets
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset = .zero
            self.scrollView.scrollIndicatorInsets = .zero
        }
    }
}

// MARK: - Setup Methods
extension LMAccountProfilePage {
    
    private func setupCustomNavigationBar() {
        actionButton.setTitle(LMText.common.save, for: .normal)
        actionButton.contentMode = .right
        actionButton.frame = CGRect(origin: .zero, size: CGSize(width: 50, height: 44))
        actionButton.setTitleColor(UIColor.systemBlue, for: .normal)
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        actionButton.addTarget(self, action: #selector(handleSaveButtonTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: actionButton)
        // 初始状态隐藏保存按钮（显示模式下不需要）
        actionButton.isHidden = true
    }
    
    private func setupUserInterfaceComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(displayView)
        contentView.addSubview(editView)
        
        // 初始状态隐藏编辑视图
        editView.isHidden = true
    }
    
    private func setupDelegates() {
        displayView.delegate = self
        editView.delegate = self
    }

    private func configureLayoutConstraints() {
        scrollView.snp.makeConstraints { make in
            make.top.equalTo(AppTheme.Screen.navigatorHeight)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        displayView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.medium)
        }
        
        editView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().priority(.medium)
        }
    }
    
    private func configureDefaultContentAndStyles() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
    }

    private func updateViewsWithData() {
        displayView.updateWithData(userProfileData)
        editView.updateWithData(userProfileData)
    }
    
    private func showDisplayView() {
        isEditingMode = false
        displayView.isHidden = false
        editView.isHidden = true
        actionButton.isHidden = true
        
        // 确保布局更新
        DispatchQueue.main.async {
            self.view.layoutIfNeeded()
        }
    }
    
    private func showEditView() {
        isEditingMode = true
        displayView.isHidden = true
        editView.isHidden = false
        actionButton.isHidden = false
        
        // 确保布局更新并滚动到顶部
        DispatchQueue.main.async {
            self.view.layoutIfNeeded()
            self.scrollView.setContentOffset(.zero, animated: true)
        }
    }
}

// MARK: - Action Handlers
extension LMAccountProfilePage {
    
    /// 显示放弃修改确认弹窗
    private func showDiscardChangesAlert() {
        LMAlertDialog.showAlert(
            title: LMText.profile.discardChanges,
            message: LMText.profile.discardChangesMessage,
            cancelText: LMText.common.cancel,
            confirmText: LMText.profile.discard,
            onConfirm: { [weak self] in
                // 用户确认放弃修改，恢复原始数据并返回显示模式
                self?.editView.updateWithData(self?.userProfileData ?? LMUserModel(userId: ""))
                self?.showDisplayView()
            }
        )
    }
    
    @objc private func handleSaveButtonTapped() {
        guard !isSaving else { return }
        // 获取编辑视图的数据
        let updatedData = editView.getCurrentData()
        // 调用后端 API 保存
        saveProfileToServer(updatedData)
    }
    
    /// 保存用户资料到服务器
    private func saveProfileToServer(_ data: LMUserModel) {
        isSaving = true
        actionButton.isEnabled = false
        AppTheme.Toast.showText(LMText.common.saving)
        
        LMApiService.shared.updateProfile(
            username: data.username,
            nickname: data.nickname,
            language: LMLaunageManager.shared.currentLanguage.rawValue,
            dateOfBirth: data.birthDate
        ) { [weak self] response in
            guard let self = self else { return }
            
            self.isSaving = false
            self.actionButton.isEnabled = true
            
            if response.requestSuccess, let updatedUser = response.value {
                // 更新本地用户数据
                LMUserManager.shared.updateUser(updatedUser)
                
                self.userProfileData = updatedUser
                // 更新显示视图
                self.displayView.updateWithData(self.userProfileData)
                // 返回显示模式
                self.showDisplayView()
                // 显示保存成功提示
                self.showSaveSuccessAlert()
            } else {
                // 显示错误提示
                let errorMessage = response.message ?? LMText.profile.failedToSaveProfile
                AppTheme.Toast.showText(errorMessage)
            }
        }
    }
    
    private func showSaveSuccessAlert() {
        AppTheme.Toast.showText(LMText.profile.profileUpdated)
    }
}

// MARK: - ProfileDisplayViewDelegate
extension LMAccountProfilePage: ProfileDisplayViewDelegate {
    
    func profileDisplayViewDidTapCancelSubscription(_ view: LMProfileDisplayView) {
        showCancelSubscriptionAlert()
    }
    
    private func showCancelSubscriptionAlert() {
        let alert = UIAlertController(
            title: LMText.profile.cancelSubscriptionTitle,
            message: LMText.profile.cancelSubscriptionMessage,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: LMText.profile.keepSubscription, style: .cancel))
        alert.addAction(UIAlertAction(title: LMText.profile.cancelSubscription, style: .destructive) { _ in
            self.performSubscriptionCancellation()
        })
        
        present(alert, animated: true)
    }
    
    private func performSubscriptionCancellation() {
        // 更新数据
        userProfileData.subscription = LMText.profile.freePlan
        // 更新视图
        updateViewsWithData()
        // 显示确认
        AppTheme.Toast.showText(LMText.profile.subscriptionCancelled)
    }
    
    func profileDisplayViewDidTapEditProfileData(_ view: LMProfileDisplayView) {
        showEditView()
    }
    
    func profileDisplayViewDidTapSubscription(_ view: LMProfileDisplayView) {
        // TODO: 跳转到订阅页面
        AppTheme.Toast.showText(LMText.profile.subscriptionDetails)
    }
}

// MARK: - UIImagePickerControllerDelegate & UINavigationControllerDelegate
extension LMAccountProfilePage: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            
            // 优先使用编辑后的图片，如果没有则使用原图
            var selectedImage: UIImage?
            if let editedImage = info[.editedImage] as? UIImage {
                selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                selectedImage = originalImage
            }
            
            guard let image = selectedImage else {
                self.showImageProcessingError()
                return
            }
            
            // 处理图片（裁剪为圆形，调整大小）
            self.processAndUpdateAvatar(image)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    // MARK: - Image Processing
    
    private func processAndUpdateAvatar(_ image: UIImage) {
        guard !isUploadingAvatar else { return }
        
        isUploadingAvatar = true
        AppTheme.Toast.showText(LMText.profile.uploadingAvatar)
        
        // 在后台线程处理图片
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. 调整图片大小为 128x128
            let targetSize = CGSize(width: 300, height: 300)
            let processedImage = self.resizeImage(image, targetSize: targetSize)
            
            // 回到主线程上传到服务器
            DispatchQueue.main.async {
                self.uploadAvatarToServer(processedImage)
            }
        }
    }
    
    /// 上传头像到服务器
    private func uploadAvatarToServer(_ image: UIImage) {
        LMApiService.shared.updateAvatar(image: image) { [weak self] response in
            guard let self = self else { return }
            self.isUploadingAvatar = false
            if response.requestSuccess, let updatedUser = response.value {
                // 更新本地用户数据
                LMUserManager.shared.updateUser(updatedUser)
                self.userProfileData = updatedUser
                // 更新编辑视图的头像
                self.editView.setAvatarImage(image)
                // 显示成功提示
                self.showAvatarUpdateSuccess()
            } else {
                // 显示错误提示
                let errorMessage = response.message ?? LMText.profile.failedToSaveProfile
                AppTheme.Toast.showText(errorMessage)
            }
        }
    }
    
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        
        // 使用较小的比例以确保图片完全覆盖目标尺寸
        let scaleFactor = max(widthRatio, heightRatio)
        
        let scaledSize = CGSize(
            width: size.width * scaleFactor,
            height: size.height * scaleFactor
        )
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            // 计算居中位置
            let x = (targetSize.width - scaledSize.width) / 2
            let y = (targetSize.height - scaledSize.height) / 2
            
            image.draw(in: CGRect(
                x: x,
                y: y,
                width: scaledSize.width,
                height: scaledSize.height
            ))
        }
        
        return resizedImage
    }
    
    private func showAvatarUpdateSuccess() {
        AppTheme.Toast.showText(LMText.profile.avatarUpdated)
    }
    
    private func showImageProcessingError() {
        LMAlertDialog.showGeneralAlert(LMText.profile.failedToProcessImage,
            title: LMText.common.error,
            onConfirm: {}
        )
    }
}

// MARK: - ProfileEditViewDelegate
extension LMAccountProfilePage: ProfileEditViewDelegate {
    
    func profileEditViewDidTapChangePhoto(_ view: LMProfileEditView) {
        showImagePicker()
    }
    
    func profileEditViewDidTapChangePassword(_ view: LMProfileEditView) {
        let changePasswordPage = LMForgotPasswordPage()
        navigationController?.pushViewController(changePasswordPage, animated: true)
    }
    
    private func showImagePicker() {
        let alert = UIAlertController(title: LMText.profile.changePhoto, message: LMText.profile.choosePhotoSource, preferredStyle: .actionSheet)
        
        // 相机选项
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: LMText.profile.camera, style: .default) { [weak self] _ in
                self?.checkCameraPermissionAndPresent()
            })
        }
        
        // 相册选项
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            alert.addAction(UIAlertAction(title: LMText.profile.photoLibrary, style: .default) { [weak self] _ in
                self?.checkPhotoLibraryPermissionAndPresent()
            })
        }
        
        alert.addAction(UIAlertAction(title: LMText.common.cancel, style: .cancel))
        
        // iPad支持
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Camera Permission
    
    private func checkCameraPermissionAndPresent() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            presentImagePicker(sourceType: .camera)
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.presentImagePicker(sourceType: .camera)
                    } else {
                        self?.showPermissionDeniedAlert(for: "Camera")
                    }
                }
            }
            
        case .denied, .restricted:
            showPermissionDeniedAlert(for: "Camera")
            
        @unknown default:
            showPermissionDeniedAlert(for: "Camera")
        }
    }
    
    // MARK: - Photo Library Permission
    
    private func checkPhotoLibraryPermissionAndPresent() {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            presentImagePicker(sourceType: .photoLibrary)
            
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self?.presentImagePicker(sourceType: .photoLibrary)
                    } else {
                        self?.showPermissionDeniedAlert(for: "Photo Library")
                    }
                }
            }
            
        case .denied, .restricted:
            showPermissionDeniedAlert(for: "Photo Library")
            
        @unknown default:
            showPermissionDeniedAlert(for: "Photo Library")
        }
    }
    
    // MARK: - Present Image Picker
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = self
        picker.allowsEditing = true // 允许编辑（裁剪）
        picker.modalPresentationStyle = .fullScreen
        
        self.imagePicker = picker
        present(picker, animated: true)
    }
    
    // MARK: - Permission Denied Alert
    
    private func showPermissionDeniedAlert(for feature: String) {
        let title = String(format: LMText.settings.featureAccessRequiredFormat, feature)
        let message = String(format: LMText.settings.enableFeatureAccessMessage, feature)
        LMAlertDialog.showAlert(
            title: title,
            message: message,
            cancelText: LMText.common.cancel,
            confirmText: LMText.common.openSettings,
            onConfirm: {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        )
    }
}

// MARK: - UIGestureRecognizerDelegate
extension LMAccountProfilePage {
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 如果是滑动返回手势
        if gestureRecognizer == navigationController?.interactivePopGestureRecognizer {
            if isEditingMode {
                // 在编辑模式下，检查是否有未保存的修改
                if editView.hasUnsavedChanges() {
                    // 有未保存的修改，显示确认弹窗，阻止滑动返回
                    showDiscardChangesAlert()
                    return false
                } else {
                    // 没有修改，切换到显示模式，阻止滑动返回
                    showDisplayView()
                    return false
                }
            }
            // 显示模式下允许滑动返回
            return true
        }
        return true
    }
}
