//
//  ObjectExtensions.swift
//  processor
//
//  Created by muz on 2025/9/20.
//

import Accelerate
import Foundation
import UIKit
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import UniformTypeIdentifiers
import Vision

/// 渐变方向枚举（常见方向，可按需扩展）
enum GradientDirection {
    case horizontal          // 水平（左→右）
    case vertical            // 垂直（上→下）
    case topLeftToBottomRight// 左上→右下
    case topRightToBottomLeft// 右上→左下
    
    // 对应的 startPoint 和 endPoint（CAGradientLayer 的坐标体系：(0,0) 左上，(1,1) 右下）
    var startPoint: CGPoint {
        switch self {
        case .horizontal: return CGPoint(x: 0, y: 0.5)
        case .vertical: return CGPoint(x: 0.5, y: 0)
        case .topLeftToBottomRight: return CGPoint(x: 0, y: 0)
        case .topRightToBottomLeft: return CGPoint(x: 1, y: 0)
        }
    }
    
    var endPoint: CGPoint {
        switch self {
        case .horizontal: return CGPoint(x: 1, y: 0.5)
        case .vertical: return CGPoint(x: 0.5, y: 1)
        case .topLeftToBottomRight: return CGPoint(x: 1, y: 1)
        case .topRightToBottomLeft: return CGPoint(x: 0, y: 1)
        }
    }
}

extension UIColor {
    
    
    /// 字符串格式化颜色
    static func hexColor(_ hex: String,
                         alpha: CGFloat = 1) -> UIColor {
        var colorString = hex
        if let splitString = hex.split(separator: "#").last {
            colorString = String(splitString)
        }
        var value: Int64 = 0
        let scanner = Scanner(string: colorString)
        scanner.scanHexInt64(&value)
        let redHex = CGFloat(value >> 16 & 0x000000FF) / 255
        let greenHex = CGFloat(value >> 8 & 0x000000FF) / 255
        let blueHex = CGFloat(value & 0x000000FF) / 255
        return UIColor(red: redHex,
                       green: greenHex,
                       blue: blueHex,
                       alpha: alpha)
    }
}


extension UIView {
    
    /// 设置View的渐变色
    func setGradient(colors: [UIColor],
                  locations: [NSNumber] = [0, 1],
                  startPoint: CGPoint = CGPoint.zero,
                  endPoint: CGPoint = CGPoint(x: 0, y: 1)) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors.map({ $0.cgColor })
        gradientLayer.frame = bounds
        gradientLayer.locations = locations
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    /// 设置View的部分圆角
    func setCorners(_ corners: UIRectCorner,
                    with radii: CGFloat) {
        let radiiSize = CGSize(width: radii, height: radii)
        let maskPath = UIBezierPath(roundedRect: bounds,
                                    byRoundingCorners: corners,
                                    cornerRadii: radiiSize)
        let maskLayer = CAShapeLayer()
        maskLayer.frame = bounds
        maskLayer.path = maskPath.cgPath
        layer.mask = maskLayer
    }
    
    /// 截图view中的内容
    func snapshot() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { context in
            layer.render(in: context.cgContext)
        }
    }
    
    func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let viewController = responder as? UIViewController {
                return viewController
            }
            responder = responder?.next
        }
        return nil
    }
}

