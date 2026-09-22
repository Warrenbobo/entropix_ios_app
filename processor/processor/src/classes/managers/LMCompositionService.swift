//
//  LMCompositionService.swift
//  processor
//
//  Created by muz on 2025/11/9.
//

import UIKit

enum LMCompositionTaskResultEventType: String {
    case like = "Like"
    case shot = "Shot"
}

class LMCompositionService {
    
    static let shared = LMCompositionService()
    
    private init() {}
    
    // MARK: - Type Aliases
    typealias CompositionTaskResponse = LMCompositionTaskResponse
    typealias CompositionStatusResponse = LMCompositionSuggestionsResponse
    typealias ConfirmSuggestionResponse = LMConfirmSuggestionResponse
    typealias CompositionHistoryResponse = LMCompositionResultsResponse
    typealias CompositionTaskResultResponse = LMEmptyModel
    
    // MARK: - 提交构图任务
    
    /// 提交构图任务
    /// - Parameters:
    ///   - originalImage: 原始场景图
    ///   - compressedImage: 压缩后的场景图（PRD 要求长边≤1080px）
    ///   - embeddings: 图像向量（768维）
    ///   - aspectRatio: 宽高比
    ///   - sceneType: 场景类型（可选）
    ///   - completion: 完成回调（使用统一的 LMApiCallback）
    func submitCompositionTask(
        originalImage: UIImage,
        compressedImage: UIImage,
        embeddings: [Float],
        aspectRatio: String,
        sceneType: String? = nil,
        completion: @escaping LMApiCallback<CompositionTaskResponse>
    ) {
        LMLogger.log("📤 Submitting composition task...")
        
        LMApiService.shared.submitCompositionTask(
            originalImage: originalImage,
            compressedImage: compressedImage,
            embeddings: embeddings,
            aspectRatio: aspectRatio,
            sceneType: sceneType,
            completion: completion
        )
    }
    
    // MARK: - 轮询任务状态
    
    /// 轮询任务状态
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - completion: 完成回调（使用统一的 LMApiCallback）
    func pollTaskStatus(
        taskId: String,
        completion: @escaping LMApiCallback<CompositionStatusResponse>
    ) {
        LMApiService.shared.getSuggestions(taskId: taskId, completion: completion)
    }
    
    // MARK: - 确认建议
    
    /// 确认选中的建议
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - suggestionId: 建议ID
    ///   - completion: 完成回调（使用统一的 LMApiCallback）
    func confirmSuggestion(
        taskId: String,
        suggestionId: String,
        completion: @escaping LMApiCallback<ConfirmSuggestionResponse>
    ) {
        LMApiService.shared.confirmSuggestion(
            taskId: taskId,
            suggestionId: suggestionId,
            completion: completion
        )
    }
    
    /// 上报 Suggestion 任务结果
    /// - Parameters:
    ///   - taskId: 任务ID
    ///   - eventType: 事件类型（如 Shot）
    ///   - suggestionId: 建议ID
    ///   - finalized: 是否为任务结束上报
    ///   - completion: 完成回调
    func reportSuggestionTaskResult(
        taskId: String,
        eventType: LMCompositionTaskResultEventType? = nil,
        suggestionId: String? = nil,
        finalized: Bool,
        completion: @escaping LMApiCallback<CompositionTaskResultResponse>
    ) {
        LMApiService.shared.reportSuggestionTaskResult(
            taskId: taskId,
            eventType: eventType,
            suggestionId: suggestionId,
            finalized: finalized,
            completion: completion
        )
    }
    
    // MARK: - 获取历史记录
    
    /// 获取历史构图结果
    /// - Parameters:
    ///   - page: 页码
    ///   - number: 每页数量
    ///   - completion: 完成回调（使用统一的 LMApiCallback）
    func fetchHistory(
        page: Int = 1,
        number: Int = 4,
        completion: @escaping LMApiCallback<CompositionHistoryResponse>
    ) {
        LMApiService.shared.getCompositionResults(
            page: page,
            number: number,
            completion: completion
        )
    }

    // MARK: - Direct Gemini Inspire Me

