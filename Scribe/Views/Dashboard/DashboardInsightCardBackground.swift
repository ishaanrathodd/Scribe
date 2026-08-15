import SwiftUI

struct DashboardInsightCardBackground: View {
    var cornerRadius: CGFloat = DashboardLayout.cardCornerRadius

    var body: some View {
        // Dashboard insight cards use one quiet grouped surface. Gradients and
        // bright outlines made them read as custom panels instead of native
        // macOS cards, while the charts already provide the required emphasis.
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.secondary.opacity(0.075))
    }
}
