//
//  LMLaunageModel.swift
//  processor
//
//  Created by muz on 2025/11/1.
//

import Foundation

struct LMLaunageModel: Codable {
    
    var english: LMAppLaunageConfig?
    var chinese: LMAppLaunageConfig?
}

struct LMAppLaunageConfig: Codable {
    
    var installer: LMAppTextConfig?
}


struct LMAppTextConfig: Codable {
    
    
}
