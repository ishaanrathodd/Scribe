import OSLog
import SwiftUI

enum ViewType: String, CaseIterable, Identifiable, Hashable {
    case insights = "Insights"
    case modes = "Modes"
    case models = "AI Models"
    case transcribeAudio = "Transcribe Audio"
    case history = "History"
    case askHistory = "Ask History"
    case audio = "Audio"
    case dictionary = "Dictionary"
    case settings = "Settings"

    var id: String { rawValue }

    var displayTitle: String {
        self == .transcribeAudio ? "Transcribe" : rawValue
    }
}

final class MainWindowNavigation: ObservableObject {
    static let shared = MainWindowNavigation()

    @Published var selectedView: ViewType = .insights

    private init() {}

    func navigate(to destination: String) {
        guard let viewType = ViewType(rawValue: destination) else {
            return
        }

        navigate(to: viewType)
    }

    func navigate(to destination: ViewType) {
        selectedView = destination
    }
}

struct ContentView: View {
    private let logger = Logger(subsystem: "com.prakashjoshipax.scribe", category: "ContentView")
    @EnvironmentObject private var navigation: MainWindowNavigation

    var body: some View {
        NavigationSplitView {
            AppSidebar(selectedView: $navigation.selectedView)
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .navigationTitle(navigation.selectedView.displayTitle)
        .frame(minWidth: AppWindowLayout.width)
        .frame(minHeight: AppWindowLayout.minimumHeight)
        .onAppear {
            logger.notice("ContentView appeared")
        }
        .onDisappear {
            logger.notice("ContentView disappeared")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDestination)) { notification in
            if let destination = notification.userInfo?["destination"] as? String {
                logger.notice("navigateToDestination received: \(destination, privacy: .public)")
                navigation.navigate(to: destination)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        detailView(for: navigation.selectedView)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func detailView(for viewType: ViewType) -> some View {
        switch viewType {
        case .insights:
            DashboardView()
        case .models:
            ModelManagementView()
        case .transcribeAudio:
            AudioTranscribeView()
        case .history:
            InlineHistoryView()
        case .askHistory:
            AskHistoryView()
        case .audio:
            AudioSetupView()
        case .dictionary:
            DictionarySettingsView()
        case .modes:
            ModeView()
        case .settings:
            SettingsView()
        }
    }
}
