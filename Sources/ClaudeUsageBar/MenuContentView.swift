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

            if let updateStatusMessage = usageStore.updateStatusMessage {
                Text(updateStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Reload") {
                    if usageStore.refreshState == .enabled {
                        usageStore.reload()
                    } else {
                        usageStore.handleMenuOpened()
                    }
                }
                .disabled(usageStore.isReloading)

                Button("Reveal Probe") {
                    usageStore.revealProbeDirectory()
                }

                Spacer()

                Button(usageStore.isCheckingForUpdates ? "Checking..." : "Check for Updates") {
                    usageStore.checkForUpdates()
                }
                .disabled(usageStore.isCheckingForUpdates)

                if usageStore.refreshState == .enabled {
                    Button("Disable") {
                        usageStore.disable()
                    }
                }

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(14)
        .frame(width: 340)
        .onAppear {
            usageStore.handleMenuOpened()
        }
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

    private func usageTint(for percentUsed: Int) -> Color {
        switch percentUsed {
        case 0..<50:
            return Color(red: 0.16, green: 0.54, blue: 0.34)
        case 50..<80:
            return Color(red: 0.95, green: 0.60, blue: 0.05)
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
