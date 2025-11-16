//
//  LMTestModeConfig.swift
//  processor
//
//  测试模式配置
//  在此文件中快速启用/禁用测试模式
//

import Foundation

/// 测试模式配置类
/// 用于快速启用/禁用测试模式和配置测试参数
class LMTestModeConfig {
    
    /// 配置测试模式
    /// 在应用启动时调用此方法
    static func configure() {
//        // ⚠️ 生产环境必须设置为 false
//        #if DEBUG
        enableTestMode()
//        #else
//        disableTestMode()
//        #endif
    }
    
    /// 启用测试模式
    private static func enableTestMode() {
        let testManager = LMTestDataManager.shared
        
        // 🧪 启用测试模式
        testManager.isTestModeEnabled = true
        
        // ⏱️ 设置测试延迟（秒）
        testManager.testModeDelay = 1.0
        
        // 👤 设置默认测试用户类型
        // .free - 免费用户（3次Inspire Points）
        // .plus - Plus订阅用户（无限Inspire Points，25天后到期）
        // .lifelong - Lifelong订阅用户（无限Inspire Points，永久有效）
        testManager.currentTestUserType = .free
        
        // 📊 打印测试模式状态
        testManager.printTestModeStatus()
        
        print("✅ Test Mode Enabled - Using mock data for all API calls")
        print("⚠️ Remember to disable test mode before release!")
    }
    
    /// 禁用测试模式
    private static func disableTestMode() {
        LMTestDataManager.shared.isTestModeEnabled = false
        print("✅ Test Mode Disabled - Using real API calls")
    }
    
    // MARK: - Quick Test User Switching
    
    /// 快速切换到免费用户
    static func switchToFreeUser() {
        LMTestDataManager.shared.switchTestUser(to: .free)
    }
    
    /// 快速切换到Plus用户
    static func switchToPlusUser() {
        LMTestDataManager.shared.switchTestUser(to: .plus)
    }
    
    /// 快速切换到Lifelong用户
    static func switchToLifelongUser() {
        LMTestDataManager.shared.switchTestUser(to: .lifelong)
    }
    
    // MARK: - Test Scenarios
    
    /// 测试场景1：新用户注册流程
    static func setupNewUserScenario() {
        let testManager = LMTestDataManager.shared
        testManager.isTestModeEnabled = true
        testManager.currentTestUserType = .free
        testManager.testModeDelay = 0.5
        print("🧪 Test Scenario: New User Registration")
    }
    
    /// 测试场景2：订阅用户使用流程
    static func setupSubscriberScenario() {
        let testManager = LMTestDataManager.shared
        testManager.isTestModeEnabled = true
        testManager.currentTestUserType = .plus
        testManager.testModeDelay = 0.5
        print("🧪 Test Scenario: Subscriber Usage")
    }
    
    /// 测试场景3：构图功能测试
    static func setupCompositionTestScenario() {
        let testManager = LMTestDataManager.shared
        testManager.isTestModeEnabled = true
        testManager.currentTestUserType = .free
        testManager.testModeDelay = 1.0
        print("🧪 Test Scenario: Composition Feature")
    }
    
    /// 测试场景4：快速响应（无延迟）
    static func setupFastResponseScenario() {
        let testManager = LMTestDataManager.shared
        testManager.isTestModeEnabled = true
        testManager.testModeDelay = 0
        print("🧪 Test Scenario: Fast Response (No Delay)")
    }
    
    /// 测试场景5：慢速网络模拟
    static func setupSlowNetworkScenario() {
        let testManager = LMTestDataManager.shared
        testManager.isTestModeEnabled = true
        testManager.testModeDelay = 3.0
        print("🧪 Test Scenario: Slow Network (3s delay)")
    }
}

// MARK: - AppDelegate Integration Example
/*
 在 AppDelegate.swift 中添加：
 
 func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
     
     // 配置测试模式
     LMTestModeConfig.configure()
     
     // 或者使用特定测试场景
     // LMTestModeConfig.setupNewUserScenario()
     // LMTestModeConfig.setupSubscriberScenario()
     // LMTestModeConfig.setupCompositionTestScenario()
     
     return true
 }
 */

// MARK: - Debug Menu Integration Example
/*
 在调试菜单或设置页面中添加：
 
 // 测试模式开关
 Toggle("Test Mode", isOn: Binding(
     get: { LMTestDataManager.shared.isTestModeEnabled },
     set: { LMTestDataManager.shared.isTestModeEnabled = $0 }
 ))
 
 // 测试用户类型选择
 Picker("Test User Type", selection: $selectedUserType) {
     Text("Free User").tag(LMTestDataManager.TestUserType.free)
     Text("Plus User").tag(LMTestDataManager.TestUserType.plus)
     Text("Lifelong User").tag(LMTestDataManager.TestUserType.lifelong)
 }
 .onChange(of: selectedUserType) { newValue in
     LMTestDataManager.shared.currentTestUserType = newValue
 }
 
 // 测试延迟设置
 Slider(value: Binding(
     get: { LMTestDataManager.shared.testModeDelay },
     set: { LMTestDataManager.shared.testModeDelay = $0 }
 ), in: 0...5, step: 0.5) {
     Text("Test Delay: \(LMTestDataManager.shared.testModeDelay, specifier: "%.1f")s")
 }
 */
