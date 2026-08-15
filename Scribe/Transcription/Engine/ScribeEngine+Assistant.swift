import Foundation

@MainActor
extension ScribeEngine {
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
        var textForAssistant = trimmed

        if let preprocessing = assistantSession.turnPreprocessing,
            let enhancementService
        {
            let cleanupConfiguration = preprocessing.runtimeConfiguration(
                provider: provider,
                modelName: modelName
            )
            if enhancementService.isConfigured(for: cleanupConfiguration) {
                do {
                    let cleanupResult = try await enhancementService.enhance(
                        trimmed,
                        configuration: cleanupConfiguration,
                        contextSnapshot: activeRecordingContextStore?.snapshot,
                        onPartial: nil
                    )
                    if !cleanupResult.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
                        textForAssistant = cleanupResult.text
                    }
                } catch {
                    logger.warning("Ask Mode follow-up preprocessing failed; sending the original text: \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        let userMessage = assistantSession.beginFollowUp(textForAssistant)
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
