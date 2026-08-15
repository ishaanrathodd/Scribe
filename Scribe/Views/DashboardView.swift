import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    private let startsInInsights: Bool

    init(startsInInsights: Bool = false) {
        self.startsInInsights = startsInInsights
    }

    var body: some View {
        DashboardContent(modelContext: modelContext, startsInInsights: startsInInsights)
    }
}
