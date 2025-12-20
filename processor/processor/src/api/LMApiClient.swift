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
    case patch
    case delete
    
    var value: HTTPMethod {
        switch self {
        case .get:
            return HTTPMethod.get
        case .post:
            return HTTPMethod.post
        case .put:
            return HTTPMethod.put
        case .patch:
            return HTTPMethod.patch
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
        case .patch:
            return "PATCH"
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
                switch responseData.result {
                case .success(var responseModel):
                    responseModel.rawData = responseData.data
                    DispatchQueue.main.async {
                        completeHandler(responseModel)
                        if let message = responseModel.message,
                           !responseModel.requestSuccess {
                            // 是否全局显示信息
                        }
                    }
                case .failure(_):
                    LMLogger.log("请求出错 == \(String(describing: responseData.error))")
                    let statusCode = responseData.response?.statusCode
                    let errorResponse = LMApiResponseModel<T>.general(of: statusCode,
                                                                      rawData: responseData.data)
                    DispatchQueue.main.async {
                        completeHandler(errorResponse)
                    }
                }
            })
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
