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
    
    /// 广告位配置
    struct GoogleAdConfigs {
        // appid
        static let appid = ""
        // 激励视频广告
        static let rewardVideoAdId = ""
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

    /**
     Compile-time Gemini defaults for Inspire Me direct path (SPEC §5 / §7).

     User secrets live in `LMGeminiModelSettingsStore` (Keychain) — never here.
     */
    struct Gemini {
        static let defaultBaseURL = "https://generativelanguage.googleapis.com"
        /// Flip to `v1` in one place if QA requires it.
        static let apiVersion = "v1beta"
        static let defaultImageSize = "1K"
        static let flashTimeout: TimeInterval = 120
        static let proTimeout: TimeInterval = 180
        static let inputMaxLongSide: CGFloat = 1024
        static let inspirePromptAssetPath = "config/gemini_inspire_prompt.txt"
        static let cacheDirectoryName = "inspire_gemini"
        static let placeholderCount = 4
    }

    /**
     Agent LLM compile-time helpers for AR Guidance.

     Base URL and model name are user-configured (Models → AR Guidance / `model_config.json`);
     do not ship DashScope or other provider defaults here.
     */
    struct AgentLLM {
        /// Intentionally empty — configure via Models → AR Guidance.
        static let defaultBaseURL = ""
        /// Intentionally empty — configure via Models → AR Guidance.
        static let modelName = ""
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
