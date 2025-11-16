//
//  LMTestDataManager.swift
//  processor
//
//  Created by Kiro on 2025-01-XX.
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
        
        // 生成16个相似构图建议
        var suggestions: [LMCompositionSuggestion] = []
        for i in 1...16 {
            suggestions.append(LMCompositionSuggestion(
                id: "test_suggestion_\(i)",
                sceneType: "outdoor",
                source: "similar",
                ready: true,
                imageUrl: "https://picsum.photos/1080/1440?random=\(i)",
                similarImageUrl: "https://picsum.photos/1080/1440?random=\(i)",
                rank: i,
                score: Double.random(in: 0.7...0.95),
                modelVersion: "v1.0",
                personBoundingBox: BoundingBox(
                    x: 0.3,
                    y: 0.2,
                    width: 0.4,
                    height: 0.6
                )
            ))
        }
        
        // 在第4、8、12位置插入AIGC构图（未准备好）
        let aigcPositions = [3, 7, 11]
        for (index, position) in aigcPositions.enumerated() {
            if position < suggestions.count {
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
                    personBoundingBox: nil
                ), at: position)
            }
        }
        
        return LMCompositionTaskResponse(
            taskId: taskId,
            status: "processing",
            suggestions: suggestions
        )
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
        return [
            LMCompositionSuggestion(
                id: "test_aigc_1",
                sceneType: "outdoor",
                source: "aigc",
                ready: true,
                imageUrl: "https://picsum.photos/1080/1440?random=aigc1",
                similarImageUrl: nil,
                rank: 4,
                score: 0.92,
                modelVersion: "v1.0",
                personBoundingBox: BoundingBox(
                    x: 0.25,
                    y: 0.15,
                    width: 0.5,
                    height: 0.7
                )
            ),
            LMCompositionSuggestion(
                id: "test_aigc_2",
                sceneType: "outdoor",
                source: "aigc",
                ready: true,
                imageUrl: "https://picsum.photos/1080/1440?random=aigc2",
                similarImageUrl: nil,
                rank: 8,
                score: 0.89,
                modelVersion: "v1.0",
                personBoundingBox: BoundingBox(
                    x: 0.3,
                    y: 0.2,
                    width: 0.4,
                    height: 0.6
                )
            ),
            LMCompositionSuggestion(
                id: "test_aigc_3",
                sceneType: "outdoor",
                source: "aigc",
                ready: true,
                imageUrl: "https://picsum.photos/1080/1440?random=aigc3",
                similarImageUrl: nil,
                rank: 12,
                score: 0.87,
                modelVersion: "v1.0",
                personBoundingBox: BoundingBox(
                    x: 0.35,
                    y: 0.25,
                    width: 0.3,
                    height: 0.5
                )
            )
        ]
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
