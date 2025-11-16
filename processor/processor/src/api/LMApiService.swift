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
    func register(username: String, email: String, password: String, completion: @escaping (LMApiResponseModel<LMUserInfo>) -> Void) {
        let params: [String: Any] = [
            "username": username,
            "email": email,
            "password": password,
            "provider": "local"
        ]
        
        LMApiClient.request(
            LMApi.User.register,
            method: .post,
            params: params,
            type: LMUserInfo.self,
            completeHandler: completion
        )
    }
    
    /// Apple 注册
    func registerWithApple(
        appleUid: String,
        idToken: String,
        email: String?,
        fullName: String?,
        completion: @escaping (LMApiResponseModel<LMUserRegisterResponse>) -> Void
    ) {
        var params: [String: Any] = [
            "provider": "apple",
            "apple_uid": appleUid,
            "apple_id_token": idToken
        ]
        
        if let email = email {
            params["apple_email"] = email
        }
        
        if let fullName = fullName {
            params["apple_full_name"] = fullName
        }
        
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
        let params: [String: Any] = [
            "identifier": identifier,
            "password": password,
            "provider": "",
        ]
        
        LMApiClient.request(
            LMApi.Auth.login,
            method: .post,
            params: params,
            type: LMLoginResponse.self,
            completeHandler: completion
        )
    }
    
    /// Apple 登录
    func loginWithApple(
        appleUid: String,
        idToken: String,
        email: String?,
        completion: @escaping (LMApiResponseModel<LMLoginResponse>) -> Void
    ) {
        let params: [String: Any] = [
            "provider": "apple",
            "apple_uid": appleUid,
            "username": "",
            "apple_id_token": idToken,
            "email": email ?? ""
        ]
        
        LMApiClient.request(
            LMApi.Auth.login,
            method: .post,
            params: params,
            type: LMLoginResponse.self,
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
            method: .put,  // ✅ 使用 PUT 方法
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
    
    /// 修改密码（需要旧密码）
    func changePassword(oldPassword: String, newPassword: String, completion: @escaping (LMApiResponseModel<LMEmptyModel>) -> Void) {
        let params: [String: Any] = [
            "old_password": oldPassword,
            "new_password": newPassword
        ]
        
        LMApiClient.request(
            LMApi.User.changePassword,
            method: .put,  // ✅ 使用 PUT 方法
            params: params,
            type: LMEmptyModel.self,
            completeHandler: completion
        )
    }
    
    /// 重置密码（忘记密码，不需要旧密码）
    func resetPassword(email: String, newPassword: String, completion: @escaping (LMApiResponseModel<LMEmptyModel>) -> Void) {
        let params: [String: Any] = [
            "email": email,
            "new_password": newPassword
        ]
        
        LMApiClient.request(
            LMApi.User.resetPassword,
            method: .post,  // ✅ 使用 POST 方法
            params: params,
            type: LMEmptyModel.self,
            completeHandler: completion
        )
    }
    
    /// 用户登出
    func logout(completion: @escaping (LMApiResponseModel<LMEmptyModel>) -> Void) {
        LMApiClient.request(
            LMApi.Auth.logout,
            method: .delete,  // ✅ 使用 DELETE 方法
            type: LMEmptyModel.self,
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
            "Platform": "iOS",
            "Channel": "AppStore",
            "Version": LMPackageManager.package.version,
//            "Model": LMPackageManager.package.model,
//            "PackageName": LMPackageManager.package.bundleName
        ]
        
        // Add Authorization token if available
        if let token = LMUserManager.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        return headers
    }
}
