//
//  LMApiResponseModel.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import Foundation
import Alamofire

struct LMApiResponseModel<T: Codable>: Codable {
    
    var value: T? // 服务端返回的数据
    
    var code: Int? = -1001 // 响应的状态值
    
    var status: DynamicStatus? // 响应的状态值
    
    var message: String? // 补充描述信息
    
    var rawData: Data? // 服务器返回的原始数据，data类型
    
    /// 空响应对象，一般用作解析失败或服务端返回数据不符合约定规范时
    static func empty() -> LMApiResponseModel {
        return LMApiResponseModel()
    }
    
    /// 请求错误响应对象（使用 AFError）
    /// - Parameters:
    ///   - code: HTTP 状态码
    ///   - requestError: Alamofire 错误
    ///   - rawData: 原始响应数据（用于解析服务端 message）
    static func general(of code: Int?,
                        rawData: Data? = nil) -> LMApiResponseModel {
        return LMApiResponseModel(
            code: code ?? -1001,
            message: "Service data is wrong",
            rawData: rawData
        )
    }
    
    /// 当前请求是否已成功
    var requestSuccess: Bool {
        if status?.wrappedValue != nil {
            return status?.wrappedValue == 200
        }
        if code != nil {
            return code == 200
        }
        return false
    }
    
    /// 转换为 LMApiError（用于错误处理）
    var asError: LMApiError? {
        if !requestSuccess {
            return LMApiError(content: message ?? "Unkonwn error")
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case value = "data"
        case message
        case code
        case status
    }
}

struct LMEmptyModel: Codable {
    
    var status: Int?
}

@propertyWrapper public struct DynamicStatus: Codable {
    
    public var wrappedValue: Int?
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var resultValue: Int?
        do {
            resultValue = try container.decode(Int.self)
        } catch {
            do {
                let boolValue = try Bool(container.decode(Bool.self))
                resultValue = boolValue ? 200 : -1001
            } catch {
                resultValue = nil
            }
        }
        wrappedValue = resultValue
    }
}


/// 自定义 API 错误类型
/// 用于统一处理 API 请求中的各种错误情况
struct LMApiError: Error, LocalizedError {
    
    /// 错误内容（优先使用服务端返回的 message，否则使用 localizedDescription）
    let content: String?
    
    // MARK: - LocalizedError
    
    var errorDescription: String? {
        return content
    }
    
    init(content: String?) {
        self.content = content
    }
}