extension UIImage {
    /// 生成渐变色图片
    /// - Parameters:
    ///   - size: 图片尺寸（默认屏幕尺寸）
    ///   - colors: 渐变颜色数组（需传入 CGColor）
    ///   - direction: 渐变方向（默认水平从左到右）
    ///   - cornerRadius: 圆角半径（默认 0，无圆角）
    ///   - locations: 渐变位置（默认 nil，均匀分布）
    /// - Returns: 生成的渐变色 UIImage
    static func gradientImage(
        size: CGSize = UIScreen.main.bounds.size,
        colors: [CGColor],
        direction: GradientDirection = .horizontal,
        cornerRadius: CGFloat = 0,
        locations: [NSNumber]? = nil
    ) -> UIImage {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors
        gradientLayer.locations = locations
        gradientLayer.frame = CGRect(origin: .zero, size: size)
        gradientLayer.cornerRadius = cornerRadius
        gradientLayer.masksToBounds = true // 圆角生效
        
        gradientLayer.startPoint = direction.startPoint
        gradientLayer.endPoint = direction.endPoint
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            gradientLayer.render(in: context.cgContext)
        }
    }

    func lmNormalizedImage() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func lmScaledToFit(maxDimension: CGFloat) -> UIImage {
        let normalizedImage = lmNormalizedImage()
        let longestEdge = max(normalizedImage.size.width, normalizedImage.size.height)

        guard longestEdge > 0, longestEdge > maxDimension else {
            return normalizedImage
        }

        let scaleRatio = maxDimension / longestEdge
        let targetSize = CGSize(width: normalizedImage.size.width * scaleRatio,
                                height: normalizedImage.size.height * scaleRatio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            normalizedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    func lmARGuidanceCanvasImage() -> UIImage {
        let normalizedImage = lmNormalizedImage()

        let shouldRotate = LMARGuidancePolicy.shouldRotateReferenceImageToPortrait(imageSize: normalizedImage.size)
        guard shouldRotate else {
            return normalizedImage
        }

        guard let cgImage = normalizedImage.cgImage,
              let portraitCanvasImage = LMARGuidancePolicy.makePortraitCanvasImage(
                from: cgImage,
                shouldRotateToPortrait: shouldRotate
              ) else {
            return normalizedImage
        }

        return UIImage(cgImage: portraitCanvasImage, scale: normalizedImage.scale, orientation: .up)
    }
}

final class LMImageAssetProcessor {

    private static let ciContext = CIContext(options: nil)

    private init() {}

    static func generateLineArt(from image: UIImage) -> UIImage? {
        let workingImage = image.lmScaledToFit(maxDimension: 1536)
        guard let cgImage = workingImage.cgImage,
              let personMask = generatePersonMask(for: cgImage) else {
            return nil
        }

        let rgba = generateLineart(image: cgImage, personMask: personMask)
        guard !rgba.isEmpty,
              let lineArtCGImage = makeCGImage(from: rgba, width: cgImage.width, height: cgImage.height) else {
            return nil
        }

        return UIImage(cgImage: lineArtCGImage, scale: workingImage.scale, orientation: .up)
    }

    private static func generatePersonMask(for image: CGImage) -> CVPixelBuffer? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        do {
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try handler.perform([request])
            return (request.results?.first as? VNPixelBufferObservation)?.pixelBuffer
        } catch {
            return nil
        }
    }

    private static func generateLineart(
        image: CGImage,
        personMask: CVPixelBuffer,
        blurSigma: Double = 1.0,
        edgeThresholdPercentile: Double = 0.85,
        dilationRadius: Int = 0
    ) -> [UInt8] {
        let width = image.width
        let height = image.height
        let imageExtent = CGRect(x: 0, y: 0, width: width, height: height)
        let ciInput = CIImage(cgImage: image)

        var maskCI = CIImage(cvPixelBuffer: personMask)
        let scaleX = CGFloat(width) / maskCI.extent.width
        let scaleY = CGFloat(height) / maskCI.extent.height
        maskCI = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let maskGray8 = renderGray8(maskCI, width: width, height: height)
        guard maskGray8.count == width * height else {
            return []
        }

        let blendFilter = CIFilter.blendWithMask()
        blendFilter.inputImage = ciInput
        blendFilter.backgroundImage = CIImage(color: CIColor.black).cropped(to: imageExtent)
        blendFilter.maskImage = maskCI
        guard let maskedCI = blendFilter.outputImage else {
            return []
        }

        let blurredCI = maskedCI
            .applyingGaussianBlur(sigma: blurSigma)
            .cropped(to: imageExtent)

        guard let blurredCGImage = ciContext.createCGImage(blurredCI, from: imageExtent) else {
            return []
        }

        let blurredGray = rgbaToGrayFloat(renderRGBA(blurredCGImage, width: width, height: height))
        guard blurredGray.count == width * height else {
            return []
        }

        var magnitude = sobelMagnitude(gray: blurredGray, width: width, height: height)

        for index in 0..<(width * height) where maskGray8[index] < 128 {
            magnitude[index] = 0
        }

        var maxValue: Float = 0
        vDSP_maxv(magnitude, 1, &maxValue, vDSP_Length(width * height))
        if maxValue > 0 {
            var normalized = [Float](repeating: 0, count: width * height)
            var divisor = maxValue
            vDSP_vsdiv(magnitude, 1, &divisor, &normalized, 1, vDSP_Length(width * height))
            var scale: Float = 255
            vDSP_vsmul(normalized, 1, &scale, &magnitude, 1, vDSP_Length(width * height))
        }

        let clampedPercentile = min(max(edgeThresholdPercentile, 0), 1)
        let nonzero = magnitude.filter { $0 > 0 }.sorted()
        let threshold: Float
        if nonzero.isEmpty {
            threshold = 128
        } else {
            let index = Int(Double(nonzero.count - 1) * clampedPercentile)
            threshold = nonzero[max(0, min(index, nonzero.count - 1))]
        }

        var binary = [UInt8](repeating: 0, count: width * height)
        for index in 0..<(width * height) {
            binary[index] = magnitude[index] >= threshold ? 255 : 0
        }

        if dilationRadius > 0 {
            binary = maxFilter(binary, width: width, height: height, radius: dilationRadius)
        }

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for index in 0..<(width * height) {
            let value = binary[index]
            let rgbaIndex = index * 4
            rgba[rgbaIndex] = value
            rgba[rgbaIndex + 1] = value
            rgba[rgbaIndex + 2] = value
            rgba[rgbaIndex + 3] = value
        }
        return rgba
    }

    private static func renderGray8(_ ciImage: CIImage, width: Int, height: Int) -> [UInt8] {
        guard let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            return []
        }

        var buffer = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return buffer
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    private static func renderRGBA(_ cgImage: CGImage, width: Int, height: Int) -> [UInt8] {
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return []
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }

    private static func rgbaToGrayFloat(_ rgba: [UInt8]) -> [Float] {
        let count = rgba.count / 4
        var gray = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let rgbaIndex = index * 4
            let red = Float(rgba[rgbaIndex]) / 255.0
            let green = Float(rgba[rgbaIndex + 1]) / 255.0
            let blue = Float(rgba[rgbaIndex + 2]) / 255.0
            gray[index] = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        }
        return gray
    }

    private static func sobelMagnitude(gray: [Float], width: Int, height: Int) -> [Float] {
        let count = width * height
        var source = gray
        var gradientX = [Float](repeating: 0, count: count)
        var gradientY = [Float](repeating: 0, count: count)
        var gxKernel: [Float] = [-1, 0, 1, -2, 0, 2, -1, 0, 1]
        var gyKernel: [Float] = [-1, -2, -1, 0, 0, 0, 1, 2, 1]
        let rowBytes = width * MemoryLayout<Float>.size

        source.withUnsafeMutableBytes { sourceBytes in
            gradientX.withUnsafeMutableBytes { gxBytes in
                gradientY.withUnsafeMutableBytes { gyBytes in
                    var sourceBuffer = vImage_Buffer(
                        data: sourceBytes.baseAddress,
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: rowBytes
                    )
                    var gxBuffer = vImage_Buffer(
                        data: gxBytes.baseAddress,
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: rowBytes
                    )
                    var gyBuffer = vImage_Buffer(
                        data: gyBytes.baseAddress,
                        height: vImagePixelCount(height),
                        width: vImagePixelCount(width),
                        rowBytes: rowBytes
                    )
                    vImageConvolve_PlanarF(
                        &sourceBuffer,
                        &gxBuffer,
                        nil,
                        0,
                        0,
                        &gxKernel,
                        3,
                        3,
                        0,
                        vImage_Flags(kvImageEdgeExtend)
                    )
                    vImageConvolve_PlanarF(
                        &sourceBuffer,
                        &gyBuffer,
                        nil,
                        0,
                        0,
                        &gyKernel,
                        3,
                        3,
                        0,
                        vImage_Flags(kvImageEdgeExtend)
                    )
                }
            }
        }

        var gxSquared = [Float](repeating: 0, count: count)
        var gySquared = [Float](repeating: 0, count: count)
        vDSP_vsq(gradientX, 1, &gxSquared, 1, vDSP_Length(count))
        vDSP_vsq(gradientY, 1, &gySquared, 1, vDSP_Length(count))

        var magnitudeSquared = [Float](repeating: 0, count: count)
        vDSP_vadd(gxSquared, 1, gySquared, 1, &magnitudeSquared, 1, vDSP_Length(count))

        var magnitude = [Float](repeating: 0, count: count)
        for index in 0..<count {
            magnitude[index] = sqrt(magnitudeSquared[index])
        }
        return magnitude
    }

    private static func maxFilter(_ source: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        let kernelSize = vImagePixelCount(radius * 2 + 1)
        var input = source
        var output = [UInt8](repeating: 0, count: width * height)

        input.withUnsafeMutableBytes { inputBytes in
            output.withUnsafeMutableBytes { outputBytes in
                var inputBuffer = vImage_Buffer(
                    data: inputBytes.baseAddress,
                    height: vImagePixelCount(height),
                    width: vImagePixelCount(width),
                    rowBytes: width
                )
                var outputBuffer = vImage_Buffer(
                    data: outputBytes.baseAddress,
                    height: vImagePixelCount(height),
                    width: vImagePixelCount(width),
                    rowBytes: width
                )
                vImageMax_Planar8(
                    &inputBuffer,
                    &outputBuffer,
                    nil,
                    0,
                    0,
                    kernelSize,
                    kernelSize,
                    vImage_Flags(kvImageEdgeExtend)
                )
            }
        }

        return output
    }

    private static func makeCGImage(from rgba: [UInt8], width: Int, height: Int) -> CGImage? {
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else {
            return nil
        }

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    static func watermarkedImage(from image: UIImage,
                                 widthRatio: CGFloat = 0.24,
                                 paddingRatio: CGFloat = 0.035,
                                 alpha: CGFloat = 0.82) -> UIImage {
        let normalizedImage = image.lmNormalizedImage()

        guard let watermarkImage = UIImage(named: AppConfigs.Assets.watermarkBrand) else {
            return normalizedImage
        }

        let targetWidth = max(CGFloat(72), normalizedImage.size.width * widthRatio)
        let targetHeight = targetWidth * watermarkImage.size.height / max(watermarkImage.size.width, 1)
        let padding = max(CGFloat(16), min(normalizedImage.size.width, normalizedImage.size.height) * paddingRatio)
        let watermarkRect = CGRect(
            x: normalizedImage.size.width - targetWidth - padding,
            y: normalizedImage.size.height - targetHeight - padding,
            width: targetWidth,
            height: targetHeight
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = normalizedImage.scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: normalizedImage.size, format: format).image { _ in
            normalizedImage.draw(in: CGRect(origin: .zero, size: normalizedImage.size))
            watermarkImage.draw(in: watermarkRect, blendMode: .normal, alpha: alpha)
        }
    }

    static func watermarkedImageDataPreservingMetadata(from image: UIImage,
                                                       originalImageData: Data,
                                                       widthRatio: CGFloat = 0.24,
                                                       paddingRatio: CGFloat = 0.035,
                                                       alpha: CGFloat = 0.82) -> Data? {
        let watermarkedImage = watermarkedImage(from: image,
                                                widthRatio: widthRatio,
                                                paddingRatio: paddingRatio,
                                                alpha: alpha).lmNormalizedImage()

        guard let cgImage = watermarkedImage.cgImage,
              let source = CGImageSourceCreateWithData(originalImageData as CFData, nil),
              let sourceType = CGImageSourceGetType(source) else {
            return nil
        }

        let originalProperties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        var destinationProperties = originalProperties
        destinationProperties[kCGImagePropertyOrientation] = 1
        destinationProperties[kCGImagePropertyPixelWidth] = Int(cgImage.width)
        destinationProperties[kCGImagePropertyPixelHeight] = Int(cgImage.height)

        let destinationData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(destinationData, sourceType, 1, nil) else {
            return nil
        }

        CGImageDestinationAddImage(destination, cgImage, destinationProperties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return destinationData as Data
    }

    static func watermarkFrame(watermarkSize: CGSize,
                               inside imageRect: CGRect,
                               widthRatio: CGFloat = 0.24,
                               paddingRatio: CGFloat = 0.04) -> CGRect {
        guard watermarkSize.width > 0,
              watermarkSize.height > 0,
              imageRect.width > 0,
              imageRect.height > 0 else {
            return .zero
        }

        let targetWidth = max(CGFloat(56), imageRect.width * widthRatio)
        let targetHeight = targetWidth * watermarkSize.height / watermarkSize.width
        let padding = max(CGFloat(12), min(imageRect.width, imageRect.height) * paddingRatio)

        return CGRect(
            x: imageRect.maxX - targetWidth - padding,
            y: imageRect.maxY - targetHeight - padding,
            width: targetWidth,
            height: targetHeight
        )
    }

    static func displayedImageRect(for imageSize: CGSize, inside bounds: CGRect) -> CGRect {
        AVMakeRect(aspectRatio: imageSize, insideRect: bounds)
    }
}

extension Int {
    
    /// 屏幕宽度自适应
    var fit: CGFloat {
        return CGFloat(self) * (UIScreen.main.bounds.width / 375)
    }
}

extension CGFloat {
    
    /// 屏幕宽度自适应
    var fit: CGFloat {
        return self * (UIScreen.main.bounds.width / 375)
    }
}

extension Date {
    
    /// 时间对象转为字符串格式
    func text(_ formatter: String = "HH:mm:ss.S") -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = customLocal
        timeFormatter.dateFormat = formatter
        return timeFormatter.string(from: self)
    }
    
    /// 是否是同一天的日期
    func samelyDay(_ date: Date) -> Bool {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = Locale(identifier: "zh_CN")
        let unitFlags: Set<Calendar.Component> = [.year, .month, .day,]
        let component1 = calendar.dateComponents(unitFlags, from: self)
        let component2 = calendar.dateComponents(unitFlags, from: date)
        return component1.year == component2.year &&
        component1.month == component2.month &&
        component1.day == component2.day
    }
    
    /// 获取时间加减后的目标时间，单位Hour
    func offset(_ hour: Int, round: Bool = true) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: self)
        let currentHour = components.hour ?? 0
        let currentMinute = components.minute ?? 0
        let currentSecond = components.second ?? 0
        var nextHour = currentHour
        if currentMinute > 0 || currentSecond > 0 {
            nextHour += hour
        }
        let nextFullHourDateComponents = DateComponents(year: components.year,
                                                        month: components.month,
                                                        day: components.day,
                                                        hour: nextHour,
                                                        minute: round ? 0 : components.minute ?? 0,
                                                        second: round ? 0 : components.second ?? 0)
        return calendar.date(from: nextFullHourDateComponents) ?? self
    }
    
    /// 获取两个时间中间相差的时分秒毫秒数
    func offsetText(to date: Date, _ format: String = "HH:mm:ss.S") -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        let components = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: self, to: date)
        return calendar.date(from: components)?.text(format) ?? ""
    }
    
    /// 获取两个日期对象的差值
    func offset(to date: Date, _ components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second, .nanosecond]) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        return calendar.dateComponents(components,
                                       from: self,
                                       to: date)
    }
    
    /// 获取当前日期的组合对象
    func toComponents() -> DateComponents {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        return calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: self)
    }
    
    /// 根据日期文本将时间转为Date格式
    static func dateFrom(text: String,
                       formatter: String = "HH:mm:ss") -> Date? {
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "zh_Hans_CN")
        timeFormatter.dateFormat = formatter
        return timeFormatter.date(from: text)
    }
    
    /// Date对象转为时间戳
    func toValue() -> TimeInterval {
        return timeIntervalSince1970
    }
    
    /// 获取某个时间偏移后的目标时间
    func offsetWithComponents(_ components: DateComponents) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        return calendar.date(byAdding: components, to: self)
    }
    
    /// 获取某个日期凌晨的时间，即某天的开始时间
    func startDate() -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        let components = calendar.dateComponents([.year,.month,.day], from: self)
        return calendar.date(from: components)
    }
    
    /// 判断某个时间对象是否应该显示为一天，一周，一月，一年前的样式
    func chineseFormatText() -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = NSTimeZone.local
        calendar.locale = customLocal
        let currentDate = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                 from: currentDate,
                                                 to: self)
        let yearMargin = components.year ?? 0
        let monthMargin = components.month ?? 0
        let dayMargin = components.day ?? 0
        if yearMargin > 0 {
            return "\(yearMargin)年后"
        } else if monthMargin > 0 {
            return "\(monthMargin)月后"
        } else if dayMargin > 0 {
            return "\(dayMargin)天后"
        } else {
            return currentDate.offsetText(to: self, "HH:mm:ss")
        }
    }
    
    /// 当前是星期几
    func chineseWeekday() -> Int {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "Asia/Shanghai")
        calendar.timeZone = timeZone!
        let weekdayValue = calendar.dateComponents([.weekday], from: self).weekday ?? 1
        return weekdayValue - 1
    }
    
    /// 将时间戳转为格式化时间
    static func toDateText(with timestamp: Int,
                           _ formatter: String = "yyyy.MM.dd") -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = formatter
        dateFormatter.timeZone = TimeZone.current
        return dateFormatter.string(from: date)
    }
    
    private var customLocal: Locale { return Locale(identifier: "zh_Hans_CN") }
}

