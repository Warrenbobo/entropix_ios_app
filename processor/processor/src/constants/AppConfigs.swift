//
//  AppConfigs.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import Foundation

struct AppConfigs {
    
    struct Host {
        
        static func path() -> String {
            return release
        }
        
        static let mvpTest = "http://47.111.152.147:8888"
        
        static let release = "https://framaist.entropixai.com"
    }
    
    /// AdMob placement IDs. Study builds use Google demo units; replace before Release.
    struct GoogleAdConfigs {
        /// AdMob App ID (`GADApplicationIdentifier` in Info.plist).
        static let appid = "ca-app-pub-3940256099942544~1458002511"
        /// Rewarded video (deferred — unused in App Open / Banner study).
        static let rewardVideoAdId = ""
        /// App Open: after splash/open page appears, before Camera (first page).
        static let appOpenAdId = "ca-app-pub-3940256099942544/5575463023"
        /// Banner: Mine page (`LMMinePage`) only.
        static let bannerAdId = "ca-app-pub-3940256099942544/2435281174"
    }
    
    struct AppStore {
        static let updateURL = "https://apps.apple.com/app/id6757949319"
    }

    /// Assets directory containing demo suggestion images for offline mode.
    static let demoSuggestionsDir = "demo_suggestions"

    struct Assets {
        static let watermarkBrand = "watermark_brand"
        static let arGuidanceBox = "box_focus_icon"
        static let arGuidanceLineArt = "pose_icon"
        static let tutorialScene = "tutorial_scene"
        static let tutorialTapLeft = "tutorial_tap_left"
        static let tutorialTapRight = "tutorial_tap_right"
        static let tutorialSelectLeft = "tutorial_select_left"
        static let tutorialSelectRight = "tutorial_select_right"
        static let tutorialAlign = "tutorial_align"
        static let tutorialSave = "tutorial_save"
    }

    /// Agent LLM + composition calibration defaults (aligned with Android `assets/config/app_config.json`).
    struct AgentLLM {
        static let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"
        static let apiKey = "sk-d50d7d95f0224783916ea419ab91971e"
        static let modelName = "qwen3.5-397b-a17b"
        static let thinkingBudget = 64
        static let imageDataURLMime = "image/jpeg"
        static let imageDataURLQuality = 85

        /// Bundled prompt manifest under `resources/config/`.
        static let promptsJSON = "prompts"
        static let systemPromptAssetPath = "config/system_prompt_agentic_v3.txt"
        static let userPromptPlaceholder =
            "【PreviewTask 调试专用静态 prompt】第一张图为参考图（风格目标），第二张图为当前相机实景（Current View）。Camera 页 Agent 模式使用代码动态生成的 user prompt，不读取本字段。"

        /// EVA02 raw-cosine → displayed S_global mapping (`global_structure_calibration`).
        struct GlobalStructureCalibration {
            static let tNeg: Float = 0.24
            static let tLo: Float = 0.25
            static let tHi: Float = 0.70
            static let sNeg: Float = 0.4
            static let sLo: Float = 0.50
            static let sHi: Float = 0.96
            static let aboveHiTau: Float = 0.08
            static let sameSceneGamma: Float = 0.85
        }
    }
}
