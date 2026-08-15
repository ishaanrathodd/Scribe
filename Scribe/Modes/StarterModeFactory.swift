import AppKit
import Foundation

enum StarterModeFactory {
    static let defaultTranscriptionModelName = "parakeet-unified-0.6b"

    /// Ask Mode starts with the fast Gemini Flash Lite model whenever the
    /// selected provider exposes it. The local starter modes intentionally do
    /// not use this selection: they run through Sotto Cleanup on-device.
    static func preferredCloudModel(
        for provider: AIProvider,
        fallback: String? = nil
    ) -> String {
        if provider == .openRouter {
            return "google/gemini-3.5-flash-lite"
        }

        if let flashLite = provider.availableModels.first(where: {
            $0.localizedCaseInsensitiveContains("gemini-3.5-flash-lite")
        }) {
            return flashLite
        }

        if let fallback, !fallback.isEmpty {
            return fallback
        }

        return provider.defaultModel
    }

    static func install(
        kinds: [StarterModeKind],
        provider: AIProvider,
        modelName: String?,
        transcriptionModelName: String = defaultTranscriptionModelName,
        isRealtimeTranscriptionEnabled: Bool = false,
        selectedLanguage: String = "auto",
        installedApps: [InstalledAppInfo]? = nil
    ) {
        let manager = ModeManager.shared
        let requestedKinds = Set(kinds)
        let availableInstalledApps =
            requestedKinds.contains(.email)
            ? (installedApps ?? InstalledApps.load())
            : []

        let starterConfigs = StarterModeCatalog.templates
            .filter { requestedKinds.contains($0.kind) }
            .map {
                makeConfig(
                    from: $0,
                    provider: provider,
                    modelName: modelName,
                    transcriptionModelName: transcriptionModelName,
                    isRealtimeTranscriptionEnabled: isRealtimeTranscriptionEnabled,
                    selectedLanguage: selectedLanguage,
                    installedApps: availableInstalledApps
                )
            }

        let nonStarterConfigs = manager.configurations
            .filter { !StarterModeCatalog.ids.contains($0.id) }
            .map { config -> ModeConfig in
                var config = config
                if starterConfigs.contains(where: \.isDefault) {
                    config.isDefault = false
                }
                return config
            }

        manager.replaceConfigurations(starterConfigs + nonStarterConfigs)

        for config in starterConfigs where config.isDefault {
            ShortcutStore.removeShortcutStorage(for: .mode(config.id))
        }

        if let defaultConfig = starterConfigs.first(where: \.isDefault) {
            manager.setActiveConfiguration(defaultConfig)
        }
    }

    static func isInstalled(kind: StarterModeKind) -> Bool {
        guard let template = StarterModeCatalog.templates.first(where: { $0.kind == kind }) else {
            return false
        }

        return ModeManager.shared.configurations.contains { $0.id == template.id }
    }

    private static func makeConfig(
        from template: StarterModeTemplate,
        provider: AIProvider,
        modelName: String?,
        transcriptionModelName: String,
        isRealtimeTranscriptionEnabled: Bool,
        selectedLanguage: String,
        installedApps: [InstalledAppInfo]
    ) -> ModeConfig {
        let isAssistant = template.kind == .assistant
        let aiProvider: AIProvider?
        let aiModel: String?

        if isAssistant {
            // Ask Mode is deliberately cloud-only. Do not silently fall back
            // to the local cleanup engine when a cloud API key is unavailable.
            let hasCloudKey = provider.requiresAPIKey
                && APIKeyManager.shared.hasAPIKey(forProvider: provider.rawValue)
            aiProvider = hasCloudKey ? provider : nil
            aiModel = hasCloudKey
                ? Self.preferredCloudModel(for: provider, fallback: modelName)
                : nil
        } else if template.usesAIEnhancement {
            // Enhancement, Email, and any other paste-oriented starter modes
            // use the on-device cleanup model by default.
            aiProvider = .scribeRefine
            aiModel = AIProvider.scribeRefine.defaultModel
        } else {
            aiProvider = nil
            aiModel = nil
        }

        return ModeConfig(
            id: template.id,
            name: template.name,
            icon: template.icon,
            appConfigs: nil,
            urlConfigs: nil,
            triggerGroups: triggerGroups(for: template.kind, installedApps: installedApps),
            isAIEnhancementEnabled: template.usesAIEnhancement,
            selectedPrompt: template.promptId?.uuidString,
            selectedTranscriptionModelName: transcriptionModelName,
            isRealtimeTranscriptionEnabled: isRealtimeTranscriptionEnabled,
            selectedLanguage: selectedLanguage,
            useClipboardContext: template.kind == .email,
            useSelectedTextContext: template.useSelectedTextContext,
            useScreenCapture: template.useScreenCapture,
            isTextFormattingEnabled: true,
            selectedAIProvider: aiProvider?.rawValue,
            selectedAIModel: aiModel,
            outputMode: template.outputMode,
            autoSendKey: .none,
            isEnabled: true,
            isDefault: template.isDefault
        )
    }

    private static func triggerGroups(
        for kind: StarterModeKind,
        installedApps: [InstalledAppInfo]
    ) -> [ModeTriggerGroup]? {
        guard kind == .email,
            let emailTemplate = TriggerTemplateCatalog.templates.first(where: { $0.id == "email" })
        else {
            return nil
        }

        let group = emailTemplate.availableGroup(
            installedApps: installedApps,
            existingAppBundleIds: [],
            existingWebsites: [],
            cleanURL: ModeManager.shared.cleanURL
        )

        return group.isEmpty ? nil : [group]
    }

}
