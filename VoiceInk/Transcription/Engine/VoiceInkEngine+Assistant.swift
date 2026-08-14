import Foundation

@MainActor
extension VoiceInkEngine {
    func sendAssistantFollowUp(_ text: String, transcription _: Transcription? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let assistantChat,
            let provider = assistantSession.provider
        else {
            return
        }

        let modelName = assistantSession.modelName
        let systemPrompt = assistantSession.systemPrompt
        let isWebSearchEnabled = assistantSession.isWebSearchEnabled
        let userMessage = assistantSession.beginFollowUp(trimmed)
        AskHistoryStore.shared.save(session: assistantSession)

        do {
            let reply = try await assistantChat.requestAssistantReply(
                provider: provider,
                modelName: modelName,
                systemPrompt: systemPrompt,
                enableWebSearch: isWebSearchEnabled,
                messages: assistantSession.messages
            )

            guard assistantSession.hasMessage(id: userMessage.id),
                assistantSession.provider == provider
            else {
                return
            }

            assistantSession.finishFollowUp(reply.text)
            AskHistoryStore.shared.save(session: assistantSession)
        } catch {
            guard assistantSession.hasMessage(id: userMessage.id),
                assistantSession.provider == provider
            else {
                return
            }
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            assistantSession.fail(errorDescription)
            AskHistoryStore.shared.save(session: assistantSession)
        }
    }

    func completeAssistantResponse(
        _ response: String,
        systemPrompt: String?
    ) async {
        assistantSession.finishInitialResponse(response, systemPrompt: systemPrompt)
        AskHistoryStore.shared.save(session: assistantSession)
    }
}
