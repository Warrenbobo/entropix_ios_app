//
//  LMLlmTaskRuntime.swift
//  processor
//
//  Shared Explore / Tips LLM slots with CompleteFetch + background semantics (§8).
//

import Foundation
import UIKit

/// Non-preempting LLM task slots for Scene Explore and Get Tips.
enum LMLlmTaskSlot: Hashable {
    case explore
    case tips
}

/// Cached result for a slot after CompleteFetch / SSE finishes.
struct LMLlmTaskCacheEntry: Sendable {
    let fullText: String
    let httpCode: Int
    let errorBody: String?
    let completedAt: Date
}

/**
 Cross-page LLM request runtime (§8).

 - Explore prefers CompleteFetch (`stream: false`).
 - Tips prefer SSE in foreground; on background cancel → CompleteFetch.
 - Leaving camera cancels all slots and clears caches.
 */
final class LMLlmTaskRuntime: @unchecked Sendable {
    static let shared = LMLlmTaskRuntime()

    private let lock = NSLock()
    private var tasks: [LMLlmTaskSlot: Task<Void, Never>] = [:]
    private var caches: [LMLlmTaskSlot: LMLlmTaskCacheEntry] = [:]
    private var backgroundTaskIds: [LMLlmTaskSlot: UIBackgroundTaskIdentifier] = [:]
    private var tipsPreferComplete = false
    private var completeRetryRemaining: [LMLlmTaskSlot: Int] = [:]

    private let chatClient = LMDashScopeChatClient()
    private let maxCompleteRetries = 1

    private init() {}

    /// Whether Tips should use CompleteFetch instead of SSE (after background cut).
    var shouldTipsUseCompleteFetch: Bool {
        lock.lock()
        defer { lock.unlock() }
        if tipsPreferComplete { return true }
        return UIApplication.shared.applicationState != .active
    }

    /// Marks Tips to switch to CompleteFetch (called on resign active).
    func markTipsPreferCompleteFetch() {
        lock.lock()
        tipsPreferComplete = true
        lock.unlock()
    }

    /// Clears Tips CompleteFetch preference after a successful round or leave.
    func clearTipsPreferCompleteFetch() {
        lock.lock()
        tipsPreferComplete = false
        lock.unlock()
    }

    /**
     Runs Scene Explore CompleteFetch under the Explore slot.

     - Parameters:
       - baseUrl: OpenAI-compatible base URL.
       - apiKey: Bearer token.
       - requestBody: Chat body; `stream` forced to false.
     */
    func runExploreComplete(
        baseUrl: String,
        apiKey: String,
        requestBody: [String: Any]
    ) async -> LMStreamResult {
        cancel(slot: .explore, clearCache: false)
        beginBackgroundTask(for: .explore)
        defer { endBackgroundTask(for: .explore) }

        var body = requestBody
        body["stream"] = false

        let result = await chatClient.completeChatCompletion(
            baseUrl: baseUrl,
            apiKey: apiKey,
            requestBody: body
        )

        if Self.isRetryableFailure(result), retryBudget(for: .explore) > 0 {
            consumeRetry(for: .explore)
            let retry = await chatClient.completeChatCompletion(
                baseUrl: baseUrl,
                apiKey: apiKey,
                requestBody: body
            )
            storeCache(.explore, result: retry)
            return retry
        }

        storeCache(.explore, result: result)
        return result
    }

