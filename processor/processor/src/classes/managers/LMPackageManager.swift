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

    /// Frozen: no longer driven by `/v1/app/updated` (App Store Lookup update path).
    static var reviewState: AppReviewState = .normal
    static var newInstaller: Bool = false
    static var launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    static weak var window: UIWindow?

    static var package: LMPackageModel = LMPackageModel.defaultModel()

    private static var cachedLookupResult: LMAppStoreLookupResult?
    private static var cachedClassification: LMAppUpdateClass = .none
    private static var cacheFetchedAt: Date?
    private static let cacheTTL: TimeInterval = 15 * 60

    private static var ignoredNonRequiredUpdateIdentity: String?
    private static var hasPresentedNonRequiredUpdateThisSession = false
    private static var isShowingUpdateAlert = false

    static var hasAvailableAppUpdate: Bool {
        currentAppUpdatePresentation != nil
    }

    /// Presentation model for dialogs / About Update when an update is classified.
    static var currentAppUpdatePresentation: LMAppUpdatePresentation? {
        guard let lookup = cachedLookupResult else { return nil }
        switch cachedClassification {
        case .none:
            return nil
        case .recommend:
            return LMAppUpdatePresentation(isForce: false, lookup: lookup, localVersion: package.version)
        case .force:
            return LMAppUpdatePresentation(isForce: true, lookup: lookup, localVersion: package.version)
        }
    }

    /// Legacy alias used by About / open URL helpers.
    static var currentAppUpdateInfo: LMAppUpdatePresentation? {
        currentAppUpdatePresentation
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
        // App Store Lookup no longer supplies review gating — keep normal for shipping builds.
        reviewState = .normal
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
                                     completion: (() -> Void)? = nil) {
        fetchAppUpdateClassification(forceRefresh: forceRefresh) { _ in
            completion?()
        }
    }

    static func queryVersionConfigs(forceRefresh: Bool = true,
                                    completeCallback: (() -> Void)? = nil) {
        queryAppUpdateStatus(forceRefresh: forceRefresh) {
            completeCallback?()
        }
    }

    static func refreshAppUpdateStatus(completion: ((Bool) -> Void)? = nil) {
        fetchAppUpdateClassification(forceRefresh: true) { _ in
            completion?(hasAvailableAppUpdate)
        }
    }

    static func presentCachedAppUpdateIfNeeded(from presenter: UIViewController) {
        guard let update = currentAppUpdatePresentation else { return }
        guard !isShowingUpdateAlert else { return }

        if update.isForce {
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
        guard let update = currentAppUpdatePresentation else {
            onContinue()
            return
        }
        guard !isShowingUpdateAlert else { return }

        let isForceUpdate = update.isForce
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

        let title = update.resolvedTitle
        let intro = isForceUpdate ? LMText.common.updateRequiredIntro : update.resolvedMessage
        let details = isForceUpdate ? update.resolvedMessage : update.resolvedDetails
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
                openUpdateURL(update.storeURL)
                if !isForceUpdate {
                    ignoredNonRequiredUpdateIdentity = update.updateIdentity
                    onContinue()
                }
                // Force: stay blocked until a later check sees a non-force local version.
            }
        ))

        dialog.show(onDismiss: {
            isShowingUpdateAlert = false
        })
    }

    static func openCurrentAvailableUpdateURL() {
        openUpdateURL(currentAppUpdatePresentation?.storeURL)
    }

    private static func fetchAppUpdateClassification(
        forceRefresh: Bool,
        completion: ((LMAppUpdateClass) -> Void)? = nil
    ) {
        if !forceRefresh,
           let cacheFetchedAt,
           Date().timeIntervalSince(cacheFetchedAt) < cacheTTL,
           cachedLookupResult != nil {
            completion?(cachedClassification)
            return
        }

        LMAppStoreLookupService.fetch { result in
            DispatchQueue.main.async {
                guard let result else {
                    LMLogger.log("⚠️ App Store Lookup failed — treating as no update")
                    cachedLookupResult = nil
                    cachedClassification = .none
                    cacheFetchedAt = Date()
                    completion?(.none)
                    return
                }

                let classification = LMAppVersionComparer.classify(
                    local: package.version,
                    store: result.storeVersion
                )
                cachedLookupResult = result
                cachedClassification = classification
                cacheFetchedAt = Date()
                LMLogger.log(
                    "📦 App Store Lookup: local=\(package.version) store=\(result.storeVersion) class=\(classification)"
                )
                completion?(classification)
            }
        }
    }

    private static func isIgnoredNonRequiredUpdate(_ update: LMAppUpdatePresentation) -> Bool {
        ignoredNonRequiredUpdateIdentity == update.updateIdentity
    }

    private static func showAppUpdateAlert(_ update: LMAppUpdatePresentation,
                                           from _: UIViewController) {
        guard !isShowingUpdateAlert else { return }
        isShowingUpdateAlert = true

        let isForceUpdate = update.isForce
        let title = update.resolvedTitle
        let message = update.resolvedMessage
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
                openUpdateURL(update.storeURL)
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
}

/// Dialog / badge model derived from App Store Lookup + semver classify.
struct LMAppUpdatePresentation {
    let isForce: Bool
    let storeVersion: String
    let localVersion: String
    let storeURL: String?
    let releaseNotes: String?

    init(isForce: Bool, lookup: LMAppStoreLookupResult, localVersion: String) {
        self.isForce = isForce
        self.storeVersion = lookup.storeVersion
        self.localVersion = localVersion
        self.storeURL = lookup.trackViewUrl.nonEmpty ?? AppConfigs.AppStore.updateURL
        self.releaseNotes = lookup.releaseNotes
    }

    var updateIdentity: String {
        "\(storeVersion)|\(storeURL ?? "")"
    }

    var resolvedTitle: String {
        isForce ? LMText.common.updateRequiredTitle : LMText.common.updateAvailableTitle
    }

    var resolvedMessage: String {
        if isForce {
            return String(
                format: LMText.common.updateRequiredMessageFormat,
                storeVersion,
                localVersion
            )
        }
        return String(
            format: LMText.common.updateAvailableMessageFormat,
            storeVersion,
            localVersion
        )
    }

    var resolvedDetails: String {
        let notes = releaseNotes?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if notes.isEmpty {
            return LMText.common.updateFallbackContent
        }
        if notes.count > 500 {
            return String(notes.prefix(500)) + "…"
        }
        return notes
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
