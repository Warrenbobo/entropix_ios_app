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
    case normal
    case inReview
}

struct LMPackageManager {

    static var reviewState: AppReviewState = .inReview
    static var newInstaller: Bool = false
    static var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    static weak var window: UIWindow?

    static var package: LMPackageModel = LMPackageModel.defaultModel()
    private static var cachedAppUpdatedStatus: LMAppUpdatedStatus?
    private static var cachedAppUpdatedLanguageCode: String?
    private static var ignoredNonRequiredUpdateIdentity: String?
    private static var hasPresentedNonRequiredUpdateThisSession = false
    private static var isShowingUpdateAlert = false

    static var hasAvailableAppUpdate: Bool {
        isUpdateAvailable(in: cachedAppUpdatedStatus)
    }

    static var currentAppUpdateInfo: LMAppUpdateInfo? {
        availableUpdate(in: cachedAppUpdatedStatus)
    }

    private static let guestTrialCountKey = "lm_guest_trial_count"
    private static let guestTrialDeviceIdKey = "lm_guest_trial_device_id"
    private static let maxGuestTrialCount = 3

    static var guestTrialCount: Int {
        get {
            if let savedDeviceId = UserDefaults.standard.string(forKey: guestTrialDeviceIdKey),
               savedDeviceId == package.uuid {
                return UserDefaults.standard.integer(forKey: guestTrialCountKey)
            }
            return maxGuestTrialCount
        }
        set {
            UserDefaults.standard.set(newValue, forKey: guestTrialCountKey)
            UserDefaults.standard.set(package.uuid, forKey: guestTrialDeviceIdKey)
            LMLogger.log("📱 Guest trial count updated: \(newValue)")
        }
    }

    static var hasGuestTrialAvailable: Bool {
        guestTrialCount > 0
    }

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

    static func resetGuestTrial() {
        guestTrialCount = maxGuestTrialCount
        LMLogger.log("🔄 Guest trial reset to \(maxGuestTrialCount)")
    }

    public static func switchWindowSceneContent(_ controller: UIViewController) {
        window?.rootViewController = controller
    }

    public static func makeHomeRootController() -> UIViewController {
        let cameraPage = LMCameraPage()
        return LMNavigationWrapper(rootViewController: cameraPage)
    }

    public static func switchToHomeRootController() {
        switchWindowSceneContent(makeHomeRootController())
    }

    public static func setup() {
        loadAppPackageData()
        queryDeviceUUID()
        loadGuestTrialData()
        loadLanguageConfiguration()
    }

    private static func loadLanguageConfiguration() {
        LMLaunageManager.shared.loadLanguageConfiguration()
        LMLogger.log("✅ Language configuration initialized")
    }

    private static func loadGuestTrialData() {
        let count = guestTrialCount
        LMLogger.log("📱 Device ID: \(package.uuid)")
        LMLogger.log("📱 Guest trial count: \(count)")
    }

    private static func loadAppPackageData() {
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
        package.release = UIDevice.current.systemVersion
    }

    private static var keychain: Keychain {
        Keychain(service: "com.processor.keychain")
    }

    private static func queryDeviceUUID() {
        let cachedKey = "com.processor.keychain.uuid"
        if let cachedUUID = UserDefaults.standard.string(forKey: cachedKey),
           !cachedUUID.isEmpty {
            package.uuid = cachedUUID
            return
        }

        do {
            if let keychainUUID = try keychain.getString(cachedKey),
               !keychainUUID.isEmpty {
                UserDefaults.standard.set(keychainUUID, forKey: cachedKey)
                package.uuid = keychainUUID
                return
            }
        } catch {
            LMLogger.log("⚠️ Keychain uuid read failed: \(error.localizedDescription)")
        }

        let fallbackUUID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        package.uuid = fallbackUUID
        UserDefaults.standard.set(fallbackUUID, forKey: cachedKey)

        do {
            try keychain.set(fallbackUUID, key: cachedKey)
        } catch {
            LMLogger.log("⚠️ Keychain uuid save failed: \(error.localizedDescription)")
        }
    }

    private static var idfaTimer: Timer?

    static func requestATTrackingPermission(complete: (() -> Void)? = nil) {
        _ = idfaTimer
        complete?()
    }

    static func queryAppUpdateStatus(forceRefresh: Bool = true,
                                     completion: ((LMAppUpdatedStatus?) -> Void)? = nil) {
        fetchAppUpdateStatus(forceRefresh: forceRefresh, completion: completion)
    }

