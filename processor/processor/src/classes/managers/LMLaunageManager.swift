//
//  LMLaunageManager.swift
//  processor
//
//  Created by muz on 2025/11/1.
//

import Foundation

// MARK: - Language Type
enum LMLanguageType: String, Codable {
    case english = "en"
    case chinese = "zh"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }
}

// MARK: - Language Manager
class LMLaunageManager {
    
    // Singleton instance
    static let shared = LMLaunageManager()
    private(set) var currentLanguage: LMLanguageType = .english
    private var languageModel: LMLaunageModel?
    
    // Current language config
    private var currentConfig: LMAppLaunageConfig? {
        switch currentLanguage {
        case .english:
            return languageModel?.english
        case .chinese:
            return languageModel?.chinese
        }
    }
    
    // Notification for language change
    static let languageDidChangeNotification = Notification.Name("LMLanguageDidChange")
    
    private init() {
        loadLanguageData()
        loadSavedLanguage()
    }
    
    // MARK: - Public Methods
    
    /// Switch to a different language
    func switchLanguage(to language: LMLanguageType) {
        guard language != currentLanguage else { return }
        
        currentLanguage = language
        saveLanguage()
        NotificationCenter.default.post(name: Self.languageDidChangeNotification, object: nil)
    }
    
    // MARK: - Text Accessors
    var common: LMCommonTextConfig {
        return currentConfig?.common ?? LMCommonTextConfig()
    }
    
    var camera: LMCameraTextConfig {
        return currentConfig?.camera ?? LMCameraTextConfig()
    }
    
    var profile: LMProfileTextConfig {
        return currentConfig?.profile ?? LMProfileTextConfig()
    }
    
    var subscription: LMSubscriptionTextConfig {
        return currentConfig?.subscription ?? LMSubscriptionTextConfig()
    }
    
    var auth: LMAuthTextConfig {
        return currentConfig?.auth ?? LMAuthTextConfig()
    }
    
    var settings: LMSettingsTextConfig {
        return currentConfig?.settings ?? LMSettingsTextConfig()
    }
    
    // MARK: - Public Methods for Initialization
    func loadLanguageConfiguration() {
        loadLanguageData()
        loadSavedLanguage()
    }
    
    // MARK: - Private Methods
    private func loadLanguageData() {
        // 尝试从JSON文件加载配置
        if let model = loadLanguageFromJSON() {
            languageModel = model
            LMLogger.log("✅ Language configuration loaded from JSON")
            return
        }
        
        // 如果JSON加载失败，使用默认配置
        LMLogger.log("⚠️ Failed to load language JSON, using default configuration")
        loadDefaultLanguageData()
    }
    
    /// 从JSON文件加载语言配置
    private func loadLanguageFromJSON() -> LMLaunageModel? {
        guard let url = Bundle.main.url(forResource: "language_config", withExtension: "json") else {
            LMLogger.log("❌ language_config.json not found in bundle")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let model = try decoder.decode(LMLaunageModel.self, from: data)
            return model
        } catch {
            LMLogger.log("❌ Failed to decode language JSON: \(error)")
            return nil
        }
    }
    
