//
//  LMPackageManager.swift
//  processor
//
//  Created by muz on 2025/9/20.
//  合并了设备管理和游客模式功能
//

import UIKit
import KeychainAccess

/// 审核的状态类型
enum AppReviewState {
    // 正常
    case normal
    // 审核
    case inReview
}

struct LMPackageManager {
    
    // 审核状态
    static var reviewState: AppReviewState = .inReview
    // 是否是首次安装用户
    static var newInstaller: Bool = false
    // 应用启动时携带的参数
    static var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    // 应用初始化窗口
    static weak var window: UIWindow?
    
    // APP包信息
    static var package: LMPackageModel = LMPackageModel.defaultModel()
    
    // MARK: - Guest Trial Management (游客模式管理)
    
    private static let guestTrialCountKey = "lm_guest_trial_count"
    private static let guestTrialDeviceIdKey = "lm_guest_trial_device_id"
    private static let maxGuestTrialCount = 3
    
    /// 游客模式剩余次数
    static var guestTrialCount: Int {
        get {
            // 检查设备ID是否匹配，防止重装APP刷新次数
            if let savedDeviceId = UserDefaults.standard.string(forKey: guestTrialDeviceIdKey),
               savedDeviceId == package.uuid {
                return UserDefaults.standard.integer(forKey: guestTrialCountKey)
            }
            // 新设备，初始化为最大次数
            return maxGuestTrialCount
        }
        set {
            UserDefaults.standard.set(newValue, forKey: guestTrialCountKey)
            UserDefaults.standard.set(package.uuid, forKey: guestTrialDeviceIdKey)
            LMLogger.log("📱 Guest trial count updated: \(newValue)")
        }
    }
    
    /// 是否有游客试用次数
    static var hasGuestTrialAvailable: Bool {
        return guestTrialCount > 0
    }
    
    /// 消耗一次游客试用次数
    @discardableResult
    static func consumeGuestTrial() -> Bool {
        guard hasGuestTrialAvailable else {
            LMLogger.log("⚠️ No guest trial available")
            return false
        }
        
        guestTrialCount -= 1
        LMLogger.log("✅ Guest trial consumed, remaining: \(guestTrialCount)")
        return true
    }
    
    /// 重置游客试用次数（仅用于测试）
    static func resetGuestTrial() {
        guestTrialCount = maxGuestTrialCount
        LMLogger.log("🔄 Guest trial reset to \(maxGuestTrialCount)")
    }
    
    /// 切换当前窗口的根视图
    public static func switchWindowSceneContent(_ controller: UIViewController) {
        window?.rootViewController = controller
    }
    
    
    /// 初始化App的包信息
    /// 包括相册的授权状态，用户信息，一些App的版本信息等
    public static func setup() {
        loadAppPackageData()
        queryDeviceUUID()
        loadGuestTrialData()
        loadLanguageConfiguration()
    }
    
    /// 加载语言配置
    private static func loadLanguageConfiguration() {
        LMLaunageManager.shared.loadLanguageConfiguration()
        LMLogger.log("✅ Language configuration initialized")
    }
    
    /// 加载游客试用数据
    private static func loadGuestTrialData() {
        let count = guestTrialCount
        LMLogger.log("📱 Device ID: \(package.uuid)")
        LMLogger.log("📱 Guest trial count: \(count)")
    }
    
    
    // 初始化系统的基础信息
    private static func loadAppPackageData() {
        // 包信息相关
        if let appInfo = Bundle.main.infoDictionary as NSDictionary? {
            if let name = appInfo.value(forKey: "CFBundleIdentifier") as? String {
                package.bundleName = name
            }
            if let appVersion = appInfo.value(forKey: "CFBundleShortVersionString") as? String {
                package.version = appVersion
            }
            if let buildCode = appInfo.value(forKey: "CFBundleVersion") as? String {
                package.build = buildCode
            }
        }
        // 系统信息
        package.release = UIDevice.current.systemVersion
        // idfa
//        if let idfaString = UserDefaults.standard.value(forKey: StoreKey.idfa) as? String {
//            idfa = idfaString
//        }
    }
    
    // 实例化keychain对象
    private static var keychain: Keychain {
        return Keychain(service: "com.processor.keychain")
    }
    
    // 获取用户的uuid信息
    private static func queryDeviceUUID() {
        let cachedKey = "com.processor.keychain.uuid"
        do {
            var uid = UserDefaults.standard.value(forKey: cachedKey) as? String
            if uid == nil {
                uid = try keychain.getString(cachedKey)
            }
            if uid != nil  {
                package.uuid = uid!
            } else {
                if let uid = UIDevice.current.identifierForVendor?.uuidString {
                    try keychain.set(uid, key: cachedKey)
                    UserDefaults.standard.set(uid, forKey: cachedKey)
                    package.uuid = uid
                }
            }
        } catch let error {
            print("keychain uuid update is error: \(error.localizedDescription)")
        }
    }
    
