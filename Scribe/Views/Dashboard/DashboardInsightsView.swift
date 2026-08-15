import SwiftUI

struct DashboardInsightsView: View {
    @Binding var selectedPeriod: DashboardInsightPeriod
    let productivityPoints: [DashboardProductivityPoint]
    let totals: DashboardMetricTotals
    let activityDays: [DashboardActivityDay]
    let peakHoursSummary: DashboardPeakHoursSummary
    let timeSavedSummary: DashboardTimeSavedSummary
    let updatedAtText: String
    let isRefreshingStats: Bool
    let onRefreshStats: () -> Void
    let showsHeader: Bool
    let showsProductivitySummary: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if showsHeader {
                header
            }

            if showsProductivitySummary {
                DashboardProductivitySummaryStrip(
                    totals: totals
                )
            }

            DashboardProductivityCard(
                period: $selectedPeriod,
                points: productivityPoints,
                updatedAtText: updatedAtText,
                isRefreshingStats: isRefreshingStats,
                onRefreshStats: onRefreshStats
            )

            insightSummaryCards

            DashboardStreakCard(days: activityDays)

        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var insightSummaryCards: some View {
        HStack(alignment: .top, spacing: DashboardLayout.columnSpacing) {
            DashboardPeakHoursCard(summary: peakHoursSummary)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            DashboardTimeSavedCard(summary: timeSavedSummary, period: selectedPeriod)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: 196)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Scribe Insights")
                    .font(InsightsTypography.pageTitle)
                    .foregroundStyle(AppTheme.Text.primary)

                Text("A closer look at your Scribe usage.")
                    .font(InsightsTypography.supportingText)
                    .foregroundStyle(AppTheme.Text.secondary)
            }

            Spacer()

            InsightPeriodPicker(
                title: "Insights period",
                selection: $selectedPeriod
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
