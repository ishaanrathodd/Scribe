import Foundation

enum TranscriptionModelRegistry {

    static var models: [any TranscriptionModel] {
        return predefinedModels + CustomCloudModelManager.shared.customModels
    }

    private static let predefinedModels: [any TranscriptionModel] = {
        let nonCloudModels: [any TranscriptionModel] = [
            // Parakeet Models
            FluidAudioModel(
                name: "parakeet-unified-0.6b",
                displayName: "Parakeet Unified",
                description: "English-only Parakeet model with native realtime transcription support",
                size: "1.2 GB",
                speed: 0.99,
                accuracy: 0.95,
                ramUsage: 1.0,
                supportsStreaming: true,
                supportedLanguages: LanguageDictionary.forProvider(isMultilingual: false, provider: .fluidAudio)
            ),
        ]

        let cloudModels: [any TranscriptionModel] = CloudProviderRegistry.allProviders.flatMap { $0.models }
        return nonCloudModels + cloudModels
    }()
}
