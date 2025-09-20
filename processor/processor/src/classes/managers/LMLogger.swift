//
//  LMLogger.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import Foundation

struct LMLogger {
    
    /// 日志的分割线
    static let dividingLine = "====================================="
    
    /// 日志输出
    static func log<str>(_ text: str,
                         file: String = #file,
                         method: String = #function,
                         line: Int = #line) {
#if DEBUG
        var resultLogString = ""
        var logFileString = ""
        if let fileString = (file as NSString).pathComponents.last {
            logFileString = fileString.replacingOccurrences(of: "swift", with: "")
        }
        resultLogString = "\nFile: \(logFileString)\n"
        var resultMethodString = method
        if resultMethodString.contains("(") {
            if let prefixString = resultMethodString.split(separator: "(").first {
                resultMethodString = String(prefixString)
            }
        }
        resultLogString = "\(resultLogString) Method: \(resultMethodString)\tLine: \(line)\n"
        print("\(logFileString)\n\(LMLogger.dividingLine)\n\(text)")
#endif
    }
}
