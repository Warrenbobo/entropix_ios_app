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
    private static var cachedAppUpdatedStatus: LMAppUpdatedStatus?
    private static var ignoredNonRequiredUpdateIdentity: String?
    private static var hasPresentedNonRequiredUpdateThisSession = false
    private static var isShowingUpdateAlert = false
    
    static var hasAvailableAppUpdate: Bool {
        isUpdateAvailable(in: cachedAppUpdatedStatus)
    }
    
    static var currentAppUpdateInfo: LMAppUpdateInfo? {
        guard isUpdateAvailable(in: cachedAppUpdatedStatus) else { return nil }
        return cachedAppUpdatedStatus?.update
    }
    
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

    /// 当前版本的默认首页：Basic Camera
    public static func makeHomeRootController() -> UIViewController {
        let cameraPage = LMCameraPage()
        return LMNavigationWrapper(rootViewController: cameraPage)
    }

    /// 切换到默认首页
    public static func switchToHomeRootController() {
        switchWindowSceneContent(makeHomeRootController())
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
    static func queryVersionConfigs(forceRefresh: Bool = true,
                                    completeCallback: (() -> ())? = nil) {
        fetchAppUpdateStatus(forceRefresh: forceRefresh) { _ in
            completeCallback?()
        }
    }
    
    static func refreshAppUpdateStatus(completion: ((Bool) -> Void)? = nil) {
        fetchAppUpdateStatus(forceRefresh: true) { status in
            completion?(isUpdateAvailable(in: status))
        }
    }
    
    static func presentCachedAppUpdateIfNeeded(from presenter: UIViewController) {
        guard let update = currentAppUpdateInfo else { return }
        guard !isShowingUpdateAlert else { return }
        
        if update.isForceUpdate {
            showAppUpdateAlert(update, from: presenter)
            return
        }
        
        guard !hasPresentedNonRequiredUpdateThisSession else { return }
        guard !isIgnoredNonRequiredUpdate(update) else { return }
        hasPresentedNonRequiredUpdateThisSession = true
        showAppUpdateAlert(update, from: presenter)
    }
    
    static func openCurrentAvailableUpdateURL() {
        openUpdateURL(currentAppUpdateInfo?.url)
    }
    
    private static func fetchAppUpdateStatus(forceRefresh: Bool,
                                             completion: ((LMAppUpdatedStatus?) -> Void)? = nil) {
        if !forceRefresh, let cachedAppUpdatedStatus = cachedAppUpdatedStatus {
            completion?(cachedAppUpdatedStatus)
            return
        }
        
        LMApiService.shared.getAppUpdatedStatus { response in
            guard response.requestSuccess, let data = response.value else {
                LMLogger.log("⚠️ Failed to fetch app updated status: \(response.message ?? "Unknown error")")
                cachedAppUpdatedStatus = nil
                completion?(nil)
                return
            }
            
            cachedAppUpdatedStatus = data
            
            if let versionStatus = data.versionStatus {
                reviewState = (versionStatus == 1) ? .normal : .inReview
                LMLogger.log("📦 App version status: \(versionStatus) (reviewState=\(reviewState))")
            }
            
            completion?(data)
        }
    }
    
    private static func isUpdateAvailable(in status: LMAppUpdatedStatus?) -> Bool {
        guard let status = status,
              status.versionStatus == 1,
              status.update != nil else {
            return false
        }
        return true
    }
    
    private static func isIgnoredNonRequiredUpdate(_ update: LMAppUpdateInfo) -> Bool {
        ignoredNonRequiredUpdateIdentity == update.updateIdentity
    }
    
    private static func showAppUpdateAlert(_ update: LMAppUpdateInfo,
                                           from _: UIViewController) {
        guard !isShowingUpdateAlert else { return }
        isShowingUpdateAlert = true
        
        let isForceUpdate = update.isForceUpdate
        let title = isForceUpdate ? LMText.common.updateRequiredTitle : LMText.common.updateAvailableTitle
        let message = buildUpdateMessage(update)
        let cancelText = isForceUpdate ? LMText.common.exit : LMText.common.later
        
        let dialog = LMAlertDialog(config: LMAlertDialogConfig(
            title: title,
            message: message,
            cancelButtonText: cancelText,
            confirmButtonText: LMText.common.updateNow,
            confirmButtonStyle: .gradient,
            onCancel: {
                isShowingUpdateAlert = false
                if isForceUpdate {
                    exit(0)
                } else {
                    ignoredNonRequiredUpdateIdentity = update.updateIdentity
                }
            },
            onConfirm: {
                isShowingUpdateAlert = false
                openUpdateURL(update.url)
            }
        ))
        
        dialog.show(onDismiss: {
            isShowingUpdateAlert = false
        })
    }
    
    private static func openUpdateURL(_ urlString: String?) {
        let resolvedURLString = urlString.nonEmpty ?? AppConfigs.AppStore.updateURL
        guard let url = URL(string: resolvedURLString) else {
            AppTheme.Toast.showText(LMText.common.invalidUpdateUrl)
            return
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    private static func buildUpdateMessage(_ update: LMAppUpdateInfo) -> String {
        let intro = update.isForceUpdate ? LMText.common.updateRequiredIntro : LMText.common.updateWhatsNew
        let content = htmlToPlainText(update.content)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = (content?.isEmpty == false) ? content! : LMText.common.updateFallbackContent
        return intro + "\n\n" + body
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

private extension LMAppUpdateInfo {
    var isForceUpdate: Bool {
        (requireUpdateStatus ?? 0) == 1
    }
    
    var updateIdentity: String {
        [version.nonEmpty, url.nonEmpty, content.nonEmpty]
            .compactMap { $0 }
            .joined(separator: "|")
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}
