//
//  LMDashScopeChatClient.swift
//  processor
//
//  DashScope compatible-mode chat completions via URLSession SSE streaming.
//

import Foundation

/// One SSE delta from a streaming chat completion.
struct LMStreamDelta: Sendable {
    let reasoningContent: String?
    let content: String?

    var hasPayload: Bool {
        !(reasoningContent?.isEmpty ?? true) || !(content?.isEmpty ?? true)
    }
}

/// Result of a streaming chat completion request.
struct LMStreamResult: Sendable {
    let httpCode: Int
    let fullText: String
    let rawLines: [String]
    let ttfbMs: Int64?
    let errorBody: String?
}

/// Parses DashScope/OpenAI-compatible SSE delta lines.
enum LMStreamingParser {
    static func parseDeltaLine(_ line: String) -> LMStreamDelta? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
        if payload.isEmpty || payload == "[DONE]" { return nil }
        guard let data = payload.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any] else {
            return nil
        }
        let streamDelta = LMStreamDelta(
            reasoningContent: nonNullString(delta["reasoning_content"]),
            content: nonNullString(delta["content"])
        )
        return streamDelta.hasPayload ? streamDelta : nil
    }

    private static func nonNullString(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        let text = String(describing: value)
        if text.isEmpty || text == "null" { return nil }
        return text
    }
}

/// URLSession-based DashScope chat client with SSE streaming.
final class LMDashScopeChatClient: @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Streams a chat completion; invokes `onDelta` for each parsed SSE delta.
    func streamChatCompletion(
        baseUrl: String,
        apiKey: String,
        requestBody: [String: Any],
        onDelta: @escaping @Sendable (LMStreamDelta) -> Void
    ) async -> LMStreamResult {
        let urlString = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
        guard let url = URL(string: urlString) else {
            return LMStreamResult(httpCode: 0, fullText: "", rawLines: [], ttfbMs: nil, errorBody: "Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        let startNs = DispatchTime.now().uptimeNanoseconds
        var firstChunkNs: UInt64?

        do {
            let (bytes, response) = try await session.bytes(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200...299).contains(httpCode) else {
                var errorData = Data()
                for try await byte in bytes { errorData.append(byte) }
                let errorBody = String(data: errorData, encoding: .utf8)
                return LMStreamResult(httpCode: httpCode, fullText: "", rawLines: [], ttfbMs: nil, errorBody: errorBody)
            }

            var full = ""
            var rawLines: [String] = []
            for try await line in bytes.lines {
                if line.isEmpty { continue }
                rawLines.append(line)
                guard let delta = LMStreamingParser.parseDeltaLine(line) else { continue }
                if firstChunkNs == nil { firstChunkNs = DispatchTime.now().uptimeNanoseconds }
                delta.reasoningContent.map { full += $0 }
                delta.content.map { full += $0 }
                onDelta(delta)
            }

            let ttfbMs = firstChunkNs.map { Int64(($0 - startNs) / 1_000_000) }
            return LMStreamResult(httpCode: httpCode, fullText: full, rawLines: rawLines, ttfbMs: ttfbMs, errorBody: nil)
        } catch is CancellationError {
            return LMStreamResult(
                httpCode: 0,
                fullText: "",
                rawLines: [],
                ttfbMs: nil,
                errorBody: "cancelled"
            )
        } catch {
            return LMStreamResult(httpCode: 0, fullText: "", rawLines: [], ttfbMs: nil, errorBody: error.localizedDescription)
        }
    }

    /**
     Non-streaming CompleteFetch (`stream: false`) — returns the full assistant text once.

     Parses OpenAI-compatible `choices[0].message.content` (+ optional reasoning).
     */
    func completeChatCompletion(
        baseUrl: String,
        apiKey: String,
        requestBody: [String: Any]
    ) async -> LMStreamResult {
        let urlString = baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/chat/completions"
        guard let url = URL(string: urlString) else {
            return LMStreamResult(httpCode: 0, fullText: "", rawLines: [], ttfbMs: nil, errorBody: "Invalid URL")
        }

        var body = requestBody
        body["stream"] = false

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let startNs = DispatchTime.now().uptimeNanoseconds
        do {
            let (data, response) = try await session.data(for: request)
            let httpCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            let raw = String(data: data, encoding: .utf8) ?? ""
            guard (200...299).contains(httpCode) else {
                return LMStreamResult(httpCode: httpCode, fullText: "", rawLines: [raw], ttfbMs: nil, errorBody: raw)
            }

            let fullText = Self.parseCompleteMessageText(from: data)
            let ttfbMs = Int64((DispatchTime.now().uptimeNanoseconds - startNs) / 1_000_000)
            return LMStreamResult(
                httpCode: httpCode,
                fullText: fullText,
                rawLines: [raw],
                ttfbMs: ttfbMs,
                errorBody: nil
            )
        } catch is CancellationError {
            return LMStreamResult(httpCode: 0, fullText: "", rawLines: [], ttfbMs: nil, errorBody: "cancelled")
        } catch {
            return LMStreamResult(httpCode: 0, fullText: "", rawLines: [], ttfbMs: nil, errorBody: error.localizedDescription)
        }
    }

    /// Extracts assistant content (+ reasoning when present) from a non-stream JSON body.
    private static func parseCompleteMessageText(from data: Data) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any] else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        var full = ""
        if let reasoning = message["reasoning_content"] as? String {
            full += reasoning
        }
        if let content = message["content"] as? String {
            full += content
        } else if let contentParts = message["content"] as? [[String: Any]] {
            for part in contentParts {
                if let text = part["text"] as? String {
                    full += text
                }
            }
        }
        return full
    }
}
