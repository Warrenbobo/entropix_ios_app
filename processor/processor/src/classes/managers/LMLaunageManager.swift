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
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "中文-简"
        case .traditionalChinese: return "中文-繁"
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
        case .simplifiedChinese:
            return languageModel?.simplifiedChinese
        case .traditionalChinese:
            return languageModel?.traditionalChinese
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
        let config = currentConfig?.settings ?? LMSettingsTextConfig()
        // Debug: Log FAQ count when accessed
        if config.faqs.isEmpty {
            LMLogger.log("⚠️ LMLaunageManager - settings.faqs is EMPTY!")
            LMLogger.log("⚠️ Current language: \(currentLanguage.displayName)")
            LMLogger.log("⚠️ Current config exists: \(currentConfig != nil)")
        } else {
            LMLogger.log("✅ LMLaunageManager - settings.faqs count: \(config.faqs.count)")
        }
        return config
    }
    
    var entrance: LMEntranceTextConfig {
        return currentConfig?.entrance ?? LMEntranceTextConfig()
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
            
            // Debug: Check FAQ data after decoding
            LMLogger.log("✅ JSON decoded successfully")
            if let englishFAQs = model.english?.settings?.faqs {
                LMLogger.log("✅ English FAQs count: \(englishFAQs.count)")
            } else {
                LMLogger.log("⚠️ English FAQs is nil or empty")
            }
            if let simplifiedFAQs = model.simplifiedChinese?.settings?.faqs {
                LMLogger.log("✅ Simplified Chinese FAQs count: \(simplifiedFAQs.count)")
            } else {
                LMLogger.log("⚠️ Simplified Chinese FAQs is nil or empty")
            }
            if let traditionalFAQs = model.traditionalChinese?.settings?.faqs {
                LMLogger.log("✅ Traditional Chinese FAQs count: \(traditionalFAQs.count)")
            } else {
                LMLogger.log("⚠️ Traditional Chinese FAQs is nil or empty")
            }
            
            return model
        } catch {
            LMLogger.log("❌ Failed to decode language JSON: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    LMLogger.log("❌ Key '\(key.stringValue)' not found: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    LMLogger.log("❌ Type mismatch for type \(type): \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    LMLogger.log("❌ Value not found for type \(type): \(context.debugDescription)")
                case .dataCorrupted(let context):
                    LMLogger.log("❌ Data corrupted: \(context.debugDescription)")
                @unknown default:
                    LMLogger.log("❌ Unknown decoding error")
                }
            }
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
            settings: LMSettingsTextConfig(),
            entrance: LMEntranceTextConfig()
        )
        let simplifiedChineseConfig = LMAppLaunageConfig(
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
	                close: "关闭",
	                newVersionAvailable: "有新版本了",
	                updateNow: "立即更新",
	                notNow: "暂不更新",
	                later: "稍后",
	                update: "更新",
	                exit: "退出",
	                updateAvailableTitle: "发现新版本",
	                updateRequiredTitle: "需要更新",
	                updateWhatsNew: "更新内容",
	                updateRequiredIntro: "为确保最佳体验：",
	                updateAvailableMessage: "发现新版本，更新以获得最新改进。",
	                updateRequiredMessage: "本次更新为强制更新，更新后才能继续使用。",
	                invalidUpdateUrl: "更新地址无效",
	                updateFallbackContent: "- 修复了一些已知问题。\n- 优化了交互体验。"
	            ),
            camera: LMCameraTextConfig(
                flash: "闪光灯",
                ratio: "比例",
                timer: "定时器",
                live: "实时",
                grid: "网格",
                flipCamera: "翻转相机",
                arGuidance: "AR 引导",
                inspireMeButton: "灵感启发",
                inspirePointsFormat: "灵感点数 -%d",
                guidanceNotice: "使用 AI 引导前请先获取灵感",
                alignPersonFrame: "将人物对齐绿色框架",
                generating: "生成中...",
                generatingAISuggestions: "正在生成 AI 建议...",
                analyzingScene: "分析场景中...",
                allSuggestionsReady: "所有建议已就绪！",
                generationFailed: "生成失败，请重试。",
                generationTimeout: "生成超时，显示可用建议。",
                processingInspiring: "Inspiring",
                virtualProgressScenery: "Scenery",
                virtualProgressPose: "Pose",
                virtualProgressAngle: "Angle",
                virtualProgressAnalyzing: "Analyzing...",
                virtualProgressGenerating: "Generating...",
                virtualProgressRating: "Rating...",
                virtualProgressLoading: "Loading...",
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
                getFreeTrial: "领取免费试用",
                freeTrialClaimed: "已领取免费试用",
                claimingFreeTrial: "领取中...",
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
                privacyPolicy: "隐私政策",
                trialExpiredTitle: "会员已到期",
                trialExpiredMessage: "您的会员已到期。领取免费试用以继续使用高级功能。",
                getFreeTrial: "领取免费试用",
                subscribeNow: "立即订阅",
                gotIt: "知道了"
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
                deleteAccountSubtitle: "提交注销申请",
                deleteAccountReminderTitle: "注销账户",
                deleteAccountReminderMessage: "注销账户将清除您的账户数据且不可恢复，是否继续？",
                deleteAccountConfirm: "确认注销",
                deleteAccountConfirmCountdownFormat: "确认注销(%ds)",
                deleteAccountRequestReceivedTitle: "已收到请求",
                deleteAccountRequestReceivedMessage: "已收到您的请求，将在48小时内审核并处理，请勿重复提交。",
                deleteAccountRequestReceivedConfirm: "知道了",
                deleteAccountReasonTitle: "请选择您注销账号的原因",
                deleteAccountReasonSubtitle: "您的反馈将帮助我们改进 AI 拍摄体验（单选）",
                deleteAccountReasonFeatureTitle: "功能还不够完善",
                deleteAccountReasonFeatureDetail: "AI 构图/灵感等功能仍有缺失或体验不稳定，影响拍摄效率。",
                deleteAccountReasonUsageTitle: "不会使用/上手困难",
                deleteAccountReasonUsageDetail: "功能较多，暂时没有找到合适的使用方式或拍摄场景。",
                deleteAccountReasonStopTitle: "暂时不想继续使用",
                deleteAccountReasonStopDetail: "近期拍摄需求减少或已改用其他工具。",
                deleteAccountReasonSecurityTitle: "担心账号与隐私安全",
                deleteAccountReasonSecurityDetail: "对账号安全或照片数据的存储方式有所顾虑。",
                deleteAccountNotice: "注销账号会导致您当前的账号无法继续使用，请您谨慎操作。我们会在您提交注销账号申请后的48小时内注销您的账号，我们不会留存您的任何信息。请您务必备份好自己的数据和信息，因注销账号导致的数据丢失，我们将无法为您恢复数据。",
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
                appStoreUpdateLink: "更新",
                privacyPolicyUnavailableMessage: "隐私政策内容暂时无法显示。",
                termsOfServiceUnavailableMessage: "服务条款内容暂时无法显示。",
                back: " 返回",
                goShot: "去拍摄",
                deleting: "删除中...",
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
            ),
            entrance: LMEntranceTextConfig(
                entropix: "Entropix",
                unleashCreativity: "释放您的摄影创意",
                noNetworkConnection: "未检测到网络连接。请检查您的网络设置并重启应用。",
                privacyPermission: "隐私权限",
                privacyDescription: "我们收集和使用您的数据来提供个性化服务、改进应用功能并增强您的体验。您的数据将被安全存储，未经您的同意不会与第三方共享。",
                agree: "同意",
                rejectAndExit: "拒绝并退出",
                viewPrivacyAndTerms: "查看我们的隐私政策和服务条款"
            )
        )
        let traditionalChineseConfig = simplifiedChineseConfig // Use same as simplified for now, will be loaded from JSON
        
        languageModel = LMLaunageModel(english: englishConfig, simplifiedChinese: simplifiedChineseConfig, traditionalChinese: traditionalChineseConfig)
    }
    
    private func saveLanguage() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: "app_language")
    }
    
    private func loadSavedLanguage() {
        // 首先检查是否有用户保存的语言偏好
        if let savedLanguage = UserDefaults.standard.string(forKey: "app_language") {
            // Migration: map old "zh" to new "zh-Hans" for existing users
            let languageCode = savedLanguage == "zh" ? "zh-Hans" : savedLanguage
            
            if let language = LMLanguageType(rawValue: languageCode) {
                currentLanguage = language
                
                // Update saved preference if migration occurred
                if savedLanguage == "zh" {
                    saveLanguage()
                    LMLogger.log("✅ Migrated language preference from 'zh' to 'zh-Hans'")
                }
                
                LMLogger.log("✅ Loaded saved language preference: \(language.displayName)")
                return
            }
        }
        
        // 如果没有保存的语言偏好，根据设备语言设置默认语言
        let defaultLanguage = getDefaultLanguageFromDevice()
        currentLanguage = defaultLanguage
        LMLogger.log("✅ Set default language based on device: \(defaultLanguage.displayName)")
    }
    
    /// 根据设备语言获取默认语言
    /// 如果设备语言是中文（简体或繁体），返回中文；否则返回英文
    private func getDefaultLanguageFromDevice() -> LMLanguageType {
        // 获取设备首选语言列表
//        let preferredLanguages = Locale.preferredLanguages
//        
//        // 检查首选语言是否包含中文
//        for languageCode in preferredLanguages {
//            let lowercased = languageCode.lowercased()
//            // 检查是否是中文语言代码
//            // zh-Hans: 简体中文, zh-Hant: 繁体中文, zh-CN: 中国大陆, zh-TW: 台湾, zh-HK: 香港
//            if lowercased.hasPrefix("zh") {
//                LMLogger.log("📱 Device language detected as Chinese: \(languageCode)")
//                return .chinese
//            }
//        }
        
        // 默认返回英文
        LMLogger.log("📱 Device language is not Chinese, defaulting to English")
        return .english
    }
}

// MARK: - Convenience Accessor
let LMText = LMLaunageManager.shared
