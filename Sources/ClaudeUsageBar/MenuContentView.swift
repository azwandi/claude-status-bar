import SwiftUI

struct MenuContentView: View {
    @ObservedObject var usageStore: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let accountLabel = usageStore.accountLabel {
                Text(accountLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Claude Session")
                            .font(.headline)
                        Text("Live usage from `/usage`")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(usageStore.menuBarTitle)
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }

                UsageProgressBar(
                    percentUsed: usageStore.sessionPercent,
                    tint: usageTint(for: usageStore.sessionPercent)
                )

                HStack {
                    summaryPill(title: "Session", value: "\(usageStore.sessionPercent)")
                    summaryPill(title: "Week", value: "\(usageStore.weeklyPercent)")
                    summaryPill(title: "Left", value: "\(usageStore.sessionPercentRemaining)")
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            if let resetText = usageStore.sessionResetText {
                HStack {
                    Text("Session reset")
                    Spacer()
                    Text(resetText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            if let weeklyResetText = usageStore.weeklyResetText {
                HStack {
                    Text("Week reset")
                    Spacer()
                    Text(weeklyResetText)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            Divider()

            if !usageStore.metrics.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Usage Breakdown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(usageStore.metrics) { metric in
                        metricCard(metric)
                    }
                }

                Divider()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Claude probe directory")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(usageStore.probeDirectoryPath)
                    .font(.caption)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            HStack {
                Text("Last update")
                Spacer()
                Text(usageStore.lastUpdatedText)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            if let errorMessage = usageStore.lastErrorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            HStack {
                Button("Reload") {
                    usageStore.reload()
                }
                .disabled(usageStore.isReloading)

                Button("Reveal Probe") {
                    usageStore.revealProbeDirectory()
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 340)
    }

    @ViewBuilder
    private func metricCard(_ metric: ClaudeUsageMetric) -> some View {
        let tint = usageTint(for: metric.percentUsed)

        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(metric.title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(metric.percentUsed)% used")
                    .monospacedDigit()
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
            }

            UsageProgressBar(percentUsed: metric.percentUsed, tint: tint)

            HStack {
                Text("\(metric.percentRemaining)% left")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let resetText = metric.resetText {
                    Text(resetText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
        )
    }

    @ViewBuilder
    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
    }

    private func usageTint(for percentUsed: Int) -> Color {
        switch percentUsed {
        case 0..<50:
            return Color(red: 0.16, green: 0.54, blue: 0.34)
        case 50..<80:
            return Color(red: 0.80, green: 0.52, blue: 0.10)
        default:
            return Color(red: 0.78, green: 0.23, blue: 0.18)
        }
    }
}

private struct UsageProgressBar: View {
    let percentUsed: Int
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, min(1, CGFloat(percentUsed) / 100)) * geometry.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.75), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("\(percentUsed)% used")
    }
}
