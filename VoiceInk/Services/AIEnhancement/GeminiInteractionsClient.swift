import Foundation
import LLMkit

/// Minimal native Gemini Interactions client for cleanup requests.
///
/// LLMkit's public Gemini client currently does not expose
/// `generation_config.max_output_tokens`. That is unsafe for transcript
/// cleanup: Gemini may return an otherwise successful response that stops in
/// the middle of a dictated sentence. This adapter keeps the same native
/// Interactions API, while making the output budget explicit.
enum GeminiInteractionsClient {
    private static let stableEndpoint = URL(
        string: "https://generativelanguage.googleapis.com/v1/interactions"
    )!
    private static let previewEndpoint = URL(
        string: "https://generativelanguage.googleapis.com/v1beta/interactions"
    )!

    static func chatCompletion(
        apiKey: String,
        model: String,
        messages: [ChatMessage],
        systemPrompt: String?,
        thinkingLevel: GeminiThinkingLevel?,
        maximumOutputTokens: Int,
        timeout: TimeInterval
    ) async throws -> String {
        let usableMessages = messages.filter {
            !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !usableMessages.isEmpty else { throw Error.emptyInput }

        let input = try usableMessages.map { message -> InputStep in
            let type: String
            switch message.role.lowercased() {
            case "user": type = "user_input"
            case "assistant", "model": type = "model_output"
            default: throw Error.unsupportedRole
            }
            return InputStep(
                type: type,
                content: [.init(type: "text", text: message.content)]
            )
        }

        let endpoint = model.lowercased().contains("-preview") ? previewEndpoint : stableEndpoint
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(
            Request(
                model: model,
                input: input,
                systemInstruction: systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
                store: false,
                generationConfig: .init(
                    maxOutputTokens: maximumOutputTokens,
                    thinkingLevel: thinkingLevel
                )
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown Gemini API error."
            throw Error.http(status: httpResponse.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let text = decoded.steps
            .filter { $0.type == "model_output" }
            .flatMap { $0.content ?? [] }
            .compactMap { $0.type == "text" ? $0.text : nil }
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else { throw Error.noResult }
        return text
    }
}

private extension GeminiInteractionsClient {
    enum Error: LocalizedError {
        case emptyInput
        case unsupportedRole
        case invalidResponse
        case noResult
        case http(status: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .emptyInput: return "Gemini received an empty request."
            case .unsupportedRole: return "Gemini received an unsupported conversation role."
            case .invalidResponse: return "Gemini returned an invalid network response."
            case .noResult: return "Gemini did not return any text."
            case let .http(status, message): return "Gemini HTTP \(status): \(message)"
            }
        }
    }

    struct Request: Encodable {
        let model: String
        let input: [InputStep]
        let systemInstruction: String?
        let store: Bool
        let generationConfig: GenerationConfig

        enum CodingKeys: String, CodingKey {
            case model, input, store
            case systemInstruction = "system_instruction"
            case generationConfig = "generation_config"
        }
    }

    struct InputStep: Encodable {
        let type: String
        let content: [Content]
    }

    struct Content: Codable {
        let type: String
        let text: String?

        init(type: String, text: String) {
            self.type = type
            self.text = text
        }
    }

    struct GenerationConfig: Encodable {
        let maxOutputTokens: Int
        let thinkingLevel: GeminiThinkingLevel?

        enum CodingKeys: String, CodingKey {
            case maxOutputTokens = "max_output_tokens"
            case thinkingLevel = "thinking_level"
        }
    }

    struct Response: Decodable {
        let steps: [ResponseStep]
    }

    struct ResponseStep: Decodable {
        let type: String
        let content: [Content]?
    }
}
