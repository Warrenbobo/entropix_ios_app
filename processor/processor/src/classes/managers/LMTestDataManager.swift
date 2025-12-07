//
//  LMTestDataManager.swift
//  processor
//
//  Created by muz on 2025-01-XX.
//  Copyright © 2025 processor. All rights reserved.
//

import Foundation
import UIKit

/// 全局测试数据管理类
/// 用于控制测试模式开关和提供模拟数据
class LMTestDataManager {
    
    // MARK: - Singleton
    static let shared = LMTestDataManager()
    private init() {}
    
    // MARK: - Test Mode Control
    
    /// 测试模式总开关
    /// 设置为 true 时，所有网络请求将返回模拟数据
    /// 设置为 false 时，使用真实网络请求
    var isTestModeEnabled: Bool = false
    
    /// 测试模式延迟时间（秒）
    /// 模拟网络请求的延迟，用于测试加载状态
    var testModeDelay: TimeInterval = 1.0
    
    // MARK: - Test User Data
    
    /// 测试用户 - 免费用户
    func testFreeUserInfo() -> LMUserInfo {
        return LMUserInfo(
            userId: "test_free_user_001",
            username: "freeuser",
            email: "free@test.com",
            subscription: nil,
            membership: nil
        )
    }
    
    /// 测试用户 - Plus订阅用户
    func testPlusUserInfo() -> LMUserInfo {
        return LMUserInfo(
            userId: "test_plus_user_001",
            username: "plususer",
            email: "plus@test.com",
            subscription: "plus",
            membership: "plus"
        )
    }
    
    /// 测试用户 - Lifelong订阅用户
    func testLifelongUserInfo() -> LMUserInfo {
        return LMUserInfo(
            userId: "test_lifelong_user_001",
            username: "lifelonguser",
            email: "lifelong@test.com",
            subscription: "lifelong",
            membership: "lifelong"
        )
    }
    
    /// 获取当前测试用户信息
    func getCurrentTestUserInfo() -> LMUserInfo {
        switch currentTestUserType {
        case .free:
            return testFreeUserInfo()
        case .plus:
            return testPlusUserInfo()
        case .lifelong:
            return testLifelongUserInfo()
        }
    }
    
    /// 获取当前测试用户的订阅类型
    func getCurrentSubscriptionType() -> String {
        switch currentTestUserType {
        case .free:
            return "free"
        case .plus:
            return "plus"
        case .lifelong:
            return "lifelong"
        }
    }
    
    /// 获取当前测试用户的Inspire Points
    func getCurrentInspirePoints() -> Int {
        switch currentTestUserType {
        case .free:
            return 3
        case .plus, .lifelong:
            return -1  // Unlimited
        }
    }
    
    /// 当前测试用户类型
    enum TestUserType {
        case free
        case plus
        case lifelong
    }
    
    /// 当前使用的测试用户类型
    var currentTestUserType: TestUserType = .free
    
    // MARK: - Test Authentication Data
    
    /// 测试登录响应
    func testLoginResponse() -> LMLoginResponse {
        return LMLoginResponse(
            accessToken: "test_access_token_\(UUID().uuidString)",
            refreshToken: "test_refresh_token_\(UUID().uuidString)",
            user: getCurrentTestUserInfo(),
            subscriptionType: getCurrentSubscriptionType(),
            inspirePoints: getCurrentInspirePoints()
        )
    }
    
    /// 测试注册响应
    func testRegisterResponse() -> LMUserRegisterResponse {
        return LMUserRegisterResponse(
            status: 200,
            message: "Registration successful. Please verify your email.",
            needEmailVerification: true,
            user: getCurrentTestUserInfo()
        )
    }
    
    /// 测试刷新Token响应
    func testRefreshTokenResponse() -> LMRefreshTokenResponse {
        return LMRefreshTokenResponse(
            accessToken: "test_access_token_\(UUID().uuidString)",
            refreshToken: "test_refresh_token_\(UUID().uuidString)"
        )
    }
    
    // MARK: - Test Composition Data
    
