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
//        ApiClient.request(Api.version,
//                          method: .get,
//                          type: VersionModel.self) { response in
//            if let update = response.value {
//                PackageUtil.reviewState = update.status == 1 ? .normal : .inReview
//                PackageUtil.upgradeModel = response.value?.package
//                if showVersionUpgradeAlert() {
//                    
//                }
//                if let qqText = update.qq {
//                    PackageUtil.customerQQ = qqText
//                }
//            }
//            PackageUtil.reviewState = .normal
//            completeCallback?()
//        }
    }
    
    /// 版本更新信息
//    private static var upgradeModel: VersionUpgradeModel?
    
    /// 显示版本更新提示
    static func showVersionUpgradeAlert() -> Bool {
//        if let model = upgradeModel,
//           let targetVersion = model.version,
//           targetVersion != PackageUtil.version {
//            let alertController = UIAlertController(title: model.title ?? "有新版本啦！",
//                                                    message: model.content ?? "及时更新版本可以使用最新的功能，体验更佳，赶快前往更新吧～",
//                                                    preferredStyle: .alert)
//            let cancelAction = UIAlertAction(title: "取消", style: .default)
//            let confirmAction = UIAlertAction(title: "立即更新",
//                                              style: .default) { _ in
//                if let urlString = model.downloadUrl, let url = URL(string: urlString) {
//                    UIApplication.shared.open(url)
//                }
//            }
//            if !(model.force ?? false) {
//                alertController.addAction(cancelAction)
//            }
//            alertController.addAction(confirmAction)
//            ScreenValue.showAlertController(alertController)
//            return true
//        }
        return false
    }
}
