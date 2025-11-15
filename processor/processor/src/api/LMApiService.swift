//
//  LMApiService.swift
//  processor
//
//  API 服务封装
//

import Foundation
import Alamofire

class LMApiService {
    
    // MARK: - Singleton
    static let shared = LMApiService()
    private init() {}
    
    // MARK: - User APIs
    
    /// 用户注册（邮箱+密码）
    func register(email: String, password: String, name: String?, completion: @escaping (LMApiResponseModel<LMUserRegisterResponse>) -> Void) {
        let deviceInfo = LMPackageManager.getDeviceInfo()
        
        let params: [String: Any] = [
            "email": email,
            "password": password,
            "name": name ?? "",
            "device_info": [
                "device_id": deviceInfo.deviceId,
                "device_model": deviceInfo.deviceModel,
                "system_version": deviceInfo.systemVersion,
                "app_version": deviceInfo.appVersion
            ]
        ]
        
        LMApiClient.request(
            LMApi.User.register,
            method: .post,
            params: params,
            type: LMUserRegisterResponse.self,
            completeHandler: completion
        )
    }
    
    /// 用户登录（邮箱+密码）
    func login(identifier: String, password: String, completion: @escaping (LMApiResponseModel<LMLoginResponse>) -> Void) {
        let deviceInfo = LMPackageManager.getDeviceInfo()
        
        let params: [String: Any] = [
            "identifier": identifier,
            "password": password,
            "device_info": [
                "device_id": deviceInfo.deviceId,
                "device_model": deviceInfo.deviceModel,
                "system_version": deviceInfo.systemVersion,
                "app_version": deviceInfo.appVersion
            ]
        ]
        
        LMApiClient.request(
            LMApi.Auth.login,
            method: .post,
            params: params,
            type: LMLoginResponse.self,
            completeHandler: completion
        )
    }
    
    /// Apple登录/注册
    func appleLogin(uid: String, fullName: String?, email: String?, idToken: String, completion: @escaping (LMApiResponseModel<LMAppleLoginResponse>) -> Void) {
        let deviceInfo = LMPackageManager.getDeviceInfo()
        
        let params: [String: Any] = [
            "provider": "apple",
            "uid": uid,
            "full_name": fullName ?? "",
            "email": email ?? "",
            "id_token": idToken,
//            "device_info": [
//                "device_id": deviceInfo.deviceId,
//                "device_model": deviceInfo.deviceModel,
//                "system_version": deviceInfo.systemVersion,
//                "app_version": deviceInfo.appVersion
//            ]
        ]
        
        LMApiClient.request(
            LMApi.Auth.appleLogin,
            method: .post,
            params: params,
            type: LMAppleLoginResponse.self,
            completeHandler: completion
        )
    }
    
    /// 发送邮箱验证码
    func sendEmailVerification(email: String, completion: @escaping (LMApiResponseModel<LMEmailVerificationResponse>) -> Void) {
        let params: [String: Any] = [
            "email": email
        ]
        
        LMApiClient.request(
            LMApi.Auth.sendEmailVerification,
            method: .post,
            params: params,
            type: LMEmailVerificationResponse.self,
            completeHandler: completion
        )
    }
    
    /// 验证邮箱验证码
    func verifyEmailCode(email: String, code: String, completion: @escaping (LMApiResponseModel<LMEmailVerificationResponse>) -> Void) {
        let params: [String: Any] = [
            "email": email,
            "verification_code": code
        ]
        
        LMApiClient.request(
            LMApi.Auth.verifyEmailCode,
            method: .post,
            params: params,
            type: LMEmailVerificationResponse.self,
            completeHandler: completion
        )
    }
    
    /// 重新发送验证邮件
    func resendEmailVerification(email: String, completion: @escaping (LMApiResponseModel<LMEmailVerificationResponse>) -> Void) {
        let params: [String: Any] = [
            "email": email
        ]
        
        LMApiClient.request(
            LMApi.Auth.resendEmailVerification,
            method: .post,
            params: params,
            type: LMEmailVerificationResponse.self,
            completeHandler: completion
        )
    }
    
    /// 会话验证
    func validateSession(completion: @escaping (LMApiResponseModel<EmptyResponse>) -> Void) {
        let deviceInfo = LMPackageManager.getDeviceInfo()
        
        let params: [String: Any] = [
            "device_id": deviceInfo.deviceId
        ]
        
        LMApiClient.request(
            LMApi.Auth.validateSession,
            method: .get,
            params: params,
            type: EmptyResponse.self,
            completeHandler: completion
        )
    }
    
    /// 刷新 Token
    func refreshToken(refreshToken: String, completion: @escaping (LMApiResponseModel<LMRefreshTokenResponse>) -> Void) {
        let params: [String: Any] = [
            "refresh_token": refreshToken
        ]
        
        LMApiClient.request(
            LMApi.Auth.refreshToken,
            method: .post,
            params: params,
            type: LMRefreshTokenResponse.self,
            completeHandler: completion
        )
    }
    
    /// 获取当前用户信息
    func getUserInfo(completion: @escaping (LMApiResponseModel<LMUserInfo>) -> Void) {
        LMApiClient.request(
            LMApi.User.info,
            method: .get,
            type: LMUserInfo.self,
            completeHandler: completion
        )
    }
    
