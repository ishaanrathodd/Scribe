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
    let actionTitle: LocalizedStringKey
    let actionIcon: String
    let actionHelp: String
    let actionAccessibilityLabel: String
    let onViewInsights: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            heroCopy

            HStack(spacing: 12) {
                Button(action: onViewInsights) {
                    DashboardMomentumActionLabel(
                        title: actionTitle,
                        icon: actionIcon,
                        isPrimary: true
                    )
                }
                .buttonStyle(.plain)
                .help(actionHelp)
                .accessibilityLabel(Text(actionAccessibilityLabel))
            }
            .padding(.top, 8)
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

private struct DashboardMomentumActionLabel: View {
    private static let cornerRadius: CGFloat = 10

    let title: LocalizedStringKey
    let icon: String
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 9) {
            Text(title)
                .lineLimit(2)

            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 20)
        .frame(minHeight: 44)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 5, y: 2)
    }

    private var foregroundColor: Color {
        if isPrimary {
            return DashboardMomentumBackground.actionForeground
        }

        return AppTheme.Text.primary
    }

    private var backgroundColor: Color {
        if isPrimary {
            return DashboardMomentumBackground.actionBackground
        }

        return Color.white.opacity(0.82)
    }

    private var borderColor: Color {
        if isPrimary {
            return Color.clear
        }

        return Color.black.opacity(0.08)
    }

    private var shadowColor: Color {
        isPrimary ? Color.black.opacity(0.20) : Color.black.opacity(0.06)
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
    static let actionBackground = Color(red: 0.92, green: 0.90, blue: 0.84)
    static let actionForeground = Color(red: 0.16, green: 0.16, blue: 0.17)
}
