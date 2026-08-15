import Foundation
import SwiftUI

enum DashboardHeroHeadline {
    case calculatingProgress
    case startRecordingProgress
    case savedTime(String)
}

struct DashboardHeroCard: View {
    private static let headlineFont: Font = .system(size: 31, weight: .medium, design: .serif)
    private static let highlightedHeadlineFont: Font = .system(size: 31, weight: .medium, design: .serif)

    let headline: DashboardHeroHeadline
    let subtext: String

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                heroCopy
            }

            Spacer(minLength: 24)

            Image("scribe-hero-mark")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(Color.white.opacity(0.92))
                .frame(width: 152, height: 152)
                .padding(.trailing, 12)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: 188, alignment: .leading)
        .background(DashboardImpactBackground())
        .clipShape(RoundedRectangle(cornerRadius: DashboardLayout.cardCornerRadius, style: .continuous))
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            headlineText
                .frame(maxWidth: 720, alignment: .leading)

            Text(subtext)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DashboardMomentumBackground.subtext)
                .frame(maxWidth: 620, alignment: .leading)
        }
    }

    private var headlineText: Text {
        Text(styledHeadline)
    }

    private var styledHeadline: AttributedString {
        let highlightedValue: String
        var text: AttributedString

        switch headline {
        case .calculatingProgress:
            highlightedValue = String(localized: "Scribe progress")
            text = AttributedString(localized: "Calculating \(highlightedValue).")
        case .startRecordingProgress:
            highlightedValue = String(localized: "Scribe progress")
            text = AttributedString(localized: "Start recording to build \(highlightedValue).")
        case .savedTime(let value):
            highlightedValue = value
            text = AttributedString(localized: "You have saved \(highlightedValue) with Scribe")
        }

        text.font = Self.headlineFont
        text.foregroundColor = DashboardMomentumBackground.headline

        if let highlightedRange = text.range(of: highlightedValue) {
            text[highlightedRange].font = Self.highlightedHeadlineFont
            text[highlightedRange].foregroundColor = DashboardMomentumBackground.accent
        }

        return text
    }

}

private struct DashboardImpactBackground: View {
    var body: some View {
        ZStack {
            Image("momentum-hero-bg")
                .resizable()
                .scaledToFill()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.60),
                    Color.black.opacity(0.34),
                    Color.black.opacity(0.04)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: DashboardLayout.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DashboardLayout.cardCornerRadius, style: .continuous)
                .stroke(AppTheme.Border.card, lineWidth: 1)
        )
    }
}

private struct DashboardMomentumBackground {
    static let accent = Color.white
    static let headline = Color.white
    static let subtext = Color.white.opacity(0.86)
}
