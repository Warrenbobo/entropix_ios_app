//
//  LMApiClient.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import Foundation
import Alamofire
import CocoaSecurity

/// 请求的方式
enum MethodType {
    case get
    case post
    case put
    case delete
    
    var value: HTTPMethod {
        switch self {
        case .get:
            return HTTPMethod.get
        case .post:
            return HTTPMethod.post
        case .put:
            return HTTPMethod.put
        case .delete:
            return HTTPMethod.delete
        }
    }
    
    var name: String {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
        case .put:
            return "PUT"
        case .delete:
            return "DELETE"
        }
    }
}

class LMApiClient {
    
    /// 网络对象
    static let reachability = NetworkReachabilityManager()
    
    /// 请求网络数据
    static func request<T: Codable>(_ url: String,
                                    method: MethodType,
                                    params: [String: Any]? = nil,
                                    type: T.Type,
                                    encoding: ParameterEncoding? = nil,
                                    useSecretHeader: Bool = false,
                                    completeHandler: @escaping ((LMApiResponseModel<T>) -> ())) {
        let resultEncoding: ParameterEncoding = encoding ?? (method == .get ? URLEncoding.default : JSONEncoding.default)
        let resultURLString = AppConfigs.Host.path() + url
        requestAndParser(resultURLString,
                         method: method,
                         params: params,
                         type: type,
                         encoding: resultEncoding,
                         header: defaultHTTPHeaders(),
                         completeHandler: completeHandler)
    }
    
    /// 使用工具请求并解析数据
    static func requestAndParser<T>(_ url: String,
                                        method: MethodType,
                                        params: [String: Any]?,
                                        type: T.Type,
                                        encoding: ParameterEncoding = URLEncoding.default,
                                        header: HTTPHeaders? = nil,
                                        completeHandler: @escaping ((LMApiResponseModel<T>) -> ())) {
        DispatchQueue.global().async {
            AF.request(url,
                       method: method.value,
                       parameters: params,
                       encoding: encoding,
                       headers: header)
            .responseDecodable(of: LMApiResponseModel<T>.self,
                               completionHandler: { responseData in
                self.requestFormatLog(url: url,
                                      method: method,
                                      headers: header,
                                      params: params,
                                      response: responseData)
                if let error: AFError = responseData.error {
                    LMLogger.log("解析出错 == \(String(describing: responseData.error))")
                    let statusCode = responseData.response?.statusCode
                    
                    // 处理 401 未授权错误 - 尝试刷新 Token
                    if statusCode == 401 {
                        LMLogger.log("⚠️ 401 Unauthorized - Attempting to refresh token")
                        self.handleUnauthorizedError(
                            url: url,
                            method: method,
                            params: params,
                            type: type,
                            encoding: encoding,
                            header: header,
                            completeHandler: completeHandler
                        )
                        return
                    } else if statusCode == 200 {
                        if let data = responseData.data,
                           let object = try? JSONSerialization.jsonObject(with: data,
                                                                          options: .fragmentsAllowed) as? [String: Any],
                           let message = object["message"] as? String {
                            LMLogger.log("⚠️ Status 200 but with error message: \(message)")
                        }
                    }
                    var errorResponse = LMApiResponseModel<T>.error(of: statusCode,
                                                               requestError: error)
                    errorResponse.rawData = responseData.data
                    DispatchQueue.main.async {
                        completeHandler(errorResponse)
                    }
                    return
                }
                guard var responseValue = responseData.value else {
                    LMLogger.log("解析出错 == \(String(describing: responseData.error))")
                    // 解析出错
                    var emptyResponse = LMApiResponseModel<T>.empty()
                    emptyResponse.rawData = responseData.data
                    DispatchQueue.main.async {
                        completeHandler(emptyResponse)
                    }
                    return
                }
                responseValue.rawData = responseData.data
                DispatchQueue.main.async {
                    completeHandler(responseValue)
                    if let message = responseValue.message,
                       !responseValue.requestSuccess {
                        // 是否全局显示信息
                    }
                }
            })
        }
    }
    
    /// 处理 401 未授权错误 - 尝试刷新 Token 并重试请求
    private static func handleUnauthorizedError<T: Codable>(
        url: String,
        method: MethodType,
        params: [String: Any]?,
        type: T.Type,
        encoding: ParameterEncoding,
        header: HTTPHeaders?,
        completeHandler: @escaping ((LMApiResponseModel<T>) -> ())
    ) {
        // 尝试刷新 Token
        LMUserManager.shared.refreshAccessToken { result in
            switch result {
            case .success:
                LMLogger.log("✅ Token refreshed successfully, retrying request")
                // Token 刷新成功，重试原请求
                self.requestAndParser(
                    url,
                    method: method,
                    params: params,
                    type: type,
                    encoding: encoding,
                    header: self.defaultHTTPHeaders(), // 使用新的 Token
                    completeHandler: completeHandler
                )
                
            case .failure(let error):
                LMLogger.log("❌ Token refresh failed: \(error.localizedDescription)")
                // Token 刷新失败，返回 401 错误
                let errorResponse = LMApiResponseModel<T>.error(of: 401, requestError: error as! AFError)
                DispatchQueue.main.async {
                    completeHandler(errorResponse)
                    // 触发自动登出
                    LMSessionManager.shared.handleAutoLogout(reason: "token_refresh_failed")
                }
            }
        }
    }
    
    /// 格式化输出网络请求的日志
    private static func requestFormatLog<T: Codable>(url: String,
                                                     method: MethodType,
                                                     headers: HTTPHeaders? = nil,
                                                     params: [String: Any]? = nil,
                                                     response: DataResponse<LMApiResponseModel<T>, AFError>? = nil) {
        var requestParser = "Request Object\nPath: \(method.name) \(url)\n"
        let resultParams = String(describing: params ?? [:])
        requestParser = "\(requestParser)Params:\n\(resultParams)\n"
        if let resultHeaders = headers {
            let headersJSON = String(describing: resultHeaders.dictionary)
            requestParser = "\(requestParser)Headers:\n\(headersJSON)"
        }
        var responseParser = "Response Object\n"
        if let data = response?.data,
           let jsonString = String(data: data, encoding: .utf8) {
            responseParser = "\(responseParser)\(jsonString)"
        } else if let error = response?.error {
            responseParser = "\(responseParser)\(error.localizedDescription)"
        }
        LMLogger.log("\(requestParser)\n\(LMLogger.dividingLine)\n\(responseParser)")
    }
}
