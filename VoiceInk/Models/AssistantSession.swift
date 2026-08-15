import Combine
import Foundation

enum AssistantMessageRole: String, Codable {
    case user
    case assistant
}

struct AssistantDisplayMessage: Identifiable, Equatable {
    let id: UUID
    let role: AssistantMessageRole
    let content: String
    let createdAt: Date
}

enum AssistantPhase: Equatable {
    case inactive
    case responding
    case ready
    case sendingFollowUp
    case failed(String)
}

/// A snapshot of the normal enhancement settings used to prepare Ask Mode
/// turns. Keeping it with the conversation means later follow-ups keep the
/// same cleanup behavior even if the active mode is edited afterwards.
struct AssistantTurnPreprocessing: Codable, Equatable {
    let prompt: CustomPrompt
    let useClipboardContext: Bool
    let useSelectedTextContext: Bool
    let useScreenCaptureContext: Bool

    init?(configuration: EnhancementRuntimeConfiguration) {
        guard let prompt = configuration.prompt else { return nil }
        self.prompt = prompt
        useClipboardContext = configuration.useClipboardContext
        useSelectedTextContext = configuration.useSelectedTextContext
        useScreenCaptureContext = configuration.useScreenCaptureContext
    }

    func runtimeConfiguration(provider: AIProvider, modelName: String?) -> EnhancementRuntimeConfiguration {
        EnhancementRuntimeConfiguration(
            mode: nil,
            isEnabled: true,
            prompt: prompt,
            provider: provider,
            modelName: modelName,
            isWebSearchEnabled: false,
            useClipboardContext: useClipboardContext,
            useSelectedTextContext: useSelectedTextContext,
            useScreenCaptureContext: useScreenCaptureContext
        )
    }
}

@MainActor
final class AssistantSession: ObservableObject {
    @Published private(set) var phase: AssistantPhase = .inactive
    @Published private(set) var messages: [AssistantDisplayMessage] = []

    private(set) var provider: AIProvider?
    private(set) var modelName: String?
    private(set) var modeName: String?
    private(set) var modeEmoji: String?
    private(set) var promptName: String?
    private(set) var systemPrompt: String?
    private(set) var isWebSearchEnabled = false
    private(set) var turnPreprocessing: AssistantTurnPreprocessing?
    private(set) var conversationID: UUID?

    var isVisible: Bool {
        phase != .inactive
    }

    var isBusy: Bool {
        phase == .responding || phase == .sendingFollowUp
    }

    var canSendFollowUp: Bool {
        provider != nil && !messages.isEmpty && !isBusy
    }

    func beginInitialResponse(
        transcript: String,
        provider: AIProvider?,
        modelName: String?,
        modeName: String?,
        modeEmoji: String?,
        promptName: String?,
        isWebSearchEnabled: Bool,
        turnPreprocessing: AssistantTurnPreprocessing?
    ) {
        conversationID = UUID()
        self.provider = provider
        self.modelName = modelName
        self.modeName = modeName
        self.modeEmoji = modeEmoji
        self.promptName = promptName
        self.isWebSearchEnabled = isWebSearchEnabled
        self.turnPreprocessing = turnPreprocessing
        messages = []

        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTranscript.isEmpty {
            messages.append(
                AssistantDisplayMessage(
                    id: UUID(),
                    role: .user,
                    content: trimmedTranscript,
                    createdAt: Date()
                )
            )
        }

        phase = .responding
    }

    func finishInitialResponse(_ response: String, systemPrompt: String?) {
        self.systemPrompt = systemPrompt

        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedResponse.isEmpty {
            appendOrReplace(
                message: AssistantDisplayMessage(
                    id: UUID(),
                    role: .assistant,
                    content: trimmedResponse,
                    createdAt: Date()
                )
            )
        }
        phase = .ready
    }

    @discardableResult
    func beginFollowUp(_ text: String) -> AssistantDisplayMessage {
        let userMessage = AssistantDisplayMessage(
            id: UUID(),
            role: .user,
            content: text,
            createdAt: Date()
        )
        appendOrReplace(message: userMessage)
        phase = .sendingFollowUp
        return userMessage
    }

    @discardableResult
    func finishFollowUp(_ text: String) -> AssistantDisplayMessage {
        let assistantMessage = AssistantDisplayMessage(
            id: UUID(),
            role: .assistant,
            content: text,
            createdAt: Date()
        )
        appendOrReplace(message: assistantMessage)
        phase = .ready
        return assistantMessage
    }

    func hasMessage(id: UUID) -> Bool {
        messages.contains { $0.id == id }
    }

    func fail(_ message: String) {
        phase = .failed(message)
    }

    func reset() {
        conversationID = nil
        phase = .inactive
        messages = []
        provider = nil
        modelName = nil
        modeName = nil
        modeEmoji = nil
        promptName = nil
        systemPrompt = nil
        isWebSearchEnabled = false
        turnPreprocessing = nil
    }

    func restore(_ conversation: AskConversation) {
        conversationID = conversation.id
        provider = conversation.providerRawValue.flatMap(AIProvider.init(rawValue:))
        modelName = conversation.modelName
        modeName = conversation.modeName
        modeEmoji = conversation.modeEmoji
        promptName = conversation.promptName
        systemPrompt = conversation.systemPrompt
        isWebSearchEnabled = conversation.isWebSearchEnabled
        turnPreprocessing = conversation.turnPreprocessing
        messages = conversation.messages.map {
            AssistantDisplayMessage(id: $0.id, role: $0.role, content: $0.content, createdAt: $0.createdAt)
        }
        phase = messages.isEmpty ? .inactive : .ready
    }

    private func appendOrReplace(message: AssistantDisplayMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        } else {
            messages.append(message)
        }
    }
}