    /// 测试构图任务响应
    func testCompositionTaskResponse() -> LMCompositionTaskResponse {
        let taskId = "test_task_\(UUID().uuidString)"
        
        // 从 Assets.xcassets/sample 文件夹获取测试图片
        let sampleImages = loadSampleImages()
        
        // 生成16个相似构图建议
        var suggestions: [LMCompositionSuggestion] = []
        for i in 1...16 {
            // 循环使用 sample 图片
            let imageIndex = (i - 1) % sampleImages.count
            let sampleImage = sampleImages[imageIndex]
            
            // 根据图片实际尺寸计算宽高比
            let aspectRatio = sampleImage.size.width / sampleImage.size.height
            
            suggestions.append(LMCompositionSuggestion(
                id: "test_suggestion_\(i)",
                sceneType: "outdoor",
                source: "similar",
                ready: true,
                imageUrl: "sample_\(imageIndex + 1)", // 使用图片名称作为标识
                similarImageUrl: sampleImageNames[imageIndex],
                rank: i,
                score: Double.random(in: 0.7...0.95),
                modelVersion: "v1.0",
                aspectRatio: aspectRatio
            ))
        }
        
        // 在第4、8、12位置插入AIGC构图（未准备好）
        let aigcPositions = [3, 7, 11]
        for (index, position) in aigcPositions.enumerated() {
            if position < suggestions.count {
                // 为 AIGC 构图也使用 sample 图片的宽高比
                let imageIndex = index % sampleImages.count
                let sampleImage = sampleImages[imageIndex]
                let aspectRatio = sampleImage.size.width / sampleImage.size.height
                
                suggestions.insert(LMCompositionSuggestion(
                    id: "test_aigc_\(index + 1)",
                    sceneType: "outdoor",
                    source: "aigc",
                    ready: false,
                    imageUrl: nil,
                    similarImageUrl: nil,
                    rank: position + 1,
                    score: nil,
                    modelVersion: "v1.0",
                    aspectRatio: aspectRatio
                ), at: position)
            }
        }
        
        return LMCompositionTaskResponse(
            taskId: taskId,
            status: "processing",
            suggestions: suggestions
        )
    }
    
    // MARK: - Helper Methods for Test Data
    
    /// 随机生成 PersonBoundingBox
    /// - Returns: 随机的 BoundingBox，确保在合理范围内
    private func generateRandomPersonBoundingBox() -> BoundingBox {
        // x: 人物中心点的 x 坐标（0.2 - 0.8，避免太靠边）
        let x = Double.random(in: 0.2...0.8)
        
        // y: 人物中心点的 y 坐标（0.2 - 0.7，避免太靠上或太靠下）
        let y = Double.random(in: 0.2...0.7)
        
        // width: 人物宽度（0.25 - 0.5，占画面的 25%-50%）
        let width = Double.random(in: 0.25...0.5)
        
        // height: 人物高度（0.4 - 0.7，占画面的 40%-70%）
        let height = Double.random(in: 0.4...0.7)
        
        return BoundingBox(x: x, y: y, width: width, height: height)
    }
    
    // MARK: - Sample Image Names
    
    /// Sample 文件夹内的图片名称数组
    private let sampleImageNames: [String] = [
        "suggest_00000450",
        "suggest_00000082",
        "suggest_00000573",
        "suggest_00000574",
        "suggest_00000575",
        "suggest_00000582",
        "suggest_00000583",
        "suggest_00000584",
        "suggest_sample_1",
        "suggest_sample_2",
    ]
    
    /// 从 Assets.xcassets/sample 文件夹加载测试图片
    private func loadSampleImages() -> [UIImage] {
        var images: [UIImage] = []
        
        // 遍历图片名称数组加载图片
        for imageName in sampleImageNames {
            if let image = UIImage(named: imageName) {
                images.append(image)
                LMLogger.log("✅ Loaded sample image: \(imageName), size: \(image.size), aspect ratio: \(String(format: "%.2f", image.size.width / image.size.height))")
            }
        }
        
        // 如果没有找到任何图片，使用系统占位图
        if images.isEmpty {
            LMLogger.log("⚠️ No sample images found in Assets.xcassets/sample folder, using placeholder")
            if let placeholder = UIImage(systemName: "photo") {
                images.append(placeholder)
            }
        } else {
            LMLogger.log("✅ Loaded \(images.count) sample images from Assets.xcassets/sample folder")
        }
        
        return images
    }
    
    /// 获取 sample 图片名称数组
    func getSampleImageNames() -> [String] {
        return sampleImageNames
    }
    
    /// 根据图片名称获取 sample 图片
    func getSampleImage(named name: String) -> UIImage? {
        return UIImage(named: name)
    }
    
    /// 测试构图建议响应
    func testCompositionSuggestionsResponse() -> LMCompositionSuggestionsResponse {
        let taskResponse = testCompositionTaskResponse()
        return LMCompositionSuggestionsResponse(
            status: "completed",
            suggestions: taskResponse.suggestions
        )
    }
    
