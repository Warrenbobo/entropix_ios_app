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
}
