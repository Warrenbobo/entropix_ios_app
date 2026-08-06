//
//  LMChatRequestBuilder.swift
//  processor
//
//  DashScope compatible-mode chat request JSON with Android-aligned key order.
//  thinking_budget / enable_thinking are top-level (raw HTTP; Python SDK extra_body flattens).
//

import Foundation

/// Builds ordered chat/completions JSON bodies for the agent LLM.
enum LMChatRequestBuilder {
    /**
     Encodes a streaming instruct request.

     Key order matches the flattened DashScope compatible-mode contract:
     `model` → `stream` → `enable_thinking` → `thinking_budget` → `messages`.
     Message objects use `role` then `content`.
     */
    static func buildJSONData(
        config: LMAppConfig,
        referenceDataUrl: String,
        cameraViewDataUrl: String,
        userPrompt: String,
        enableThinking: Bool = true,
        prettyPrinted: Bool = false
    ) throws -> Data {
        let body = RequestBody(
            model: config.modelName,
            stream: true,
            enableThinking: enableThinking,
            thinkingBudget: config.thinkingBudget,
            messages: [
                Message.system(config.systemPrompt),
                Message.user(
                    text: userPrompt,
                    referenceDataUrl: referenceDataUrl,
                    cameraViewDataUrl: cameraViewDataUrl
                ),
            ]
        )
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.withoutEscapingSlashes]
        if prettyPrinted {
            formatting.insert(.prettyPrinted)
        }
        encoder.outputFormatting = formatting
        return try encoder.encode(body)
    }

    /// Pretty-printed preview string for Agent Log (same schema as the live request).
    static func buildPrettyJSONString(
        config: LMAppConfig,
        referenceDataUrl: String,
        cameraViewDataUrl: String,
        userPrompt: String,
        enableThinking: Bool = true
    ) -> String {
        guard let data = try? buildJSONData(
            config: config,
            referenceDataUrl: referenceDataUrl,
            cameraViewDataUrl: cameraViewDataUrl,
            userPrompt: userPrompt,
            enableThinking: enableThinking,
            prettyPrinted: true
        ), let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    // MARK: - Codable payload (CodingKeys declaration order = JSON key order)

    private struct RequestBody: Encodable {
        let model: String
        let stream: Bool
        let enableThinking: Bool
        let thinkingBudget: Int
        let messages: [Message]

        enum CodingKeys: String, CodingKey {
            case model
            case stream
            case enableThinking = "enable_thinking"
            case thinkingBudget = "thinking_budget"
            case messages
        }
    }

    private struct Message: Encodable {
        let role: String
        let content: Content

        enum CodingKeys: String, CodingKey {
            case role
            case content
        }

        static func system(_ text: String) -> Message {
            Message(role: "system", content: .text(text))
        }

        static func user(text: String, referenceDataUrl: String, cameraViewDataUrl: String) -> Message {
            Message(
                role: "user",
                content: .parts([
                    .text(text),
                    .imageURL(referenceDataUrl),
                    .imageURL(cameraViewDataUrl),
                ])
            )
        }
    }

    private enum Content: Encodable {
        case text(String)
        case parts([ContentPart])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let string):
                try container.encode(string)
            case .parts(let parts):
                try container.encode(parts)
            }
        }
    }

    private struct ContentPart: Encodable {
        let type: String
        let text: String?
        let imageURL: ImageURLPayload?

        enum CodingKeys: String, CodingKey {
            case type
            case text
            case imageURL = "image_url"
        }

        static func text(_ value: String) -> ContentPart {
            ContentPart(type: "text", text: value, imageURL: nil)
        }

        static func imageURL(_ url: String) -> ContentPart {
            ContentPart(type: "image_url", text: nil, imageURL: ImageURLPayload(url: url))
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            if let text {
                try container.encode(text, forKey: .text)
            }
            if let imageURL {
                try container.encode(imageURL, forKey: .imageURL)
            }
        }
    }

    private struct ImageURLPayload: Encodable {
        let url: String
    }
}
