import Foundation

/// Shared latency controls for cleanup requests.
///
/// The policy intentionally describes the *job* (rewrite a transcript) instead
/// of pinning behavior to a particular model. Providers use different field
/// names, so adapters translate the same safe output budget at the API edge.
enum EnhancementLatencyPolicy {
    /// Cleanup should be roughly the same length as the dictated text. Giving a
    /// provider an unbounded response reservation adds avoidable queueing on
    /// several cloud backends. The budget remains deliberately generous so it
    /// never truncates normal rewritten paragraphs.
    static func maximumCompletionTokens(for transcript: String) -> Int {
        let words = transcript.split { $0.isWhitespace || $0.isNewline }.count
        return min(max(words * 3 + 96, 128), 4_096)
    }

    /// Extra body fields for every OpenAI-compatible cleanup backend, including
    /// self-hosted compatible servers. GPT-5/o-series use the modern field;
    /// the rest of the compatible ecosystem uses `max_tokens`.
    static func openAICompatibleBody(
        modelName: String,
        maximumCompletionTokens: Int,
        existing: [String: Any]? = nil
    ) -> [String: Any] {
        var body = existing ?? [:]
        let normalizedModelName = modelName.lowercased()
        let usesModernCompletionLimit =
            normalizedModelName.hasPrefix("gpt-5")
            || normalizedModelName.hasPrefix("o1")
            || normalizedModelName.hasPrefix("o3")
            || normalizedModelName.hasPrefix("o4")

        body[usesModernCompletionLimit ? "max_completion_tokens" : "max_tokens"] =
            maximumCompletionTokens
        return body
    }
}
