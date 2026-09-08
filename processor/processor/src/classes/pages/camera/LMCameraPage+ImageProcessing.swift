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

// MARK: - Scene Analysis
extension LMCameraPage {
    
    /// 使用 EVA02 分析场景
    func analyzeSceneWithFastVLM(_ image: UIImage) -> [Float]? {
#if DEBUG
        if let debugInspireMeSceneFeatureOverride {
            return debugInspireMeSceneFeatureOverride(image)
        }
#endif
        LMLogger.log("🔍 Analyzing scene with EVA02...")
        
        do {
            let imageProcessor = LMImageProcessor.forEVA02()
            let multiArray = try imageProcessor.processImage(image)
            
            LMLogger.log("✅ Image processed: shape=\(multiArray.shape), count=\(multiArray.count)")
            
            let output = try LMEVA02ModelProvider.predictEmbedding(from: multiArray)
            guard var embedding = extractEmbedding(from: output) else {
                LMLogger.log("❌ Failed to extract EVA02 embedding")
                return nil
            }
            LMCompositionMath.l2Normalize(&embedding)
            LMLogger.log("✅ EVA02 inference completed, embedding dimension: \(embedding.count)")
            LMAgentRequestLogRecorder.recordInspireMeEva02(embedding: embedding)
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
        guard LMFeatureFlagsManager.backendApiEnabled else {
            finishOfflineInspireMe()
            return
        }

        LMLogger.log("📤 Processing and uploading image...")
        
        // PRD 3.13.3.4: 压缩图像，长边≤1080px
        guard let compressedImage = compressImage(image, maxLongSide: 1080) else {
            DispatchQueue.main.async { [weak self] in
                self?.hideProcessingOverlay()
                self?.isInspireMeCapture = false
                AppTheme.Toast.showText(LMText.camera.imageCompressionFailed)
            }
            return
        }
        
        let aspectRatio = calculateAspectRatio(compressedImage)
        
        guard let embeddings = sceneFeature else {
            DispatchQueue.main.async { [weak self] in
                self?.hideProcessingOverlay()
                self?.isInspireMeCapture = false
                AppTheme.Toast.showText(LMText.camera.analysisFailed)
            }
            return
        }

        let handleResponse: LMApiCallback<LMCompositionTaskResponse> = { [weak self] response in
            self?.hideProcessingOverlay()
            self?.isInspireMeCapture = false
            
            if response.requestSuccess, let data = response.value {
                LMLogger.log("✅ Task submitted: \(data.taskId ?? "unknown")")
                self?.navigateToShowSuggestions(data)
            } else {
                LMLogger.log("❌ Task submission failed: \(response.message ?? "Unknown error")")
                
                if self?.isSubscriptionExpiredError(response) == true {
                    self?.showSubscriptionExpiredAlert()
                } else {
                    let errorMessage = response.message ?? LMText.camera.analysisFailed
                    AppTheme.Toast.showText(errorMessage)
                }
            }
        }

#if DEBUG
        if let debugInspireMeCompositionSubmitter {
            debugInspireMeCompositionSubmitter(
                image,
                compressedImage,
                embeddings,
                aspectRatio,
                handleResponse
            )
            return
        }
#endif
        
        LMCompositionService.shared.submitCompositionTask(
            originalImage: image,
            compressedImage: compressedImage,
            embeddings: embeddings,
            aspectRatio: aspectRatio,
            sceneType: nil
        ) { response in
            handleResponse(response)
        }
    }

    /**
     Direct Gemini Inspire Me: show 4 placeholders immediately, then replace with local tiles.

     Skips EVA02 upload and Composition `/analyze` / job polling.
     */
    func processAndGenerateDirectGemini(_ image: UIImage) {
        LMLogger.log("📤 Processing Inspire Me via direct Gemini...")

        guard let compressedImage = compressImage(image, maxLongSide: AppConfigs.Gemini.inputMaxLongSide) else {
            DispatchQueue.main.async { [weak self] in
                self?.hideProcessingOverlay()
                self?.isInspireMeCapture = false
                AppTheme.Toast.showText(LMText.camera.imageCompressionFailed)
            }
            return
        }

        let aspectRatio = LMCompositionService.snapAspectRatio(calculateAspectRatio(compressedImage))
        let taskId = "local_gemini_\(UUID().uuidString)"
        let placeholders = LMCompositionService.shared.makeDirectGeminiPlaceholders()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.hideProcessingOverlay()
            self.isInspireMeCapture = false
            self.enterShowSuggestionsState(taskId: taskId, suggestions: placeholders)
        }

        let appendix = pendingSpotPromptAppendix
        pendingSpotPromptAppendix = nil
        if let session = exploreSession {
            session.inspireTaskId = taskId
        }

        LMCompositionService.shared.generateSuggestionsDirectly(
            sceneImage: image,
            aspectRatio: aspectRatio,
            sessionId: taskId,
            spotPromptAppendix: appendix
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let suggestions):
                self.updateSuggestionsWithNewData(suggestions)
                self.cleanupInvalidSuggestions()
                LMLogger.log("✅ Direct Gemini suggestions ready: \(suggestions.count)")
            case .failure(let error):
                let message = (error as? LocalizedError)?.errorDescription
                    ?? error.localizedDescription
                LMLogger.log("❌ Direct Gemini failed: \(message)")
                AppTheme.Toast.showText(message)
                self.cleanupInvalidSuggestions()
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
    
    /// Offline Inspire Me: always transition processing → demo suggestions regardless of scene analysis.
    func finishOfflineInspireMe() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            guard let self else { return }
            let demoSuggestions = LMDemoSuggestionsLoader.loadSuggestions()
            self.hideProcessingOverlay()
            self.isInspireMeCapture = false
            if demoSuggestions.isEmpty {
                AppTheme.Toast.showText("No demo images found in assets/\(AppConfigs.demoSuggestionsDir)/")
                return
            }
            self.enterShowSuggestionsState(taskId: "demo_task", suggestions: demoSuggestions)
        }
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