    /**
     Runs Tips chat — SSE when foreground-active preference, else CompleteFetch.

     - Parameters:
       - baseUrl: Base URL.
       - apiKey: API key.
       - requestBody: Request body (stream flag adjusted).
       - onDelta: SSE delta callback (ignored for CompleteFetch; full text synthesized).
     */
    func runTipsChat(
        baseUrl: String,
        apiKey: String,
        requestBody: [String: Any],
        onDelta: @escaping @Sendable (LMStreamDelta) -> Void
    ) async -> LMStreamResult {
        let useComplete = shouldTipsUseCompleteFetch
        beginBackgroundTask(for: .tips)
        defer { endBackgroundTask(for: .tips) }

        if useComplete {
            var body = requestBody
            body["stream"] = false
            let result = await chatClient.completeChatCompletion(
                baseUrl: baseUrl,
                apiKey: apiKey,
                requestBody: body
            )
            if !result.fullText.isEmpty {
                onDelta(LMStreamDelta(reasoningContent: nil, content: result.fullText))
            }
            if Self.isRetryableFailure(result), retryBudget(for: .tips) > 0 {
                consumeRetry(for: .tips)
                let retry = await chatClient.completeChatCompletion(
                    baseUrl: baseUrl,
                    apiKey: apiKey,
                    requestBody: body
                )
                if !retry.fullText.isEmpty {
                    onDelta(LMStreamDelta(reasoningContent: nil, content: retry.fullText))
                }
                storeCache(.tips, result: retry)
                clearTipsPreferCompleteFetch()
                return retry
            }
            storeCache(.tips, result: result)
            clearTipsPreferCompleteFetch()
            return result
        }

        var body = requestBody
        body["stream"] = true
        let result = await chatClient.streamChatCompletion(
            baseUrl: baseUrl,
            apiKey: apiKey,
            requestBody: body,
            onDelta: onDelta
        )

        // Background cut mid-SSE → CompleteFetch with same payload.
        if Task.isCancelled || Self.isRetryableFailure(result) {
            markTipsPreferCompleteFetch()
            var completeBody = requestBody
            completeBody["stream"] = false
            let complete = await chatClient.completeChatCompletion(
                baseUrl: baseUrl,
                apiKey: apiKey,
                requestBody: completeBody
            )
            if !complete.fullText.isEmpty {
                onDelta(LMStreamDelta(reasoningContent: nil, content: complete.fullText))
            }
            storeCache(.tips, result: complete)
            clearTipsPreferCompleteFetch()
            return complete
        }

        storeCache(.tips, result: result)
        return result
    }

    /// Cancels an in-flight slot task.
    func cancel(slot: LMLlmTaskSlot, clearCache: Bool = true) {
        lock.lock()
        tasks[slot]?.cancel()
        tasks[slot] = nil
        if clearCache {
            caches[slot] = nil
            completeRetryRemaining[slot] = nil
        }
        lock.unlock()
        endBackgroundTask(for: slot)
    }

    /// Cancels Explore + Tips and clears caches (leave camera).
    func cancelAll() {
        cancel(slot: .explore)
        cancel(slot: .tips)
        clearTipsPreferCompleteFetch()
    }

    /// Returns cached result if present.
    func cachedResult(for slot: LMLlmTaskSlot) -> LMLlmTaskCacheEntry? {
        lock.lock()
        defer { lock.unlock() }
        return caches[slot]
    }

    /// True when failure looks like background abort / connectivity cut (§8).
    static func isRetryableFailure(_ result: LMStreamResult) -> Bool {
        if (200...299).contains(result.httpCode) { return false }
        let body = (result.errorBody ?? "").lowercased()
        if body.contains("cancel") { return true }
        if body.contains("abort") { return true }
        if body.contains("network connection was lost") { return true }
        if body.contains("software caused connection abort") { return true }
        if body.contains("timed out") { return true }
        if result.httpCode == 0 && !(result.errorBody?.isEmpty ?? true) { return true }
        return false
    }

    /// User-facing copy for retryable network / background cuts.
    static func retryableErrorMessage(for result: LMStreamResult) -> String {
        if isRetryableFailure(result) {
            return LMText.camera.llmRetryableNetworkError
        }
        return result.errorBody ?? LMText.camera.exploreFailed
    }

    private func storeCache(_ slot: LMLlmTaskSlot, result: LMStreamResult) {
        lock.lock()
        caches[slot] = LMLlmTaskCacheEntry(
            fullText: result.fullText,
            httpCode: result.httpCode,
            errorBody: result.errorBody,
            completedAt: Date()
        )
        lock.unlock()
    }

    private func retryBudget(for slot: LMLlmTaskSlot) -> Int {
        lock.lock()
        defer { lock.unlock() }
        if let remaining = completeRetryRemaining[slot] {
            return remaining
        }
        completeRetryRemaining[slot] = maxCompleteRetries
        return maxCompleteRetries
    }

    private func consumeRetry(for slot: LMLlmTaskSlot) {
        lock.lock()
        let current = completeRetryRemaining[slot] ?? maxCompleteRetries
        completeRetryRemaining[slot] = max(0, current - 1)
        lock.unlock()
    }

    private func beginBackgroundTask(for slot: LMLlmTaskSlot) {
        var bgId = UIBackgroundTaskIdentifier.invalid
        bgId = UIApplication.shared.beginBackgroundTask(withName: "LMLlmTask.\(slot)") { [weak self] in
            self?.endBackgroundTask(for: slot)
        }
        lock.lock()
        backgroundTaskIds[slot] = bgId
        lock.unlock()
    }

    private func endBackgroundTask(for slot: LMLlmTaskSlot) {
        lock.lock()
        let id = backgroundTaskIds[slot] ?? .invalid
        backgroundTaskIds[slot] = nil
        lock.unlock()
        if id != .invalid {
            UIApplication.shared.endBackgroundTask(id)
        }
    }
}
