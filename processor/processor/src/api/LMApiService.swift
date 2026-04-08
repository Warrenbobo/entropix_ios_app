//
//  LMApiService.swift
//  processor
//
//

import Foundation
import Alamofire

class LMApiService {
    
    // MARK: - Singleton
    static let shared = LMApiService()
    private init() {}
    
    // MARK: - User APIs
    
    /// 用户注册（邮箱+密码）
    func register(username: String, email: String, password: String, completion: @escaping LMApiCallback<LMUserModel>) {
        let params: [String: Any] = [
            "username": username,
            "email": email,
            "password": password
        ]
        
        LMApiClient.request(
            LMApi.User.register,
            method: .post,
            params: params,
            type: LMUserModel.self,
            completeHandler: completion
        )
    }
    
    /// Apple 注册
    /// 根据接口文档：POST /v1/auth/apple/users
    func registerWithApple(
        appleUid: String,
        idToken: String,
        email: String?,
        fullName: String?,
        username: String?,
        deviceId: String?,
        completion: @escaping LMApiCallback<LMUserModel>
    ) {
        var params: [String: Any] = [
            "apple_uid": appleUid,
            "apple_id_token": idToken
        ]
        
        if let email = email {
            params["apple_email"] = email
        }
        if let fullName = fullName {
            params["apple_full_name"] = fullName
        }
        if let username = username {
            params["username"] = username
        }
        if let deviceId = deviceId {
            params["device_id"] = deviceId
        }
        
        LMApiClient.request(
            LMApi.Auth.appleRegister,
            method: .post,
            params: params,
            type: LMUserModel.self,
            completeHandler: completion
        )
    }
    