    /// 加载默认语言配置（作为后备方案）
    private func loadDefaultLanguageData() {
        let englishConfig = LMAppLaunageConfig(
            common: LMCommonTextConfig(),
            camera: LMCameraTextConfig(),
            profile: LMProfileTextConfig(),
            subscription: LMSubscriptionTextConfig(),
            auth: LMAuthTextConfig(),
            settings: LMSettingsTextConfig()
        )
        let chineseConfig = LMAppLaunageConfig(
            common: LMCommonTextConfig(
                ok: "确定",
                cancel: "取消",
                save: "保存",
                back: "返回",
                done: "完成",
                edit: "编辑",
                delete: "删除",
                confirm: "确认",
                loading: "加载中...",
                error: "错误",
                success: "成功",
                retry: "重试",
                close: "关闭"
            ),
            camera: LMCameraTextConfig(
                flash: "闪光灯",
                ratio: "比例",
                timer: "定时器",
                live: "实时",
                grid: "网格",
                flipCamera: "翻转相机",
                arGuidance: "AR 引导",
                inspireMeButton: "灵感启发  ⓘ",
                inspirePointsFormat: "灵感点数 -%d",
                guidanceNotice: "使用 AI 引导前请先获取灵感",
                alignPersonFrame: "将人物对齐绿色框架",
                generating: "生成中...",
                generatingAISuggestions: "正在生成 AI 建议...",
                analyzingScene: "分析场景中...",
                allSuggestionsReady: "所有建议已就绪！",
                generationFailed: "生成失败，请重试。",
                generationTimeout: "生成超时，显示可用建议。",
                compositionSuggestions: "构图建议"
            ),
            profile: LMProfileTextConfig(
                profile: "个人资料",
                accountProfile: "账户资料",
                gallery: "图库",
                savedIdeas: "已保存的创意",
                plusPlan: "Plus 会员",
                freePlan: "免费版",
                unlimitedInspires: "无限灵感",
                limitedUsage: "有限使用",
                unlimited: "无限",
                inspirePoints: "灵感点数",
                watchAds: "观看广告",
                watchAdsWithIcon: "▶ 观看广告",
                upgrade: "升级",
                plusIndicator: "+5",
                fullName: "全名",
                username: "用户名",
                emailAddress: "电子邮箱",
                dateOfBirth: "出生日期",
                subscriptionType: "订阅类型",
                cancelSubscription: "取消订阅",
                editProfileData: "编辑资料",
                changePhoto: "更换照片",
                changePassword: "修改密码",
                camera: "相机",
                photoLibrary: "照片库",
                profileUpdated: "资料已更新",
                profileUpdatedMessage: "您的资料已成功更新。",
                cancelSubscriptionTitle: "取消订阅",
                cancelSubscriptionMessage: "确定要取消订阅吗？您将失去高级功能的访问权限。",
                keepSubscription: "保留订阅",
                subscriptionCancelled: "订阅已取消",
                subscriptionCancelledMessage: "您的订阅已成功取消。"
            ),
            subscription: LMSubscriptionTextConfig(
                subscriptionTitle: "订阅",
                limitedTimeOffer: "限时优惠倒计时：",
                days: "天",
                day: "天",
                hours: "小时",
                hour: "小时",
                minutes: "分钟",
                minute: "分钟",
                seconds: "秒",
                second: "秒",
                limitedSpotsAvailable: "限量名额：",
                spotsLeftFormat: "仅剩 %d 个名额！",
                unlimitedAISuggestions: "获取无限 AI 建议、高级功能和优先支持",
                autoRenewsMonthly: "每月自动续订，随时取消",
                freeInspirePoints: "新下载用户获得 3 个免费灵感点数",
                unlimitedInspirePoints: "无限灵感点数",
                aiInspiring: "AI 灵感启发",
                basicCamera: "基础相机",
                advancedCamera: "高级相机",
                prioritySupport: "优先支持",
                noAds: "无广告",
                startFreeTrial: "开始免费试用",
                subscribe: "订阅",
                continueWithFree: "继续使用免费版",
                giveUpFreeTrial: "放弃免费试用？",
                giveUp: "放弃",
                kContinue: "继续",
                watchAd: "观看广告",
                watchAdsToGetFree: "观看广告获得 5 次免费 AI 建议",
                selectAndContinue: "选择并继续",
                regenerate: "重新生成",
                oneTimePayment: "一次性付款，永久拥有",
                autoRenewNotice: "自动续订订阅将在当前周期结束前至少 24 小时自动续订，除非取消。",
                termsOfService: "服务条款",
                privacyPolicy: "隐私政策"
            ),
            auth: LMAuthTextConfig(
                signIn: "登录",
                email: "电子邮箱",
                password: "密码",
                forgotPassword: "忘记密码？",
                dontHaveAccount: "还没有账户？",
                signUp: "注册",
                createAccount: "创建账户",
                fullName: "全名",
                confirmPassword: "确认密码",
                alreadyHaveAccount: "已有账户？",
                resetPassword: "重置密码",
                sendResetLink: "发送重置链接",
                backToSignIn: "返回登录",
                emailRequired: "请输入电子邮箱",
                passwordRequired: "请输入密码",
                passwordMismatch: "密码不匹配",
                invalidEmail: "电子邮箱格式无效",
                signInSuccess: "登录成功",
                signUpSuccess: "账户创建成功",
                resetLinkSent: "重置链接已发送到您的邮箱",
                availableWithoutAccount: "无需账户即可使用",
                sessionExpired: "会话已过期",
                pleaseSignInAgain: "您的会话已过期，请重新登录",
                createAccountTitle: "创建账户",
                createAccountSubtitle: "加入我们，发现您的创造力",
                appName: "InspireCam",
                appTagline: "释放您的创意潜能",
                or: "或",
                passwordRequirement: "密码必须至少 8 个字符，包含\n至少一个数字和一个字母。",
                changing: "更改中...",
                loggingOut: "退出登录中...",
                logOut: "退出登录"
            ),
            settings: LMSettingsTextConfig(
                settings: "设置",
                account: "账户",
                general: "通用",
                about: "关于",
                accountProfile: "账户资料",
                changePassword: "修改密码",
                signOut: "退出登录",
                deleteAccount: "删除账户",
                language: "语言",
                notifications: "通知",
                cameraSettings: "相机设置",
                dataAndStorage: "数据与存储",
                appVersion: "应用版本",
                termsOfService: "服务条款",
                privacyPolicy: "隐私政策",
                contactUs: "联系我们",
                rateApp: "评价应用",
                shareApp: "分享应用",
                helpAndSupport: "帮助与支持",
                faq: "常见问题",
                contactSupport: "联系我们的支持团队获取个性化帮助。",
                getInTouch: "联系我们",
                connectCommunity: "与我们的社区联系",
                framAIstTeam: "FramAIst 团队",
                appDeveloper: "应用开发者",
                earnFreeUses: "赚取免费使用次数",
                downloaded: "已下载",
                selectLanguage: "选择语言",
                view: "查看",
                back: " 返回",
                goShot: "去拍摄",
                deleting: "删除中...",
                copied: "已复制！",
                joinDiscord: "加入我们的 Discord 频道",
                inviteLink: "邀请链接：",
                sendMessage: "直接给我们发送消息",
                needHelp: "需要帮助？",
                respondWithin24Hours: "我们通常在 24 小时内回复。",
                stillHaveQuestions: "还有问题？",
                accountProfileSubtitle: "管理您的账户设置",
                notificationSubtitle: "接收我们的系统通知",
                languageSubtitle: "更改应用内语言",
                contactUsSubtitle: "获取帮助和支持",
                frequentQuestionsSubtitle: "查找常见问题的答案",
                aboutSubtitle: "应用信息和支持",
                frequentQuestions: "常见问题",
                comingSoon: "即将推出",
                comingSoonMessage: "%@ 将在未来的更新中提供。",
                areYouSureLogout: "确定要退出登录吗？",
                unlockCreativePotential: "释放您的创意潜能",
                giveUpFreeTrialMessage: "当您切换到免费计划时，您将放弃此免费试用机会。在提供新优惠之前，您将无法再次获得免费试用。",
                welcomeToApp: "欢迎使用 InspireCam",
                signInToDiscover: "登录以发现完整功能",
                takePhotosStandard: "使用标准功能拍照",
                leftFormat: "剩余 %d",
                languageChangedSuccess: "语言已成功更改。所有文本将被更新。",
                switchToFormat: "切换到 %@？",
                signInWithEmail: "使用邮箱登录",
                termsAndPrivacy: "继续即表示您同意我们的服务条款和隐私政策",
                termsOfServiceLink: "服务条款",
                privacyPolicyLink: "隐私政策",
                noAccountPrompt: "还没有账户？注册",
                signUpLink: "注册"
            )
        )
        
        languageModel = LMLaunageModel(english: englishConfig, chinese: chineseConfig)
    }
    
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
    }
    
    private func loadSavedLanguage() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language"),
           let language = LMLanguageType(rawValue: savedLanguage) {
            currentLanguage = language
        }
    }
}

// MARK: - Convenience Accessor
let LMText = LMLaunageManager.shared
