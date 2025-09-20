//
//  LMPackageModel.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import Foundation

struct LMPackageModel {
    
    // app版本
    var version: String = ""
    // build
    var build: String = ""
    // app包名
    var bundleName: String = ""
    // 系统版本
    var release: String = ""
    // idfa
    var idfa: String = ""
    // model
    var model: String = ""
    // uuid
    var uuid: String = ""
    
    /// 初始数据
    static func defaultModel() -> LMPackageModel {
        return LMPackageModel()
    }
}