    /**
     Builds four AIGC placeholders (ranks 1…4) for the direct-Gemini carousel path.
     */
    func makeDirectGeminiPlaceholders() -> [LMCompositionSuggestion] {
        (1...AppConfigs.Gemini.placeholderCount).map { rank in
            LMCompositionSuggestion(
                id: UUID().uuidString,
                sceneType: nil,
                source: "placeholder",
                ready: false,
                imageUrl: nil,
                width: nil,
                height: nil,
                rank: rank,
                score: nil
            )
        }
    }

    /**
     Runs device → Gemini generation, splits/persists tiles, returns ready suggestions.

     Does **not** call Composition `/analyze` or job APIs.

     - Parameters:
       - sessionId: Existing `local_gemini_*` id (matches carousel placeholders).
       - mode: FREE_COMPOSITION (Normal / Path B) or FIXED_CAMERA (Path A).
       - spot: Required for FIXED_CAMERA; ignored for free mode.
     */
    func generateSuggestionsDirectly(
        sceneImage: UIImage,
        aspectRatio: String,
        sessionId: String,
        mode: LMInspireGenerationMode = .freeComposition,
        spot: LMSceneExploreSpot? = nil,
        completion: @escaping (Result<[LMCompositionSuggestion], Error>) -> Void
    ) {
        let settings = LMGeminiModelSettingsStore.load()
        guard settings.isConfigured else {
            completion(.failure(LMGeminiImageError.invalidSettings))
            return
        }

        let requestStart = Date()
        let hasCameraInstruction = !(spot?.cameraInstruction?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        LMLogger.log(
            "inspire.request_start mode=\(mode.rawValue) taskId=\(sessionId) " +
            "spotId=\(spot?.id ?? "nil") cameraInstruction=\(hasCameraInstruction) " +
            "model=\(settings.model.rawValue)"
        )

        let feature = LMGeminiInspireConfigRepository.shared.get()
        guard let compressed = compressForGemini(sceneImage, maxLong: feature.inputLongEdge),
              let jpeg = compressed.jpegData(compressionQuality: feature.jpegQuality) else {
            LMLogger.log("inspire.fail mode=\(mode.rawValue) taskId=\(sessionId) reason=compress")
            completion(.failure(LMGeminiImageError.decodeFailed))
            return
        }

        let snapped = Self.snapAspectRatio(aspectRatio)
        let prompt = LMInspirePromptBuilder.build(
            mode: mode,
            aspectRatio: snapped,
            spot: mode == .fixedCamera ? spot : nil
        )

        LMGeminiImageClient.shared.generate(
            sceneJPEG: jpeg,
            mimeType: "image/jpeg",
            prompt: prompt,
            aspectRatio: snapped,
            settings: settings
        ) { [weak self] result in
            DispatchQueue.global(qos: .userInitiated).async {
                let elapsedMs = Int(Date().timeIntervalSince(requestStart) * 1000)
                switch result {
                case .failure(let error):
                    LMLogger.log(
                        "inspire.fail mode=\(mode.rawValue) taskId=\(sessionId) " +
                        "elapsedMs=\(elapsedMs) error=\(error.localizedDescription)"
                    )
                    DispatchQueue.main.async { completion(.failure(error)) }
                case .success(let images):
                    LMLogger.log(
                        "inspire.first_image mode=\(mode.rawValue) taskId=\(sessionId) " +
                        "elapsedMs=\(elapsedMs) imageCount=\(images.count)"
                    )
                    guard let self else {
                        DispatchQueue.main.async { completion(.failure(LMGeminiImageError.cancelled)) }
                        return
                    }
                    do {
                        let tiles = self.resolveTiles(from: images)
                        let suggestions = try self.persistTiles(
                            tiles,
                            sessionId: sessionId,
                            aspectRatio: snapped
                        )
                        let totalMs = Int(Date().timeIntervalSince(requestStart) * 1000)
                        LMLogger.log(
                            "inspire.success mode=\(mode.rawValue) taskId=\(sessionId) " +
                            "elapsedMs=\(totalMs) tiles=\(suggestions.count) rawImages=\(images.count)"
                        )
                        DispatchQueue.main.async { completion(.success(suggestions)) }
                    } catch {
                        LMLogger.log(
                            "inspire.fail mode=\(mode.rawValue) taskId=\(sessionId) " +
                            "elapsedMs=\(elapsedMs) error=\(error.localizedDescription)"
                        )
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }
            }
        }
    }

    /// Compresses scene for Gemini inline payload (long edge configurable).
    private func compressForGemini(_ image: UIImage, maxLong: CGFloat = AppConfigs.Gemini.inputMaxLongSide) -> UIImage? {
        let size = image.size
        let longSide = max(size.width, size.height)
        if longSide <= maxLong { return image }
        let scale = maxLong / longSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let out = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return out
    }

    /**
     Maps Gemini image outputs to four tiles.

     One collage → 2×2 split; 2…4 discrete images → pad/truncate to four ranks.
     */
    private func resolveTiles(from images: [UIImage]) -> [UIImage] {
        if images.count == 1 {
            return LMGeminiGridSplitter.split2x2(images[0])
        }
        var tiles = Array(images.prefix(AppConfigs.Gemini.placeholderCount))
        while tiles.count < AppConfigs.Gemini.placeholderCount, let last = tiles.last {
            tiles.append(last)
        }
        return tiles
    }

    /// Writes tiles under Caches/`inspire_gemini`/{session}/q{n}.jpg and builds suggestions.
    private func persistTiles(
        _ tiles: [UIImage],
        sessionId: String,
        aspectRatio: String
    ) throws -> [LMCompositionSuggestion] {
        let fm = FileManager.default
        let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let root = caches.appendingPathComponent(AppConfigs.Gemini.cacheDirectoryName, isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        Self.cleanupOldGeminiSessions(root: root, keeping: sessionId)

        let sessionDir = root.appendingPathComponent(sessionId, isDirectory: true)
        try fm.createDirectory(at: sessionDir, withIntermediateDirectories: true)

        var suggestions: [LMCompositionSuggestion] = []
        for (index, tile) in tiles.enumerated() {
            let rank = index + 1
            let fileURL = sessionDir.appendingPathComponent("q\(rank).jpg")
            guard let data = tile.jpegData(compressionQuality: 0.92) else { continue }
            try data.write(to: fileURL, options: .atomic)
            let pixelW = Int(tile.size.width * tile.scale)
            let pixelH = Int(tile.size.height * tile.scale)
            suggestions.append(
                LMCompositionSuggestion(
                    id: UUID().uuidString,
                    sceneType: nil,
                    source: "generated",
                    ready: true,
                    imageUrl: fileURL.absoluteString,
                    width: pixelW,
                    height: pixelH,
                    rank: rank,
                    score: 0.9
                )
            )
        }
        guard suggestions.count == AppConfigs.Gemini.placeholderCount else {
            throw LMGeminiImageError.noImage
        }
        LMLogger.log("✅ Persisted \(suggestions.count) Gemini tiles aspect=\(aspectRatio) → \(sessionDir.path)")
        return suggestions
    }

    /// Best-effort cleanup of prior `inspire_gemini` sessions.
    private static func cleanupOldGeminiSessions(root: URL, keeping sessionId: String) {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in children where url.lastPathComponent != sessionId {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /**
     Snaps a camera aspect string to a Gemini-supported value (default `3:4`).
     */
    static func snapAspectRatio(_ raw: String) -> String {
        let supported: [(String, Double)] = [
            ("1:1", 1.0),
            ("2:3", 2.0 / 3.0),
            ("3:2", 3.0 / 2.0),
            ("3:4", 3.0 / 4.0),
            ("4:3", 4.0 / 3.0),
            ("4:5", 4.0 / 5.0),
            ("5:4", 5.0 / 4.0),
            ("9:16", 9.0 / 16.0),
            ("16:9", 16.0 / 9.0),
            ("21:9", 21.0 / 9.0)
        ]
        if supported.contains(where: { $0.0 == raw }) {
            return raw
        }
        let parts = raw.split(separator: ":").compactMap { Double($0) }
        let ratio: Double
        if parts.count == 2, parts[1] != 0 {
            ratio = parts[0] / parts[1]
        } else {
            return "3:4"
        }
        let nearest = supported.min { abs($0.1 - ratio) < abs($1.1 - ratio) }
        return nearest?.0 ?? "3:4"
    }
}
