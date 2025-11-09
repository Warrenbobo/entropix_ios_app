//
//  LMCompositionService.swift
//  processor
//
//  Created by Kiro on 2025/11/9.
//

import UIKit
import Alamofire

class LMCompositionService {
    
    static let shared = LMCompositionService()
    
    private init() {}
    
    // MARK: - 提交构图任务
    
    /// 提交构图任务
    /// - Parameters:
    ///   - originalImage: 原始场景图
    ///   - optimizedImage: 预处理后的 960px 场景图
    ///   - embeddings: 图像向量（768维）
    ///   - aspectRatio: 宽高比
    ///   - sceneType: 场景类型（可选）
    ///   - completion: 完成回调
    func submitCompositionTask(
        originalImage: UIImage,
        optimizedImage: UIImage,
        embeddings: [Float],
        aspectRatio: String,
        sceneType: String? = nil,
        completion: @escaping (Result<CompositionTaskResponse, Error>) -> Void
    ) {
        LMLogger.log("📤 Submitting composition task...")
        
        // 验证向量维度
        guard embeddings.count == 768 else {
            let error = NSError(domain: "CompositionService", code: -1, 
                              userInfo: [NSLocalizedDescriptionKey: "Embeddings must be 768 dimensions"])
            completion(.failure(error))
            return
        }
        
        // 准备图片数据
        guard let originalData = originalImage.jpegData(compressionQuality: 0.9),
              let optimizedData = optimizedImage.jpegData(compressionQuality: 0.9) else {
            let error = NSError(domain: "CompositionService", code: -2,
                              userInfo: [NSLocalizedDescriptionKey: "Failed to encode images"])
            completion(.failure(error))
            return
        }
        
        // 准备表单数据
        let url = AppConfigs.Host.path() + "/v1/composition/analyze"
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(getAccessToken())"
        ]
        
        // 创建时间戳
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let createdAt = dateFormatter.string(from: Date())
        
        // 转换 embeddings 为 JSON 字符串
        let embeddingsJSON = try? JSONSerialization.data(withJSONObject: embeddings)
        let embeddingsString = embeddingsJSON.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        
        AF.upload(multipartFormData: { multipartFormData in
            // 添加文件
            multipartFormData.append(originalData, withName: "file", fileName: "scene.jpg", mimeType: "image/jpeg")
            multipartFormData.append(optimizedData, withName: "optimized_file", fileName: "scene_960.jpg", mimeType: "image/jpeg")
            
            // 添加文本字段
            if let aspectRatioData = aspectRatio.data(using: .utf8) {
                multipartFormData.append(aspectRatioData, withName: "aspect_ratio")
            }
            
            if let createdAtData = createdAt.data(using: .utf8) {
                multipartFormData.append(createdAtData, withName: "created_at")
            }
            
            if let embeddingsData = embeddingsString.data(using: .utf8) {
                multipartFormData.append(embeddingsData, withName: "embeddings")
            }
            
            if let sceneType = sceneType, let sceneTypeData = sceneType.data(using: .utf8) {
                multipartFormData.append(sceneTypeData, withName: "scene_type")
            }
        }, to: url, headers: headers)
        .validate()
        .responseDecodable(of: LMApiResponseModel<CompositionTaskResponse>.self) { response in
            switch response.result {
            case .success(let apiResponse):
                if apiResponse.requestSuccess, let data = apiResponse.value {
                    LMLogger.log("✅ Task submitted: \(data.taskId)")
                    completion(.success(data))
                } else {
                    let error = NSError(domain: "CompositionService", code: apiResponse.code ?? -1,
                                      userInfo: [NSLocalizedDescriptionKey: apiResponse.message ?? "Unknown error"])
                    completion(.failure(error))
                }
            case .failure(let error):
                LMLogger.log("❌ Task submission failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 轮询任务状态
    
    /// 轮询任务状态
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - completion: 完成回调
    func pollTaskStatus(
        taskId: String,
        completion: @escaping (Result<CompositionStatusResponse, Error>) -> Void
    ) {
        let url = AppConfigs.Host.path() + "/v1/composition/suggestions/\(taskId)"
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(getAccessToken())"
        ]
        
        AF.request(url, method: .get, headers: headers)
            .validate()
            .responseDecodable(of: LMApiResponseModel<CompositionStatusResponse>.self) { response in
                switch response.result {
                case .success(let apiResponse):
                    if apiResponse.requestSuccess, let data = apiResponse.value {
                        completion(.success(data))
                    } else {
                        let error = NSError(domain: "CompositionService", code: apiResponse.code ?? -1,
                                          userInfo: [NSLocalizedDescriptionKey: apiResponse.message ?? "Unknown error"])
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    // MARK: - 确认建议
    
    /// 确认选中的建议
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - suggestionId: 建议ID
    ///   - completion: 完成回调
    func confirmSuggestion(
        taskId: String,
        suggestionId: String,
        completion: @escaping (Result<ConfirmSuggestionResponse, Error>) -> Void
    ) {
        let url = AppConfigs.Host.path() + "/v1/composition/suggestions/confirm"
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(getAccessToken())",
            "Content-Type": "application/json"
        ]
        
        let request = ConfirmSuggestionRequest(taskId: taskId, suggestionId: suggestionId)
        
        AF.request(url, method: .post, parameters: request, encoder: JSONParameterEncoder.default, headers: headers)
            .validate()
            .responseDecodable(of: LMApiResponseModel<ConfirmSuggestionResponse>.self) { response in
                switch response.result {
                case .success(let apiResponse):
                    if apiResponse.requestSuccess, let data = apiResponse.value {
                        LMLogger.log("✅ Suggestion confirmed: \(suggestionId)")
                        completion(.success(data))
                    } else {
                        let error = NSError(domain: "CompositionService", code: apiResponse.code ?? -1,
                                          userInfo: [NSLocalizedDescriptionKey: apiResponse.message ?? "Unknown error"])
                        completion(.failure(error))
                    }
                case .failure(let error):
                    LMLogger.log("❌ Confirmation failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
    }
    
    // MARK: - 获取历史记录
    
    /// 获取历史构图结果
    /// - Parameters:
    ///   - page: 页码
    ///   - number: 每页数量
    ///   - completion: 完成回调
    func fetchHistory(
        page: Int = 1,
        number: Int = 4,
        completion: @escaping (Result<CompositionHistoryResponse, Error>) -> Void
    ) {
        let url = AppConfigs.Host.path() + "/v1/composition/results"
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(getAccessToken())"
        ]
        let parameters: [String: Any] = [
            "page": page,
            "number": number
        ]
        
        AF.request(url, method: .get, parameters: parameters, headers: headers)
            .validate()
            .responseDecodable(of: LMApiResponseModel<CompositionHistoryResponse>.self) { response in
                switch response.result {
                case .success(let apiResponse):
                    if apiResponse.requestSuccess, let data = apiResponse.value {
                        completion(.success(data))
                    } else {
                        let error = NSError(domain: "CompositionService", code: apiResponse.code ?? -1,
                                          userInfo: [NSLocalizedDescriptionKey: apiResponse.message ?? "Unknown error"])
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
    }
    
    // MARK: - Helper Methods
    
    private func getAccessToken() -> String {
        // TODO: 从 Keychain 或用户管理器获取 access token
        return UserDefaults.standard.string(forKey: "access_token") ?? ""
    }
}
