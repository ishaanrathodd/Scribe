import Foundation
import LLMkit

/// Server-Sent Events client for OpenAI-compatible chat-completions APIs.
/// It exposes generated text as it arrives instead of waiting for the complete body.
@MainActor
enum OpenAIStreamingClient {
    static func chatCompletion(
        baseURL: URL,
        apiKey: String,
        model: String,
        messages: [ChatMessage],
        systemPrompt: String? = nil,
        temperature: Double = 0.3,
        reasoningEffort: String? = nil,
        extraBody: [String: Any]? = nil,
        timeout: TimeInterval = 30,
        onDelta: @escaping (String) -> Void
    ) async throws -> String {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAPIKey.isEmpty else {
            throw EnhancementError.notConfigured
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(trimmedAPIKey)", forHTTPHeaderField: "Authorization")

        var allMessages = messages
        if let systemPrompt, !systemPrompt.isEmpty {
            allMessages.insert(.system(systemPrompt), at: 0)
        }

        var body: [String: Any] = [
            "model": model,
            "messages": allMessages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "stream": true,
        ]
        if let reasoningEffort {
            body["reasoning_effort"] = reasoningEffort
        }
        if let extraBody {
            for (key, value) in extraBody {
                body[key] = value
            }
        }

        guard JSONSerialization.isValidJSONObject(body) else {
            throw EnhancementError.customError("Could not encode the streaming enhancement request.")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnhancementError.networkError
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            var errorBody = Data()
            for try await byte in bytes {
                errorBody.append(byte)
            }
            let message = String(data: errorBody, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw EnhancementError.customError("HTTP \(httpResponse.statusCode): \(message)")
        }

        var output = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }

            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8) else { continue }

            if let delta = try? JSONDecoder().decode(StreamEvent.self, from: data),
                let content = delta.choices.first?.delta.content,
                !content.isEmpty
            {
                output.append(contentsOf: content)
                onDelta(content)
            } else if let error = try? JSONDecoder().decode(StreamError.self, from: data) {
                throw EnhancementError.customError(error.error.message)
            }
        }

        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EnhancementError.enhancementFailed
        }
        return output
    }
}

private struct StreamEvent: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
        }

        let delta: Delta
    }

    let choices: [Choice]
}

private struct StreamError: Decodable {
    struct Payload: Decodable {
        let message: String
    }

    let error: Payload
}
