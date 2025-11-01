//
//  ImageProcessor.swift
//  cam
//
//  Created by Ziyang Ye on 29/10/2025.
//

import UIKit
import CoreML
import CoreVideo


enum ImageProcessingError: Error, LocalizedError {
    case invalidImage
    case resizeFailed
    case pixelBufferCreationFailed
    case multiArrayConversionFailed
    case invalidInputSize
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image"
        case .resizeFailed:
            return "Image resize failed"
        case .pixelBufferCreationFailed:
            return "Failed to create pixel buffer"
        case .multiArrayConversionFailed:
            return "Failed to convert to MLMultiArray"
        case .invalidInputSize:
            return "Invalid input size"
        }
    }
}


class ImageProcessor {
    
    
    struct ProcessingConfig {
        let targetSize: CGSize
        let normalizeValues: Bool
        let meanValues: [Float]
        let standardDeviationValues: [Float]
        
        
        static let eva02Default = ProcessingConfig(
            targetSize: CGSize(width: 336, height: 336),
            normalizeValues: true,
            meanValues: [0.485, 0.456, 0.406], 
            standardDeviationValues: [0.229, 0.224, 0.225]
        )
        
        
        static let basic = ProcessingConfig(
            targetSize: CGSize(width: 448, height: 448),
            normalizeValues: false,
            meanValues: [],
            standardDeviationValues: []
        )
    }
    
    private let config: ProcessingConfig
    
    
    
    init(config: ProcessingConfig = .eva02Default) {
        self.config = config
    }
    
    
    
    
    func processImage(_ image: UIImage) throws -> MLMultiArray {
        
        guard image.cgImage != nil else {
            throw ImageProcessingError.invalidImage
        }
        
        
        let resizedImage = try resizeImage(image, to: config.targetSize)
        
        
        let pixelBuffer = try createPixelBuffer(from: resizedImage)
        
        
        let multiArray = try convertToMLMultiArray(pixelBuffer: pixelBuffer)
        
        return multiArray
    }
    
    
    
    
    
    
    func resizeImage(_ image: UIImage, to size: CGSize) throws -> UIImage {
        guard size.width > 0 && size.height > 0 else {
            throw ImageProcessingError.invalidInputSize
        }
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        
        guard resizedImage.cgImage != nil else {
            throw ImageProcessingError.resizeFailed
        }
        
        return resizedImage
    }
    
    
    private func createPixelBuffer(from image: UIImage) throws -> CVPixelBuffer {
        let width = Int(config.targetSize.width)
        let height = Int(config.targetSize.height)
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            nil,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw ImageProcessingError.pixelBufferCreationFailed
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            throw ImageProcessingError.pixelBufferCreationFailed
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        
        return buffer
    }
    
    
    private func convertToMLMultiArray(pixelBuffer: CVPixelBuffer) throws -> MLMultiArray {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        
        guard let multiArray = try? MLMultiArray(
            shape: [1, 3, NSNumber(value: height), NSNumber(value: width)],
            dataType: .float32
        ) else {
            throw ImageProcessingError.multiArrayConversionFailed
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly) }
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw ImageProcessingError.multiArrayConversionFailed
        }
        
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * 4
                
                
                var r = Float(buffer[pixelIndex + 1]) / 255.0
                var g = Float(buffer[pixelIndex + 2]) / 255.0
                var b = Float(buffer[pixelIndex + 3]) / 255.0
                
                
                if config.normalizeValues && config.meanValues.count == 3 && config.standardDeviationValues.count == 3 {
                    r = (r - config.meanValues[0]) / config.standardDeviationValues[0]
                    g = (g - config.meanValues[1]) / config.standardDeviationValues[1]
                    b = (b - config.meanValues[2]) / config.standardDeviationValues[2]
                }
                
                
                multiArray[[0, 0, y, x] as [NSNumber]] = NSNumber(value: r)
                multiArray[[0, 1, y, x] as [NSNumber]] = NSNumber(value: g)
                multiArray[[0, 2, y, x] as [NSNumber]] = NSNumber(value: b)
            }
        }
        
        return multiArray
    }
    
    
    func getProcessedImageInfo(originalSize: CGSize) -> String {
        return """
        Original size: \(Int(originalSize.width)) x \(Int(originalSize.height))
        Processed size: \(Int(config.targetSize.width)) x \(Int(config.targetSize.height))
        Normalize: \(config.normalizeValues ? "Yes" : "No")
        """
    }
}


extension ImageProcessor {
    
    
    static func forEVA02() -> ImageProcessor {
        return ImageProcessor(config: .eva02Default)
    }
    
    
    static func basic(targetSize: CGSize = CGSize(width: 448, height: 448)) -> ImageProcessor {
        return ImageProcessor(config: ProcessingConfig(
            targetSize: targetSize,
            normalizeValues: false,
            meanValues: [],
            standardDeviationValues: []
        ))
    }
    
    
    static func custom(
        targetSize: CGSize,
        normalizeValues: Bool = true,
        meanValues: [Float] = [0.485, 0.456, 0.406],
        standardDeviationValues: [Float] = [0.229, 0.224, 0.225]
    ) -> ImageProcessor {
        return ImageProcessor(config: ProcessingConfig(
            targetSize: targetSize,
            normalizeValues: normalizeValues,
            meanValues: meanValues,
            standardDeviationValues: standardDeviationValues
        ))
    }
}
