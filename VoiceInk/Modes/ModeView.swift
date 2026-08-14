import SwiftData
import SwiftUI

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: () -> Content
    ) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

enum ConfigurationMode: Hashable {
    case add
    case edit(ModeConfig)

    var isAdding: Bool {
        if case .add = self { return true }
        return false
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .add:
            hasher.combine(0)
        case .edit(let config):
            hasher.combine(1)
            hasher.combine(config.id)
        }
    }

    static func == (lhs: ConfigurationMode, rhs: ConfigurationMode) -> Bool {
        switch (lhs, rhs) {
        case (.add, .add):
            return true
        case (.edit(let lhsConfig), .edit(let rhsConfig)):
            return lhsConfig.id == rhsConfig.id
        default:
            return false
        }
    }
}

enum ConfigurationType {
    case application
    case website
}

struct ModeView: View {
    @StateObject private var modeManager = ModeManager.shared
    @StateObject private var modeWarmupStore = ModeFormWarmupStore.shared
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var transcriptionModelManager: TranscriptionModelManager
    @State private var activePanel: PanelType?
    @State private var panelID = UUID()

    private enum PanelType {
        case configuration(ConfigurationMode)
        case settings
    }

    private var isPanelOpen: Bool {
        activePanel != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if modeManager.configurations.isEmpty {
                    ContentUnavailableView(
                        "No Modes",
                        systemImage: "square.grid.2x2",
                        description: Text("Add a mode to control how VoiceInk transcribes and formats your speech.")
                    )
                } else {
                    Form {
                        Section {
                        ModeConfigurationsGrid(
                            modeManager: modeManager,
                            onEditConfig: { config in
                                openPanel(mode: .edit(config))
                            }
                        )
                        }
                    }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sidePanel(
            isPresented: .init(
                get: { isPanelOpen },
                set: { if !$0 { closePanel() } }
            ), dismissOnExitCommand: false
        ) {
            switch activePanel {
            case .configuration(let mode)?:
                ModeConfigEditorView(mode: mode, modeManager: modeManager, onDismiss: closePanel)
                    .environmentObject(modeWarmupStore)
                    .id(panelID)
            case .settings?:
                ModeSettingsPanelView(modeManager: modeManager, onDismiss: closePanel)
            case nil:
                EmptyView()
            }
        }
        .onAppear {
            modeWarmupStore.configure(
                aiService: aiService,
                enhancementService: enhancementService,
                transcriptionModelManager: transcriptionModelManager
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    openPanel(mode: .add)
                } label: {
                    Label("Add Mode", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
                .help("Add Mode")

                Button {
                    openSettingsPanel()
                } label: {
                    Label("Modes Settings", systemImage: "gearshape")
                }
                .labelStyle(.iconOnly)
                .help("Modes Settings")
            }
        }
    }

    private func openPanel(mode: ConfigurationMode) {
        panelID = UUID()
        activePanel = .configuration(mode)
    }

    private func closePanel() {
        activePanel = nil
    }

    private func openSettingsPanel() {
        activePanel = .settings
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }
}