    /// 用户登录（邮箱+密码）
    func login(identifier: String, password: String, completion: @escaping LMApiCallback<LMLoginResponse>) {
        let params: [String: Any] = [
            "identifier": identifier,
            "password": password
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
    /// 根据接口文档：POST /v1/auth/apple/tokens
    func loginWithApple(
        appleUid: String,
        idToken: String,
        completion: @escaping LMApiCallback<LMLoginResponse>
    ) {
        let params: [String: Any] = [
            "apple_uid": appleUid,
            "apple_id_token": idToken
        ]
        
        LMApiClient.request(
            LMApi.Auth.appleLogin,
            method: .post,
            params: params,
            type: LMLoginResponse.self,
            completeHandler: completion
        )
    }
    
    /// 刷新 Token
    func refreshToken(refreshToken: String, completion: @escaping LMApiCallback<LMLoginResponse>) {
        let params: [String: Any] = [
            "refresh_token": refreshToken
        ]
        LMApiClient.request(
            LMApi.Auth.refreshToken,
            method: .put,
            params: params,
            type: LMLoginResponse.self,
            completeHandler: completion
        )
    }
    
    /// 获取当前用户信息
    func getUserInfo(completion: @escaping LMApiCallback<LMUserModel>) {
        LMApiClient.request(
            LMApi.User.info,
            method: .get,
            type: LMUserModel.self,
            completeHandler: completion
        )
    }
    
    /// 修改密码（需要旧密码）
    func changePassword(oldPassword: String, newPassword: String, completion: @escaping LMApiCallback<LMEmptyModel>) {
        let params: [String: Any] = [
            "old_password": oldPassword,
            "new_password": newPassword
        ]
        
        LMApiClient.request(
            LMApi.User.changePassword,
            method: .put,
            params: params,
            type: LMEmptyModel.self,
            completeHandler: completion
        )
    }
    
    /// 更新用户资料
    func updateProfile(
        username: String?,
        nickname: String?,
        language: String?,
        dateOfBirth: String?,
        completion: @escaping LMApiCallback<LMUserModel>
    ) {
        var params: [String: Any] = [:]
        
        if let username = username {
            params["username"] = username
        }
        if let nickname = nickname {
            params["nickname"] = nickname
        }
        if let language = language {
            params["language"] = language
        }
        if let dateOfBirth = dateOfBirth {
            params["date_of_birth"] = dateOfBirth
        }
        
        LMApiClient.request(
            LMApi.User.updateProfile,
            method: .patch,
            params: params,
            type: LMUserModel.self,
            completeHandler: completion
        )
    }
    
    /// 更新用户头像
    func updateAvatar(image: UIImage, completion: @escaping LMApiCallback<LMUserModel>) {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            var errorResponse = LMApiResponseModel<LMUserModel>.empty()
            errorResponse.message = "Failed to convert image to JPEG data"
            completion(errorResponse)
            return
        }
        
        let url = AppConfigs.Host.path() + LMApi.User.updateAvatar
        DispatchQueue.global().async {
            AF.upload(multipartFormData: { multipartFormData in
                multipartFormData.append(imageData, withName: "avatar", fileName: "avatar.jpg", mimeType: "image/jpeg")
            },
                      to: url,
                      method: .put,
                      headers: LMApiClient.uploadHTTPHeaders())
            .responseDecodable(of: LMApiResponseModel<LMUserModel>.self) { response in
                self.logUploadRequest(url: url, fileName: "avatar.jpg", response: response)
                
                // 先检查 HTTP 状态码
                let statusCode = response.response?.statusCode ?? 0
                LMLogger.log("📡 Avatar upload response status: \(statusCode)")
                
                // 打印原始响应数据用于调试
                if let data = response.data {
                    let rawString = String(data: data, encoding: .utf8) ?? "Unable to decode"
                    LMLogger.log("📦 Raw response data: \(rawString)")
                }
                
                if let error = response.error {
                    LMLogger.log("❌ Upload error: \(error.localizedDescription)")
                    
                    // 尝试从原始数据解析错误信息
                    var errorResponse = LMApiResponseModel<LMUserModel>.general(of: statusCode, rawData: response.data)
                    errorResponse.rawData = response.data
                    
                    // 如果状态码是 200，可能是解析问题而非真正的错误
                    if statusCode == 200 {
                        // 尝试手动解析响应
                        if let data = response.data,
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            LMLogger.log("⚠️ Status 200 but decode failed, raw JSON: \(json)")
                        }
                    }
                    
                    DispatchQueue.main.async {
                        completion(errorResponse)
                    }
                    return
                }
                
                guard var responseValue = response.value else {
                    LMLogger.log("❌ Failed to parse response")
                    var emptyResponse = LMApiResponseModel<LMUserModel>.empty()
                    emptyResponse.rawData = response.data
                    DispatchQueue.main.async {
                        completion(emptyResponse)
                    }
                    return
                }
                
                responseValue.rawData = response.data
                if responseValue.code == nil {
                    responseValue.code = statusCode
                }
                DispatchQueue.main.async {
                    completion(responseValue)
                }
            }
        }
    }
    
    /// 用户登出
    func logout(completion: @escaping LMApiCallback<LMEmptyModel>) {
        LMApiClient.request(
            LMApi.Auth.logout,
            method: .delete,
            type: LMEmptyModel.self,
            completeHandler: completion
        )
    }

    /// 删除账户（提交注销原因）
    func deleteAccount(reason: Int, completion: @escaping LMApiCallback<LMEmptyModel>) {
        let params: [String: Any] = [
            "reason": reason
        ]
        
        LMApiClient.request(
            LMApi.User.deleteAccount,
            method: .post,
            params: params,
            type: LMEmptyModel.self,
            completeHandler: completion
        )
    }
    
    // MARK: - Guest User APIs
    
    /// Guest 用户注册
    func registerGuest(language: String? = nil, completion: @escaping LMApiCallback<LMLoginResponse>) {
        var params: [String: Any] = [
            "device_id": LMPackageManager.package.uuid
        ]
        
        if let language = language {
            params["language"] = language
        }
        
        LMApiClient.request(
            LMApi.Auth.guestRegister,
            method: .post,
            params: params,
            type: LMLoginResponse.self,
            completeHandler: completion
        )
    }
    
