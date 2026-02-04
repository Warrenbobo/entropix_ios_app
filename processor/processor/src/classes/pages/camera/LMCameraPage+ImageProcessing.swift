//
//  LMCameraPage+ImageProcessing.swift
//  processor
//
//  Image processing, blur detection, and scene analysis
//

import UIKit
import CoreML

// MARK: - Blur Detection
extension LMCameraPage {
    
    /// 检测图像是否模糊
    func detectImageBlur(_ image: UIImage) -> Bool {
        guard let grayImage = convertToGrayscale(image) else {
            LMLogger.log("❌ Failed to convert image to grayscale")
            return true
        }
        
        guard let variance = calculateLaplacianVariance(grayImage) else {
            LMLogger.log("❌ Failed to calculate Laplacian variance")
            return true
        }
        
        let isBlur = variance <= 200
        LMLogger.log("📊 Blur detection: variance=\(variance), isBlur=\(isBlur)")
        
        return isBlur
    }
    
    /// 将图像转换为灰度图
    func convertToGrayscale(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let grayImage = context.makeImage() else { return nil }
        
        return UIImage(cgImage: grayImage)
    }
    
    /// 计算 Laplacian 滤波后的方差
    func calculateLaplacianVariance(_ image: UIImage) -> Double? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }
        
        var sum: Double = 0
        var sumSquared: Double = 0
        var count: Int = 0
        
        for y in 1..<(height-1) {
            for x in 1..<(width-1) {
                let center = Double(bytes[y * width + x])
                let top = Double(bytes[(y-1) * width + x])
                let bottom = Double(bytes[(y+1) * width + x])
                let left = Double(bytes[y * width + (x-1)])
                let right = Double(bytes[y * width + (x+1)])
                
                let laplacian = top + bottom + left + right - 4 * center
                
                sum += laplacian
                sumSquared += laplacian * laplacian
                count += 1
            }
        }
        
        let mean = sum / Double(count)
        let variance = (sumSquared / Double(count)) - (mean * mean)
        
        return variance
    }
}

// MARK: - Orientation Normalization
extension LMCameraPage {
    
    /// 将图像统一渲染为竖屏（home键在下方）的预览样式，并固化为 `.up` 方向。
    /// - Note: 用于 `analyzeSceneWithFastVLM` 以及提交构图任务时，避免后端/模型忽略 EXIF 方向导致的旋转问题。
    func normalizeImageForCompositionTaskPortrait(
        _ image: UIImage,
        capturedDeviceOrientation: UIDeviceOrientation
    ) -> UIImage? {
        // 只接受有效方向，其余（faceUp/faceDown/unknown）按 portrait 处理
        let orientation: UIDeviceOrientation
        switch capturedDeviceOrientation {
        case .portrait, .landscapeLeft, .landscapeRight, .portraitUpsideDown:
            orientation = capturedDeviceOrientation
        default:
            orientation = .portrait
        }
        
        // 将“当前手持方向”的画面旋转回 portrait（home键在下方）
        let rotationToPortrait = -rotationAngle(for: orientation)
        
        let originalSize = image.size
        let outputSize: CGSize
        if abs(rotationToPortrait) == .pi / 2 {
            outputSize = CGSize(width: originalSize.height, height: originalSize.width)
        } else {
            outputSize = originalSize
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let rendered = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            context.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.rotate(by: rotationToPortrait)
            
            // 以中心点为基准绘制，确保旋转后不偏移
            image.draw(
                in: CGRect(
                    x: -originalSize.width / 2,
                    y: -originalSize.height / 2,
                    width: originalSize.width,
                    height: originalSize.height
                )
            )
        }
        
        return rendered
    }
    
    private func rotationAngle(for orientation: UIDeviceOrientation) -> CGFloat {
        switch orientation {
        case .portrait:
            return 0
        case .landscapeLeft:
            return .pi / 2
        case .portraitUpsideDown:
            return .pi
        case .landscapeRight:
            return -.pi / 2
        default:
            return 0
        }
    }
}

// MARK: - Scene Analysis
extension LMCameraPage {
    
