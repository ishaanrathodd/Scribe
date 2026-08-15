import SwiftUI

/// Unmodified system sidebar control.
struct AppSidebar: View {
    @Binding var selectedView: ViewType

    var body: some View {
        List(selection: $selectedView) {
            ForEach(ViewType.primaryItems) { item in
                Label(item.displayTitle, systemImage: item.icon)
                    .tag(item)
            }

            ForEach(ViewType.secondaryItems) { item in
                Label(item.displayTitle, systemImage: item.icon)
                    .tag(item)
            }
        }
        .listStyle(.sidebar)
    }
}

private extension ViewType {
    static let primaryItems: [ViewType] = [
        .insights, .modes, .transcribeAudio, .history, .askHistory, .dictionary, .models, .audio,
    ]

    static let secondaryItems: [ViewType] = [.settings]

    var icon: String {
        switch self {
        case .insights: return "chart.line.uptrend.xyaxis"
        case .transcribeAudio: return "waveform.path"
        case .history: return "doc.text.fill"
        case .askHistory: return "bubble.left.and.bubble.right.fill"
        case .models: return "cpu"
        case .modes: return "sparkles.square.fill.on.square"
        case .audio: return "mic.fill"
        case .dictionary: return "text.book.closed.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