    /// Guest 用户登录
    func loginGuest(completion: @escaping LMApiCallback<LMLoginResponse>) {
        let params: [String: Any] = [
            "device_id": LMPackageManager.package.uuid
        ]
        
        LMApiClient.request(
            LMApi.Auth.guestLogin,
            method: .post,
            params: params,
            type: LMLoginResponse.self,
            completeHandler: completion
        )
    }
    
    // MARK: - Subscription APIs
    
    /// 领取免费试用（14天）
    func claimFreeTrial(completion: @escaping LMApiCallback<LMFreeTrialResponse>) {
        LMApiClient.request(
            LMApi.Subscription.freeTrial,
            method: .post,
            type: LMFreeTrialResponse.self,
            completeHandler: completion
        )
    }

    // MARK: - App APIs
    
    /// 获取当前版本发布状态及更新信息
    func getAppUpdatedStatus(completion: @escaping LMApiCallback<LMAppUpdatedStatus>) {
        LMApiClient.request(
            LMApi.App.updated,
            method: .get,
            type: LMAppUpdatedStatus.self,
            completeHandler: completion
        )
    }
    
    // MARK: - Composition APIs
    
    /// 提交构图任务
    /// - Parameters:
    ///   - originalImage: 原始场景图
    ///   - compressedImage: 压缩后的场景图（PRD 要求长边≤1080px）
    func submitCompositionTask(
        originalImage: UIImage,
        compressedImage: UIImage,
        embeddings: [Float],
        aspectRatio: String,
        sceneType: String?,
        completion: @escaping LMApiCallback<LMCompositionTaskResponse>
    ) {
        
        guard let originalImageData = originalImage.jpegData(compressionQuality: 0.9),
              let compressedImageData = compressedImage.jpegData(compressionQuality: 0.9) else {
            var errorResponse = LMApiResponseModel<LMCompositionTaskResponse>.empty()
            errorResponse.message = "Failed to convert image to JPEG data"
            completion(errorResponse)
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let createdAt = dateFormatter.string(from: Date())
        
        let embeddingsJSON = try? JSONSerialization.data(withJSONObject: embeddings)
        let embeddingsString = embeddingsJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        
        let url = AppConfigs.Host.path() + LMApi.Composition.analyze
        
        // 在后台线程执行上传
        DispatchQueue.global().async {
            AF.upload(multipartFormData: { multipartFormData in
                multipartFormData.append(originalImageData, withName: "file", fileName: "scene.jpg", mimeType: "image/jpeg")
                multipartFormData.append(compressedImageData, withName: "optimized_file", fileName: "scene_optimized.jpg", mimeType: "image/jpeg")
                
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
            }, to: url, headers: LMApiClient.uploadHTTPHeaders())
            .responseDecodable(of: LMApiResponseModel<LMCompositionTaskResponse>.self) { response in
                
                // 统一的响应处理（参考 LMApiClient.requestAndParser）
                switch response.result {
                case .success(var responseModel):
                    responseModel.rawData = response.data
                    DispatchQueue.main.async {
                        completion(responseModel)
                    }
                case .failure(_):
                    LMLogger.log("❌ Upload error: \(String(describing: response.error))")
                    let statusCode = response.response?.statusCode
                    var errorResponse = LMApiResponseModel<LMCompositionTaskResponse>.general(of: statusCode, rawData: response.data)
                    errorResponse.rawData = response.data
                    DispatchQueue.main.async {
                        completion(errorResponse)
                    }
                }
            }
        }
    }
    
    /// 获取任务建议图（轮询：获取所有建议图）
    func getSuggestions(taskId: String, completion: @escaping LMApiCallback<LMCompositionSuggestionsResponse>) {
        LMApiClient.request(
            LMApi.Composition.suggestions(taskId: taskId),
            method: .get,
            type: LMCompositionSuggestionsResponse.self,
            completeHandler: completion
        )
    }
    
    /// 查询任务概要（轮询：查询任务概要）
    func getTaskDetail(taskId: String, completion: @escaping LMApiCallback<LMCompositionTaskDetailResponse>) {
        LMApiClient.request(
            LMApi.Composition.taskDetail(taskId: taskId),
            method: .get,
            type: LMCompositionTaskDetailResponse.self,
            completeHandler: completion
        )
    }
    
    /// 获取任务 Job 列表
    func getJobList(taskId: String, completion: @escaping LMApiCallback<LMCompositionJobListResponse>) {
        LMApiClient.request(
            LMApi.Composition.jobList(taskId: taskId),
            method: .get,
            type: LMCompositionJobListResponse.self,
            completeHandler: completion
        )
    }
    
    /// 按 Job 轮询建议图
    func getJobDetail(
        taskId: String,
        jobId: String,
        rank: Int? = nil,
        offset: Int? = nil,
        limit: Int? = nil,
        completion: @escaping LMApiCallback<LMCompositionJobDetailResponse>
    ) {
        var params: [String: Any] = [:]
        
        if let rank = rank {
            params["rank"] = rank
        }
        if let offset = offset {
            params["offset"] = offset
        }
        if let limit = limit {
            params["limit"] = limit
        }
        
        LMApiClient.request(
            LMApi.Composition.jobDetail(taskId: taskId, jobId: jobId),
            method: .get,
            params: params,
            type: LMCompositionJobDetailResponse.self,
            completeHandler: completion
        )
    }
    
    /// 分页获取历史构图结果
    func getCompositionResults(page: Int = 1, number: Int = 4, completion: @escaping LMApiCallback<LMCompositionResultsResponse>) {
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
    func confirmSuggestion(taskId: String, suggestionId: String, completion: @escaping LMApiCallback<LMConfirmSuggestionResponse>) {
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
    
    /// 上报 Suggestion 任务结果
    func reportSuggestionTaskResult(
        taskId: String,
        eventType: LMCompositionTaskResultEventType? = nil,
        suggestionId: String? = nil,
        finalized: Bool,
        completion: @escaping LMApiCallback<LMEmptyModel>
    ) {
        var params: [String: Any] = [
            "task_id": taskId,
            "finalized": finalized
        ]
        
        if let eventType {
            params["event_type"] = eventType.rawValue
        }
        
        if let suggestionId, !suggestionId.isEmpty {
            params["suggestion_id"] = suggestionId
        }
        
        LMApiClient.request(
            LMApi.Composition.suggestionResults,
            method: .post,
            params: params,
            type: LMEmptyModel.self,
            completeHandler: completion
        )
    }
    
    // MARK: - Private Helper Methods
    
    /// 格式化输出文件上传请求的日志
    private func logUploadRequest<T: Codable>(
        url: String,
        fileName: String,
        response: DataResponse<LMApiResponseModel<T>, AFError>
    ) {
        var requestParser = "Request Object\nPath: PUT \(url)\n"
        requestParser += "Params:\n"
        requestParser += "  - file: \(fileName) (multipart)\n"
        
        var responseParser = "Response Object\n"
        if let data = response.data,
           let jsonString = String(data: data, encoding: .utf8) {
            responseParser += jsonString
        } else if let error = response.error {
            responseParser += error.localizedDescription
        }
        
        LMLogger.log("\(requestParser)\n\(LMLogger.dividingLine)\n\(responseParser)")
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
            "Accept-Language": LMLaunageManager.shared.currentLanguage.apiLanguageCode,
            "Language": LMLaunageManager.shared.currentLanguage.apiLanguageCode,
            //            "Model": LMPackageManager.package.model,
            //            "PackageName": LMPackageManager.package.bundleName
        ]
        
        // Add Authorization token if available
        if let token = LMUserManager.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        return headers
    }
    
    /// 用于文件上传的 HTTP Headers（不包含 Content-Type，让 Alamofire 自动设置 multipart boundary）
    static func uploadHTTPHeaders() -> HTTPHeaders {
        var headers: HTTPHeaders = [
            "Platform": "iOS",
            "Channel": "AppStore",
            "Version": LMPackageManager.package.version,
        ]
        
        // Add Authorization token if available
        if let token = LMUserManager.shared.accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        return headers
    }
}
