//
//  LMPersonDetectionProtocol.swift
//  processor
//
//  Created by Kiro on 2025-01-XX.
//

import UIKit
import CoreMedia

/// 人物检测结果代理
protocol LMPersonDetectionDelegate: AnyObject {
    /// 人物检测结果更新
    /// - Parameters:
    ///   - bbox: 检测到的人物边界框（归一化坐标 0-1），nil表示未检测到人物
    ///   - confidence: 检测置信度（0-1）
    func personDetectionDidUpdate(bbox: CGRect?, confidence: Float)
    
    /// 人物检测失败
    /// - Parameter error: 错误信息
    func personDetectionDidFail(error: Error)
}

/// 人物检测协议
protocol LMPersonDetectionProtocol {
    /// 代理
    var delegate: LMPersonDetectionDelegate? { get set }
    
    /// 是否正在检测
    var isDetecting: Bool { get }
    
    /// 开始检测
    func startDetection()
    
    /// 停止检测
    func stopDetection()
    
    /// 检测静态图片中的人物
    /// - Parameters:
    ///   - image: 待检测图片
    ///   - orientation: 图片方向
    /// - Returns: 检测到的人物边界框（归一化坐标），nil表示未检测到
    func detectPerson(in image: UIImage, orientation: UIImage.Orientation) -> CGRect?
    
    /// 检测像素缓冲区中的人物
    /// - Parameters:
    ///   - pixelBuffer: 像素缓冲区
    ///   - orientation: 图片方向
    /// - Returns: 检测到的人物边界框（归一化坐标），nil表示未检测到
    func detectPerson(in pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> CGRect?
}
