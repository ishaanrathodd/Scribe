import Foundation
import SwiftUI

/// Update delivery is intentionally disabled in this community build.
/// Distributions can supply their own updater and feed without inheriting an upstream release channel.
@MainActor
final class UpdaterViewModel: ObservableObject {
    struct AvailableUpdate: Equatable {
        let versionIdentifier: String
        let displayVersion: String
    }

    @Published var canCheckForUpdates = false
    @Published private(set) var checksForUpdatesWhenDashboardAppears = false
    @Published private(set) var availableUpdate: AvailableUpdate?

    func setChecksForUpdatesWhenDashboardAppears(_ value: Bool) {
        checksForUpdatesWhenDashboardAppears = value
    }

    func checkForUpdatesIfDue() {}

    func checkForUpdates() {}
}

struct CheckForUpdatesView: View {
    @ObservedObject var updaterViewModel: UpdaterViewModel

    var body: some View {
        Button("Check for Updates…", action: updaterViewModel.checkForUpdates)
            .disabled(true)
    }
}
