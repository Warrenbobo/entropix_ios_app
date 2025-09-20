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
    
    var value: HTTPMethod {
        switch self {
        case .get:
            return HTTPMethod.get
        case .post:
            return HTTPMethod.post
        }
    }
    
    var name: String {
        switch self {
        case .get:
            return "GET"
        case .post:
            return "POST"
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
        let resultURLString = AppConfigs.Host.release + url
        requestAndParser(resultURLString,
                         method: method,
                         params: addSecretSign(with: params ?? [:]),
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
                    if statusCode == 401 {
                        
                    } else if statusCode == 200 {
                        if let data = responseData.data,
                           let object = try? JSONSerialization.jsonObject(with: data,
                                                                          options: .fragmentsAllowed) as? [String: Any],
                           let message = object["message"] as? String {
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
    
    /// 默认的全局请求Header参数
    private static func defaultHTTPHeaders() -> HTTPHeaders {
        return ["Content-Type": "application/json",
                "platform": "iOS",
                "channel": "appstore",
                "Version": LMPackageManager.package.version,
                "model": LMPackageManager.package.model,
                "PackageName": LMPackageManager.package.bundleName]
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
    
    private static let secret = "j^f-9wGbfiSElxCxG+&O4gIvts_FE#Cb4Z&@#j3g"
    /// 给请求参数加密
    static private func addSecretSign(with params: [String: Any]) -> [String: Any] {
        var originalParams = params
        originalParams["timestamp"] = String(format: "%.f", Date().timeIntervalSince1970 * 1000)
        let paramList = originalParams.sorted(by: { $0.key < $1.key })
        let stringList = paramList.map {(key, value) -> String in
            return "\(key)=\(value)"
        }
        let originalString = stringList.joined(separator: "") + secret
        originalParams["sign"] = CocoaSecurity.md5(originalString).hexLower
        return originalParams
    }
}
