import Combine
import Foundation

struct AskConversation: Codable, Identifiable, Equatable {
    struct Message: Codable, Identifiable, Equatable {
        let id: UUID
        let role: AssistantMessageRole
        let content: String
        let createdAt: Date
    }

    let id: UUID
    let title: String
    let createdAt: Date
    let updatedAt: Date
    let providerRawValue: String?
    let modelName: String?
    let modeName: String?
    let modeEmoji: String?
    let promptName: String?
    let systemPrompt: String?
    let isWebSearchEnabled: Bool
    let turnPreprocessing: AssistantTurnPreprocessing?
    let messages: [Message]
}

/// A dedicated, local history store for Ask Mode. It intentionally does not
/// share the transcription database, so AI conversations never appear in the
/// normal transcript history.
@MainActor
final class AskHistoryStore: ObservableObject {
    static let shared = AskHistoryStore()

    @Published private(set) var conversations: [AskConversation] = []

    private let fileURL: URL

    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.prakashjoshipax.Scribe", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("ask-history.json")
        load()
    }

    func save(session: AssistantSession) {
        guard let id = session.conversationID, !session.messages.isEmpty else { return }

        let existing = conversations.first { $0.id == id }
        let firstQuestion = session.messages.first(where: { $0.role == .user })?.content ?? "New Chat"
        let title = Self.title(from: firstQuestion)
        let conversation = AskConversation(
            id: id,
            title: title,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date(),
            providerRawValue: session.provider?.rawValue,
            modelName: session.modelName,
            modeName: session.modeName,
            modeEmoji: session.modeEmoji,
            promptName: session.promptName,
            systemPrompt: session.systemPrompt,
            isWebSearchEnabled: session.isWebSearchEnabled,
            turnPreprocessing: session.turnPreprocessing,
            messages: session.messages.map {
                AskConversation.Message(id: $0.id, role: $0.role, content: $0.content, createdAt: $0.createdAt)
            }
        )

        conversations.removeAll { $0.id == id }
        conversations.insert(conversation, at: 0)
        conversations.sort { $0.updatedAt > $1.updatedAt }
        persist()
    }

    func delete(_ conversation: AskConversation) {
        conversations.removeAll { $0.id == conversation.id }
        persist()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([AskConversation].self, from: data)
        else { return }
        conversations = decoded.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func title(from text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > 72 else { return normalized }
        return String(normalized.prefix(72)) + "…"
    }
}
