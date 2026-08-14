import SwiftUI

struct VoiceInkButton: View {
    let title: LocalizedStringKey
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isDisabled ? AppTheme.Accent.disabled : AppTheme.Accent.primary)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct ModeEmptyStateView: View {
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Modes")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add customized modes for different contexts")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VoiceInkButton(
                title: "Add New Mode",
                action: action
            )
            .frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ModeConfigurationsGrid: View {
    @ObservedObject var modeManager: ModeManager
    let onEditConfig: (ModeConfig) -> Void
    @EnvironmentObject var enhancementService: AIEnhancementService

    var body: some View {
        ForEach($modeManager.configurations) { $config in
            ConfigurationRow(
                config: $config,
                isEditing: false,
                modeManager: modeManager,
                onEditConfig: onEditConfig
            )
        }
    }
}

struct DefaultModeIndicator: View {
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)

            Text("Default")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.leading, 7)
        .padding(.trailing, 9)
        .frame(height: 24)
        .background {
            Capsule()
                .fill(AppTheme.Surface.card)
        }
        .overlay {
            Capsule()
                .strokeBorder(AppTheme.Border.control, lineWidth: 0.5)
        }
        .contentShape(Capsule())
        .help("Default mode is used when no app or website matches")
    }
}

struct ConfigurationRow: View {
    private struct TranscriptionModelMetadata {
        let label: String
        let isWarning: Bool
    }

    @Binding var config: ModeConfig
    let isEditing: Bool
    let modeManager: ModeManager
    let onEditConfig: (ModeConfig) -> Void
    @EnvironmentObject var enhancementService: AIEnhancementService
    @EnvironmentObject var transcriptionModelManager: TranscriptionModelManager
    @State private var isHovering = false

    private let maxAppIconsToShow = 5

    private var selectedPrompt: CustomPrompt? {
        guard let promptId = config.selectedPrompt,
            let uuid = UUID(uuidString: promptId)
        else { return nil }
        return enhancementService.allPrompts.first { $0.id == uuid }
    }

    private var transcriptionModelMetadata: TranscriptionModelMetadata {
        switch ModeRuntimeResolver.transcriptionModelResolution(
            mode: config,
            transcriptionModelManager: transcriptionModelManager
        ) {
        case .available(_, let model):
            return TranscriptionModelMetadata(
                label: model.displayName,
                isWarning: false
            )
        case .noMode, .noSelection, .modelNotFound, .unavailable:
            return TranscriptionModelMetadata(
                label: String(localized: "Unavailable"),
                isWarning: true
            )
        }
    }

    private var selectedLanguage: String? {
        if let langCode = config.selectedLanguage {
            if langCode == "auto" { return String(localized: "Auto") }
            if langCode == "en" { return String(localized: "English") }

            if let modelName = config.selectedTranscriptionModelName,
                let model = transcriptionModelManager.allAvailableModels.first(where: { $0.name == modelName }),
                let langName = TranscriptionLanguageSupport.languages(
                    for: model, realtimeEnabled: config.isRealtimeTranscriptionEnabled)[langCode]
            {
                return langName
            }
            return langCode.uppercased()
        }
        return "Default"
    }

    private var appCount: Int { return config.allAppConfigs.count }
    private var websiteCount: Int { return config.allURLConfigs.count }

    private var websiteText: String {
        if websiteCount == 0 { return "" }
        return String(localized: "\(websiteCount) Websites")
    }

    private var appText: String {
        if appCount == 0 { return "" }
        return String(localized: "\(appCount) Apps")
    }

    private var extraAppsCount: Int {
        return max(0, appCount - maxAppIconsToShow)
    }

    private var visibleAppConfigs: [AppConfig] {
        return Array(config.allAppConfigs.prefix(maxAppIconsToShow))
    }

    private var editModeButton: some View {
        Button {
            onEditConfig(config)
        } label: {
            Text("Edit")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(AppTheme.Surface.control)
                )
                .overlay(
                    Capsule()
                        .stroke(AppTheme.Border.control, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .help("Edit mode")
        .accessibilityLabel("Edit mode")
    }

    var body: some View {
        HStack(spacing: 12) {
            ModeIconView(icon: config.icon, size: config.icon.kind == .emoji ? 20 : 16)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(config.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if appCount > 0 {
                        Label(appText, systemImage: "app")
                    }
                    if websiteCount > 0 {
                        Label(websiteText, systemImage: "globe")
                    }
                    Label(transcriptionModelMetadata.label, systemImage: "waveform")
                    if let language = selectedLanguage, language != "Default" {
                        Text(language)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 12)

            if config.isDefault {
                HStack(spacing: 4) {
                    Text("Default")
                    Image(systemName: "checkmark.seal")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            } else {
                Toggle(
                    "Enable \(config.name)",
                    isOn: Binding(
                        get: { config.isEnabled },
                        set: { newValue in
                            if newValue {
                                modeManager.enableConfiguration(with: config.id)
                            } else {
                                modeManager.disableConfiguration(with: config.id)
                            }
                        }
                    )
                )
                .labelsHidden()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onEditConfig(config) }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .opacity(config.isEnabled ? 1.0 : 0.70)
    }

}

struct ModeAppIcon: View {
    let bundleId: String

    var body: some View {
        if let icon = TriggerAppIconCache.shared.icon(for: bundleId) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
        }
    }
}

struct AppGridItem: View {
    let app: (url: URL, name: String, bundleId: String, icon: NSImage)
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                    .shadow(color: Color(NSColor.shadowColor).opacity(0.1), radius: 2, x: 0, y: 1)
                Text(app.name)
                    .font(.system(size: 10))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
            }
            .frame(width: 80, height: 80)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppTheme.Accent.fillSubtle : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppTheme.Accent.primary : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