    static func queryVersionConfigs(forceRefresh: Bool = true,
                                    completeCallback: (() -> Void)? = nil) {
        queryAppUpdateStatus(forceRefresh: forceRefresh) { _ in
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

    static func presentLaunchAppUpdateIfNeeded(from _: UIViewController,
                                               onContinue: @escaping () -> Void) {
        guard let update = currentAppUpdateInfo else {
            onContinue()
            return
        }
        guard !isShowingUpdateAlert else { return }

        let isForceUpdate = update.isForceUpdate
        if !isForceUpdate {
            guard !hasPresentedNonRequiredUpdateThisSession else {
                onContinue()
                return
            }
            guard !isIgnoredNonRequiredUpdate(update) else {
                onContinue()
                return
            }
            hasPresentedNonRequiredUpdateThisSession = true
        }
        isShowingUpdateAlert = true

        let title = resolvedUpdateTitle(update)
        let intro = resolvedUpdateContent(update)
        let details = ""
        let cancelText = isForceUpdate ? LMText.common.exit : LMText.common.later

        let dialog = LMVersionUpdateDialog(config: LMVersionUpdateDialogConfig(
            title: title,
            intro: intro,
            details: details,
            cancelButtonText: cancelText,
            confirmButtonText: LMText.common.updateNow,
            onCancel: {
                isShowingUpdateAlert = false
                if isForceUpdate {
                    exit(0)
                } else {
                    ignoredNonRequiredUpdateIdentity = update.updateIdentity
                    onContinue()
                }
            },
            onConfirm: {
                isShowingUpdateAlert = false
                openUpdateURL(update.url)
                if !isForceUpdate {
                    ignoredNonRequiredUpdateIdentity = update.updateIdentity
                    onContinue()
                }
            }
        ))

        dialog.show(onDismiss: {
            isShowingUpdateAlert = false
        })
    }

    static func openCurrentAvailableUpdateURL() {
        openUpdateURL(currentAppUpdateInfo?.url)
    }

    private static func fetchAppUpdateStatus(forceRefresh: Bool,
                                             completion: ((LMAppUpdatedStatus?) -> Void)? = nil) {
        let currentLanguageCode = LMLaunageManager.shared.currentLanguage.apiLanguageCode

        if !forceRefresh,
           let cachedAppUpdatedStatus,
           cachedAppUpdatedLanguageCode == currentLanguageCode {
            completion?(cachedAppUpdatedStatus)
            return
        }

        LMApiService.shared.getAppUpdatedStatus { response in
            guard response.requestSuccess, let data = response.value else {
                LMLogger.log("⚠️ Failed to fetch app updated status: \(response.message ?? "Unknown error")")
                cachedAppUpdatedStatus = nil
                cachedAppUpdatedLanguageCode = nil
                completion?(nil)
                return
            }

            cachedAppUpdatedStatus = data
            cachedAppUpdatedLanguageCode = currentLanguageCode

            if let versionStatus = data.versionStatus {
                reviewState = (versionStatus == 1) ? .normal : .inReview
                LMLogger.log("📦 App version status: \(versionStatus) (reviewState=\(reviewState))")
            }

            completion?(data)
        }
    }

    private static func isUpdateAvailable(in status: LMAppUpdatedStatus?) -> Bool {
        availableUpdate(in: status) != nil
    }

    private static func isIgnoredNonRequiredUpdate(_ update: LMAppUpdateInfo) -> Bool {
        ignoredNonRequiredUpdateIdentity == update.updateIdentity
    }

    private static func showAppUpdateAlert(_ update: LMAppUpdateInfo,
                                           from _: UIViewController) {
        guard !isShowingUpdateAlert else { return }
        isShowingUpdateAlert = true

        let isForceUpdate = update.isForceUpdate
        let title = resolvedUpdateTitle(update)
        let message = resolvedUpdateContent(update)
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

    private static func availableUpdate(in status: LMAppUpdatedStatus?) -> LMAppUpdateInfo? {
        guard let status,
              status.versionStatus == 1,
              let update = status.update,
              update.shouldPresent(forCurrentVersion: package.version) else {
            return nil
        }
        return update
    }

    private static func resolvedUpdateTitle(_ update: LMAppUpdateInfo) -> String {
        update.title.nonEmpty ?? (update.isForceUpdate ? LMText.common.updateRequiredTitle : LMText.common.updateAvailableTitle)
    }

    private static func resolvedUpdateContent(_ update: LMAppUpdateInfo) -> String {
        let content = htmlToPlainText(update.content)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (content?.isEmpty == false) ? content! : LMText.common.updateFallbackContent
    }

    private static func buildUpdateMessage(_ update: LMAppUpdateInfo) -> String {
        resolvedUpdateContent(update)
    }

    private static func buildUpdateDetails(_ update: LMAppUpdateInfo) -> String {
        resolvedUpdateContent(update)
    }

    private static func htmlToPlainText(_ html: String?) -> String? {
        guard let html, !html.isEmpty else { return nil }
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

    func shouldPresent(forCurrentVersion currentVersion: String) -> Bool {
        guard let updateVersion = version.nonEmpty,
              let currentVersion = Optional.some(currentVersion).nonEmpty else {
            return false
        }
        return updateVersion != currentVersion
    }

    var updateIdentity: String {
        [version.nonEmpty, url.nonEmpty, title.nonEmpty, content.nonEmpty]
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
