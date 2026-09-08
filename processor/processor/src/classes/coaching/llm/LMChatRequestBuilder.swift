//
//  LMChatRequestBuilder.swift
//  processor
//
//  Ordered OpenAI-compatible chat completion JSON with top-level enable_thinking.
//

import Foundation

/**
 Builds chat completion request dictionaries with a stable key order:

 `model` → `stream` → `enable_thinking` → `thinking_budget` (when enabled) → `temperature` → `max_tokens` → `messages`
 */
enum LMChatRequestBuilder {

    /**
     Builds a streaming chat request body.

     - Parameters:
       - model: Provider model id.
       - enableThinking: Top-level `enable_thinking` flag.
       - thinkingBudget: Sent only when `enableThinking` is true.
       - temperature: Sampling temperature.
       - maxTokens: Max completion tokens.
       - messages: OpenAI-style messages array.
     */
    static func buildStreamingRequest(
        model: String,
        enableThinking: Bool,
        thinkingBudget: Int,
        temperature: Double,
        maxTokens: Int,
        messages: [[String: Any]]
    ) -> [String: Any] {
        // Use ordered key insertion via NSMutableDictionary bridge is unreliable;
        // JSONSerialization preserves Swift Dictionary insertion order on Apple platforms.
        var body: [String: Any] = [:]
        body["model"] = model
        body["stream"] = true
        body["enable_thinking"] = enableThinking
        if enableThinking {
            body["thinking_budget"] = thinkingBudget
        }
        body["temperature"] = temperature
        body["max_tokens"] = maxTokens
        body["messages"] = messages
        return body
    }

    /**
     Builds a non-streaming CompleteFetch chat request body (`stream: false`).

     Same field order as streaming, for OpenAI-compatible providers.
     */
    static func buildCompleteRequest(
        model: String,
        enableThinking: Bool,
        thinkingBudget: Int,
        temperature: Double,
        maxTokens: Int,
        messages: [[String: Any]]
    ) -> [String: Any] {
        var body = buildStreamingRequest(
            model: model,
            enableThinking: enableThinking,
            thinkingBudget: thinkingBudget,
            temperature: temperature,
            maxTokens: maxTokens,
            messages: messages
        )
        body["stream"] = false
        return body
    }

    /**
     Serializes a request body to JSON data without sorted keys (preserves insertion order).
     */
    static func jsonData(from body: [String: Any]) -> Data? {
        guard JSONSerialization.isValidJSONObject(body) else { return nil }
        return try? JSONSerialization.data(withJSONObject: body, options: [])
    }
}
