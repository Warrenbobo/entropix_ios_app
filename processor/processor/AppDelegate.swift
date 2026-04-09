//
//  AppDelegate.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import UIKit
import CoreData
//import ApiInspector

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
//        let config = ApiInspectorConfig.config(
//            domains: [ApiInspectorDomain(name: "生产环境", url: AppConfigs.Host.release)],
//            enableDomainSwitch: false,
//            enableRequestLog: true,
//            enableWebDebug: false
//        )
//        ApiInspector.shared.delegate = self
//        ApiInspector.shared.start(with: config)
        
        // Initialize StoreKit 2 manager
//        Task {
//            await LMStoreManager.shared.initialize()
//        }
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

}

//extension AppDelegate: ApiInspectorDelegate {
//    
//    func apiInspector(_ inspector: ApiInspector, didSelectCustomMenuItemWithActionType actionType: String) {
//        
//    }
//}
