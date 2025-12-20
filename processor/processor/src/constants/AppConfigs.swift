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
}