    /// 使用 EVA02 分析场景
    func analyzeSceneWithFastVLM(_ image: UIImage) -> [Float]? {
        LMLogger.log("🔍 Analyzing scene with EVA02...")
        
        do {
            let imageProcessor = LMImageProcessor.forEVA02()
            let multiArray = try imageProcessor.processImage(image)
            
            LMLogger.log("✅ Image processed: shape=\(multiArray.shape), count=\(multiArray.count)")
            
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            guard let model = try? EVA02(configuration: configuration) else {
                LMLogger.log("❌ Failed to load EVA02 model")
                return nil
            }
            let output = try model.prediction(image: multiArray)
            let embedding = extractEmbedding(from: output)
            LMLogger.log("✅ EVA02 inference completed, embedding dimension: \(embedding?.count ?? 0)")
            return embedding
        } catch {
            LMLogger.log("❌ Failed to process image with ImageProcessor: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 从模型输出中提取 embedding
    func extractEmbedding(from output: Any) -> [Float]? {
        if let outputObject = output as? EVA02Output {
            let multiArray = outputObject.input0_1
            let count = multiArray.count
            var embedding = [Float](repeating: 0, count: count)
            for i in 0..<count {
                embedding[i] = multiArray[i].floatValue
            }
            return embedding
        }
        return nil
    }
}

// MARK: - Image Compression and Upload
extension LMCameraPage {
    
    /// 压缩图像（长边不超过指定尺寸）
    func compressImage(_ image: UIImage, maxLongSide: CGFloat) -> UIImage? {
        let size = image.size
        let longSide = max(size.width, size.height)
        
        if longSide <= maxLongSide {
            return image
        }
        
        let scale = maxLongSide / longSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let compressedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return compressedImage
    }
    
    /// 计算图像宽高比
    func calculateAspectRatio(_ image: UIImage) -> String {
        let size = image.size
        let ratio = size.width / size.height
        
        if abs(ratio - 3.0/4.0) < 0.1 {
            return "3:4"
        } else if abs(ratio - 1.0) < 0.1 {
            return "1:1"
        } else if abs(ratio - 9.0/16.0) < 0.1 {
            return "9:16"
        } else {
            return "\(Int(size.width)):\(Int(size.height))"
        }
    }
    
    /// 处理并上传图像到后端
    func processAndUploadImage(_ image: UIImage, sceneFeature: [Float]?) {
        LMLogger.log("📤 Processing and uploading image...")
        
        // PRD 3.13.3.4: 压缩图像，长边≤1080px
        guard let compressedImage = compressImage(image, maxLongSide: 1080) else {
            hideProcessingOverlay()
            isInspireMeCapture = false
            AppTheme.Toast.showText(LMText.camera.imageCompressionFailed)
            return
        }
        
        let aspectRatio = calculateAspectRatio(compressedImage)
        
        guard let embeddings = sceneFeature else {
            hideProcessingOverlay()
            isInspireMeCapture = false
            AppTheme.Toast.showText(LMText.camera.analysisFailed)
            return
        }
        
        LMCompositionService.shared.submitCompositionTask(
            originalImage: image,
            compressedImage: compressedImage,
            embeddings: embeddings,
            aspectRatio: aspectRatio,
            sceneType: nil
        ) { [weak self] response in
            self?.hideProcessingOverlay()
            self?.isInspireMeCapture = false
            
            if response.requestSuccess, let data = response.value {
                LMLogger.log("✅ Task submitted: \(data.taskId ?? "unknown")")
                self?.navigateToShowSuggestions(data)
            } else {
                LMLogger.log("❌ Task submission failed: \(response.message ?? "Unknown error")")
                
                // 检查是否为订阅失效错误
                if self?.isSubscriptionExpiredError(response) == true {
                    self?.showSubscriptionExpiredAlert()
                } else {
                    // 使用后端返回的 message，无需本地硬编码
                    let errorMessage = response.message ?? LMText.camera.analysisFailed
                    AppTheme.Toast.showText(errorMessage)
                }
            }
        }
    }
    
    /// 检查是否为订阅失效错误
    private func isSubscriptionExpiredError(_ response: LMApiResponseModel<LMCompositionTaskResponse>) -> Bool {
        guard let message = response.message?.lowercased() else { return false }
        
        // 检查错误消息中是否包含订阅相关的关键词
        let subscriptionKeywords = [
            "subscription",
            "trial",
            "expired",
            "免费试用",
            "订阅",
            "到期",
            "失效"
        ]
        
        for keyword in subscriptionKeywords {
            if message.contains(keyword.lowercased()) {
                return true
            }
        }
        
        return false
    }
    
    /// 显示订阅过期弹窗
    private func showSubscriptionExpiredAlert() {
        LMAlertDialog.showAlert(
            title: LMText.subscription.trialExpiredTitle,
            message: LMText.subscription.trialExpiredMessage,
            cancelText: LMText.subscription.gotIt,
            confirmText: LMText.subscription.getFreeTrial,
            confirmStyle: .gradient,
            onConfirm: { [weak self] in
                self?.navigateToProfile()
            }
        )
    }
    
    func navigateToShowSuggestions(_ response: CompositionTaskResponse) {
        LMLogger.log("✅ Composition analysis completed")
        LMLogger.log("📊 Received \(response.suggestions?.count) suggestions")
        
        // PRD 3.14: 在 Camera 页面内展示构图建议，不跳转到独立页面
        DispatchQueue.main.async { [weak self] in
            self?.enterShowSuggestionsState(
                taskId: response.taskId ?? "",
                suggestions: response.suggestions
            )
        }
    }
}