    /// 修改密码
    func changePassword(oldPassword: String, newPassword: String, completion: @escaping (LMApiResponseModel<EmptyResponse>) -> Void) {
        let params: [String: Any] = [
            "old_password": oldPassword,
            "new_password": newPassword
        ]
        
        LMApiClient.request(
            LMApi.User.changePassword,
            method: .post,
            params: params,
            type: EmptyResponse.self,
            completeHandler: completion
        )
    }
    
    /// 用户登出
    func logout(completion: @escaping (LMApiResponseModel<EmptyResponse>) -> Void) {
        LMApiClient.request(
            LMApi.Auth.logout,
            method: .post,
            type: EmptyResponse.self,
            completeHandler: completion
        )
    }
    
    // MARK: - Composition APIs
    
    /// 提交构图任务
    func submitCompositionTask(
        originalImage: UIImage,
        optimizedImage: UIImage,
        embeddings: [Float],
        aspectRatio: String,
        sceneType: String?,
        completion: @escaping (LMApiResponseModel<LMCompositionTaskResponse>) -> Void
    ) {
        guard let originalImageData = originalImage.jpegData(compressionQuality: 0.9),
              let optimizedImageData = optimizedImage.jpegData(compressionQuality: 0.9) else {
            LMLogger.log("❌ Failed to convert images to data")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let createdAt = dateFormatter.string(from: Date())
        
        let embeddingsJSON = try? JSONSerialization.data(withJSONObject: embeddings)
        let embeddingsString = embeddingsJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        
        let url = AppConfigs.Host.path() + LMApi.Composition.analyze
        
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(originalImageData, withName: "file", fileName: "scene.jpg", mimeType: "image/jpeg")
            multipartFormData.append(optimizedImageData, withName: "optimized_file", fileName: "scene_optimized.jpg", mimeType: "image/jpeg")
            
            if let aspectRatioData = aspectRatio.data(using: .utf8) {
                multipartFormData.append(aspectRatioData, withName: "aspect_ratio")
            }
            
            if let sceneType = sceneType, let sceneTypeData = sceneType.data(using: .utf8) {
                multipartFormData.append(sceneTypeData, withName: "scene_type")
            }
            
            if let createdAtData = createdAt.data(using: .utf8) {
                multipartFormData.append(createdAtData, withName: "created_at")
            }
            
            if let embeddingsData = embeddingsString.data(using: .utf8) {
                multipartFormData.append(embeddingsData, withName: "embeddings")
            }
        }, to: url, headers: LMApiClient.defaultHTTPHeaders())
        .responseDecodable(of: LMApiResponseModel<LMCompositionTaskResponse>.self) { response in
            LMLogger.log("📤 Composition task submitted")
            
            if let error = response.error {
                LMLogger.log("❌ Upload error: \(error)")
                var errorResponse = LMApiResponseModel<LMCompositionTaskResponse>.error(of: response.response?.statusCode, requestError: error)
                errorResponse.rawData = response.data
                completion(errorResponse)
                return
            }
            
            guard var responseValue = response.value else {
                LMLogger.log("❌ Failed to parse response")
                var emptyResponse = LMApiResponseModel<LMCompositionTaskResponse>.empty()
                emptyResponse.rawData = response.data
                completion(emptyResponse)
                return
            }
            
            responseValue.rawData = response.data
            completion(responseValue)
        }
    }
    
    /// 获取任务建议图
    func getSuggestions(taskId: String, completion: @escaping (LMApiResponseModel<LMCompositionSuggestionsResponse>) -> Void) {
        LMApiClient.request(
            LMApi.Composition.suggestions(taskId: taskId),
            method: .get,
            type: LMCompositionSuggestionsResponse.self,
            completeHandler: completion
        )
    }
    
    /// 分页获取历史构图结果
    func getCompositionResults(page: Int = 1, number: Int = 4, completion: @escaping (LMApiResponseModel<LMCompositionResultsResponse>) -> Void) {
        let params: [String: Any] = [
            "page": page,
            "number": number
        ]
        
        LMApiClient.request(
            LMApi.Composition.results,
            method: .get,
            params: params,
            type: LMCompositionResultsResponse.self,
            completeHandler: completion
        )
    }
    
    /// 确认建议图
    func confirmSuggestion(taskId: String, suggestionId: String, completion: @escaping (LMApiResponseModel<LMConfirmSuggestionResponse>) -> Void) {
        let params: [String: Any] = [
            "task_id": taskId,
            "suggestion_id": suggestionId
        ]
        
        LMApiClient.request(
            LMApi.Composition.confirm,
            method: .post,
            params: params,
            type: LMConfirmSuggestionResponse.self,
            completeHandler: completion
        )
    }
}

// MARK: - LMApiClient Extension for Headers
extension LMApiClient {
    static func defaultHTTPHeaders() -> HTTPHeaders {
        var headers: HTTPHeaders = [
            "Content-Type": "application/json",
            "platform": "iOS",
            "channel": "appstore",
            "Version": LMPackageManager.package.version,
            "model": LMPackageManager.package.model,
            "PackageName": LMPackageManager.package.bundleName
        ]
        
        // Add Authorization token if available
        if let token = LMUserManager.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        return headers
    }
}