    private static var idfaTimer: Timer?
    
    // 请求ATTracking权限
    static func requestATTrackingPermission(complete: (() -> ())? = nil) {
        
    }
    
    /// 更新版本信息
    static func queryVersionConfigs(completeCallback: (() -> ())? = nil) {
        LMApiService.shared.getAppUpdatedStatus { response in
            guard response.requestSuccess, let data = response.value else {
                LMLogger.log("⚠️ Failed to fetch app updated status: \(response.message ?? "Unknown error")")
                completeCallback?()
                return
            }
            
            // 1 = 已发布，0 = 审核中
            if let versionStatus = data.versionStatus {
                reviewState = (versionStatus == 1) ? .normal : .inReview
                LMLogger.log("📦 App version status: \(versionStatus) (reviewState=\(reviewState))")
            }
            
            // update 字段有值且 version > 当前包版本时，显示更新弹窗
            guard let update = data.update,
                  let targetVersion = update.version?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !targetVersion.isEmpty,
                  isVersion(targetVersion, greaterThan: package.version) else {
                completeCallback?()
                return
            }
            
            showAppUpdateAlert(update) { canProceed in
                if canProceed {
                    completeCallback?()
                }
            }
        }
    }
    
    // MARK: - App Update (版本更新弹窗)
    
    private static var isShowingUpdateAlert: Bool = false
    
    private static func showAppUpdateAlert(_ update: LMAppUpdateInfo, completion: @escaping (Bool) -> Void) {
        guard !isShowingUpdateAlert else { return }
        isShowingUpdateAlert = true
        
        let isForceUpdate = (update.requireUpdateStatus ?? 0) == 1
        
        let title = update.title ?? LMText.common.newVersionAvailable
        let message = buildUpdateMessage(update)
        
        let cancelText: String? = isForceUpdate ? nil : LMText.common.notNow
        let confirmText: String = LMText.common.updateNow
        
        let dialog = LMAlertDialog(config: LMAlertDialogConfig(
            title: title,
            message: message,
            cancelButtonText: cancelText,
            confirmButtonText: confirmText,
            confirmButtonStyle: .gradient,
            onCancel: {
                isShowingUpdateAlert = false
                completion(true)
            },
            onConfirm: {
                openUpdateURL(update.url)
                isShowingUpdateAlert = false
                if !isForceUpdate {
                    completion(true)
                } else {
                    completion(false)
                }
            }
        ))
        
        dialog.show(onDismiss: {
            isShowingUpdateAlert = false
            
            // 强制更新：用户返回 App 时继续拦截
            if isForceUpdate {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showAppUpdateAlert(update, completion: completion)
                }
            }
        })
    }
    
    private static func openUpdateURL(_ urlString: String?) {
        guard let urlString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: urlString) else {
            AppTheme.Toast.showText(LMText.common.invalidUpdateUrl)
            return
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    private static func buildUpdateMessage(_ update: LMAppUpdateInfo) -> String {
        let content = htmlToPlainText(update.content)
        
        var lines: [String] = []
        if let content = content, !content.isEmpty {
            lines.append(content)
        } else {
            let isForceUpdate = (update.requireUpdateStatus ?? 0) == 1
            lines.append(isForceUpdate ? LMText.common.updateRequiredMessage : LMText.common.updateAvailableMessage)
        }
        return lines.joined(separator: "\n\n")
    }
    
    private static func htmlToPlainText(_ html: String?) -> String? {
        guard let html = html, !html.isEmpty else { return nil }
        guard let data = html.data(using: .utf8) else { return html }
        
        if let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) {
            return attributed.string
        }
        
        return html
    }
    
    private static func isVersion(_ newVersion: String, greaterThan currentVersion: String) -> Bool {
        let newComponents = versionNumberComponents(from: newVersion)
        let currentComponents = versionNumberComponents(from: currentVersion)
        
        let maxCount = max(newComponents.count, currentComponents.count)
        for index in 0..<maxCount {
            let lhs = index < newComponents.count ? newComponents[index] : 0
            let rhs = index < currentComponents.count ? currentComponents[index] : 0
            if lhs != rhs {
                return lhs > rhs
            }
        }
        return false
    }
    
    private static func versionNumberComponents(from version: String) -> [Int] {
        return version
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
    }
}

// MARK: - Models

/// GET /v1/app/updated -> data
struct LMAppUpdatedStatus: Codable {
    var versionStatus: Int?
    var update: LMAppUpdateInfo?
}

struct LMAppUpdateInfo: Codable {
    var requireUpdateStatus: Int?
    var title: String?
    var content: String?
    var version: String?
    var url: String?
    
    enum CodingKeys: String, CodingKey {
        case requireUpdateStatus = "require_update_status"
        case title
        case content
        case version
        case url
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}