    /// 测试AIGC构图更新（模拟AIGC构图准备完成）
    func testAIGCCompositionsReady() -> [LMCompositionSuggestion] {
        // 从 Assets.xcassets/sample 文件夹获取测试图片
        let sampleImages = loadSampleImages()
        
        var aigcSuggestions: [LMCompositionSuggestion] = []
        
        // 生成3个AIGC构图
        for i in 1...3 {
            let imageIndex = (i - 1) % sampleImages.count
            let sampleImage = sampleImages[imageIndex]
            let aspectRatio = sampleImage.size.width / sampleImage.size.height
            
            aigcSuggestions.append(LMCompositionSuggestion(
                id: "test_aigc_\(i)",
                sceneType: "outdoor",
                source: "aigc",
                ready: true,
                imageUrl: "sample_\(imageIndex + 1)", // 使用图片名称作为标识
                similarImageUrl: nil,
                rank: i * 4, // 4, 8, 12
                score: Double.random(in: 0.85...0.95),
                modelVersion: "v1.0",
                aspectRatio: aspectRatio
            ))
        }
        
        return aigcSuggestions
    }
    
    /// 测试确认建议响应
    func testConfirmSuggestionResponse() -> LMConfirmSuggestionResponse {
        return LMConfirmSuggestionResponse(
            message: "Suggestion confirmed successfully"
        )
    }
    
    // MARK: - Test Gallery Data
    
    /// 测试构图历史结果列表
    func testCompositionResultsResponse() -> LMCompositionResultsResponse {
        var results: [LMCompositionResult] = []
        
        for i in 1...10 {
            results.append(LMCompositionResult(
                taskId: "test_task_\(i)",
                suggestionId: "test_suggestion_\(i)",
                imageUrl: "https://picsum.photos/1080/1440?random=result\(i)",
                sceneType: i % 2 == 0 ? "outdoor" : "indoor",
                rank: i,
                score: Double.random(in: 0.7...0.95),
                modelVersion: "v1.0",
                savedAt: Date().addingTimeInterval(-Double(i) * 24 * 3600).ISO8601Format()
            ))
        }
        
        return LMCompositionResultsResponse(results: results)
    }
    

    
    // MARK: - Helper Methods
    
    /// 模拟网络延迟执行
    func executeWithDelay<T>(_ completion: @escaping (T) -> Void, data: T) {
        DispatchQueue.main.asyncAfter(deadline: .now() + testModeDelay) {
            completion(data)
        }
    }
    

    
    /// 切换测试用户类型
    func switchTestUser(to type: TestUserType) {
        currentTestUserType = type
        print("🧪 Test Mode: Switched to \(type) user")
    }
    
    /// 打印测试模式状态
    func printTestModeStatus() {
        print("🧪 Test Mode: \(isTestModeEnabled ? "ENABLED" : "DISABLED")")
        print("🧪 Current Test User: \(currentTestUserType)")
        print("🧪 Test Delay: \(testModeDelay)s")
    }
    
    // MARK: - Inspire Me Data Recording
    
    private let inspireMeRecordsKey = "lm_inspire_me_records"
    private var inspireMeRecords: [LMInspireMeRecord] = []
    
    /// 记录 Inspire Me 数据
    func recordInspireMeData(sceneFeature: [Float]?, image: UIImage?) {
        let record = LMInspireMeRecord(
            sceneFeature: sceneFeature,
            image: image
        )
        
        inspireMeRecords.append(record)
        saveRecordsToUserDefaults()
        
        print("📝 Inspire Me Record saved: \(record.id)")
        print("   Scene Feature: \(String(describing: sceneFeature))")
        print("   Total Records: \(inspireMeRecords.count)")
    }
    
    /// 获取所有记录
    func getAllInspireMeRecords() -> [LMInspireMeRecord] {
        return inspireMeRecords
    }
    
    /// 清除所有记录
    func clearAllInspireMeRecords() {
        inspireMeRecords.removeAll()
        UserDefaults.standard.removeObject(forKey: inspireMeRecordsKey)
        print("🗑️ All Inspire Me records cleared")
    }
    
    /// 删除指定记录
    func deleteInspireMeRecord(id: String) {
        inspireMeRecords.removeAll { $0.id == id }
        saveRecordsToUserDefaults()
        print("🗑️ Inspire Me record deleted: \(id)")
    }
    
    /// 保存记录到 UserDefaults
    private func saveRecordsToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(inspireMeRecords) {
            UserDefaults.standard.set(encoded, forKey: inspireMeRecordsKey)
        }
    }
    
    /// 从 UserDefaults 加载记录
    func loadRecordsFromUserDefaults() {
        if let data = UserDefaults.standard.data(forKey: inspireMeRecordsKey),
           let decoded = try? JSONDecoder().decode([LMInspireMeRecord].self, from: data) {
            inspireMeRecords = decoded
            print("📂 Loaded \(inspireMeRecords.count) Inspire Me records")
        }
    }
}
