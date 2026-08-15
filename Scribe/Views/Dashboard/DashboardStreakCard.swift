import SwiftUI

struct DashboardStreakCard: View {
    let days: [DashboardActivityDay]

    private var currentStreak: Int {
        var streak = 0
        for day in days.reversed() {
            guard day.isActive else { break }
            streak += 1
        }
        return streak
    }

    private var longestStreak: Int {
        var longest = 0
        var current = 0
        for day in days {
            if day.isActive {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text(currentStreak == 1 ? "1 day streak" : "\(currentStreak) day streak")
                    .font(InsightsTypography.cardTitle)
                    .foregroundStyle(AppTheme.Text.primary)

                Spacer()

                Text("LONGEST STREAK  |  \(longestStreak) DAYS")
                    .font(InsightsTypography.metricLabel)
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.Text.secondary)
            }

            LazyHGrid(
                rows: Array(repeating: GridItem(.fixed(12), spacing: 6), count: 7),
                spacing: 6
            ) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fillColor(for: day))
                        .frame(width: 12, height: 12)
                        .help(day.date.formatted(.dateTime.month(.abbreviated).day()) + ": " +
                              "\(Formatters.formattedNumber(day.wordCount)) words")
                        .accessibilityLabel(
                            "\(day.date.formatted(.dateTime.month(.wide).day())): \(day.wordCount) words"
                        )
                }
            }

            Text("Last 42 days of Scribe activity")
                .font(InsightsTypography.supportingText)
                .foregroundStyle(AppTheme.Text.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DashboardInsightCardBackground(cornerRadius: 12))
    }

    private func fillColor(for day: DashboardActivityDay) -> Color {
        guard day.isActive else {
            return AppTheme.Surface.controlActive.opacity(0.68)
        }
        return AppTheme.Accent.primary.opacity(day.wordCount > 100 ? 1 : 0.68)
    }
}