extension Notification.Name {
    
    /// 用户数据发生变化通知
    static let userModelValueChanged = Notification.Name("UserModelValueChanged")
    
    /// 设备资源使用情况刷新
    static let resourceUsageChanged = Notification.Name("DeviceResourceUsageValueChanged")
}

extension String {
    
    /// 更改placeholder的样式
    var placeholder: NSAttributedString {
        return NSAttributedString(string: self,
                                  attributes: [.foregroundColor: AppTheme.ThemeColor.placeholder,
                                               .font: UIFont.systemFont(ofSize: 14)])
    }
    
    /// 生成事件的唯一id
    static func eventId() -> NSNumber {
        let timestamp = String(format: "%.f", Date().timeIntervalSince1970)
        let idString = timestamp[timestamp.index(timestamp.startIndex, offsetBy: 5)..<timestamp.endIndex]
        let idValue = Int(idString)!
        let random = Int.random(in: 100..<999)
        return NSNumber(value: idValue + random)
    }
    
    /// 获取随机长度的数字字符串
    static func randomChar(_ length: Int) -> String {
        guard length > 0 else { return "" }
        let base = "0123456789"
        var randomString = ""
        for _ in 0..<length {
            guard let randomCharacter = base.randomElement() else { continue }
            randomString.append(randomCharacter)
        }
        return randomString
    }
}

extension UIFont {
    
    /// 输出系统字体
    static func printSystemFonts() {
        let fontFamilies = UIFont.familyNames
        for familyName in fontFamilies {
            let fontNames = UIFont.fontNames(forFamilyName: familyName)
            print("Font Family: \(familyName)")
            for fontName in fontNames {
                print(" ---- \(fontName)")
            }
        }
    }
}

extension UIButton {
    
    /// 修改Button的图片和文字位置
    /// 以文字作为参照物
    /// #一定要在设置完button的字体属性后再使用本方法，否则会导致文字的宽度计算不正确
    func adjust(image: UIImage?,
                title: String?,
                titlePosition: UIView.ContentMode,
                additionalSpacing: CGFloat = 0,
                state: UIControl.State) {
        self.setImage(image, for: state)
        self.setTitle(title, for: state)
        guard let titleText = title else {
            return
        }
        adjustContentViews(title: titleText,
                           position: titlePosition,
                           spacing: additionalSpacing)
    }
    
    private func adjustContentViews(title: String,
                                    position: UIView.ContentMode,
                                    spacing: CGFloat) {
        
        let imageSize = imageView?.intrinsicContentSize ?? CGSize.zero
        let textSize = titleLabel?.intrinsicContentSize ?? CGSize.zero

        var titleInsets: UIEdgeInsets
        var imageInsets: UIEdgeInsets
        
        switch position {
        case .top:       //文字在上 图片在下
            titleInsets = UIEdgeInsets(top: 0,
                                       left: -imageSize.width,
                                       bottom: imageSize.height + spacing,
                                       right: 0)
            imageInsets = UIEdgeInsets(top: textSize.height + spacing,
                                       left: 0,
                                       bottom: 0,
                                       right: -textSize.width)
        case .bottom:     //文字在下 图片在上
            titleInsets = UIEdgeInsets(top: imageSize.height + spacing,
                                       left: -imageSize.width,
                                       bottom: 0,
                                       right: 0)
            imageInsets = UIEdgeInsets(top: 0,
                                       left: 0,
                                       bottom: textSize.height + spacing,
                                       right: -textSize.width)
        case .left:       //文字在左 图片在右
            titleInsets = UIEdgeInsets(top: 0,
                                       left: -imageSize.width - spacing / 2,
                                       bottom: 0,
                                       right: imageSize.width + spacing / 2)
            imageInsets = UIEdgeInsets(top: 0,
                                       left: textSize.width + spacing / 2,
                                       bottom: 0,
                                       right: -textSize.width - spacing / 2)
        case .right:      //文字在右 图片在左
            titleInsets = UIEdgeInsets(top: 0,
                                       left: spacing / 2,
                                       bottom: 0,
                                       right: -spacing / 2)
            imageInsets = UIEdgeInsets(top: 0,
                                       left: -spacing / 2,
                                       bottom: 0,
                                       right: spacing / 2)
        default:
            titleInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        }
        self.titleEdgeInsets = titleInsets
        self.imageEdgeInsets = imageInsets
    }
}

extension UIEdgeInsets {
    
    static func all(_ value: CGFloat) -> UIEdgeInsets {
        return UIEdgeInsets(top: value, left: value, bottom: value, right: value)
    }
}


import Toast_Swift

extension UIViewController {
    
    /// Show a toast message with default settings
    /// - Parameters:
    ///   - message: The message to display
    ///   - duration: Duration in seconds (default: 3.0)
    ///   - completion: Optional completion handler
    
}
