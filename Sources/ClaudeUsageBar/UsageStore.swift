import AppKit
import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var sessionPercent = 0
    @Published private(set) var sessionPercentRemaining = 0
    @Published private(set) var sessionResetText: String?
    @Published private(set) var weeklyPercent = 0
    @Published private(set) var weeklyPercentRemaining = 0
    @Published private(set) var weeklyResetText: String?
    @Published private(set) var accountLabel: String?
    @Published private(set) var metrics: [ClaudeUsageMetric] = []
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastUpdatedText = "Never"
    @Published private(set) var isReloading = false

    let probeDirectoryPath: String

    var menuBarTitle: String {
        "\(sessionPercent) - \(weeklyPercent)"
    }

    private let provider: ClaudeUsageProvider
    private var refreshTask: Task<Void, Never>?

    init(provider: ClaudeUsageProvider) {
        self.provider = provider
        self.probeDirectoryPath = provider.effectiveWorkingDirectoryURL.path

        reload()
        startRefreshTask()
    }

    deinit {
        refreshTask?.cancel()
    }

    func reload() {
        guard !isReloading else {
            return
        }

        isReloading = true

        Task.detached(priority: .userInitiated) { [provider] in
            do {
                let snapshot = try provider.load()
                await MainActor.run {
                    self.sessionPercent = snapshot.sessionPercentUsed
                    self.sessionPercentRemaining = snapshot.sessionPercentRemaining
                    self.sessionResetText = snapshot.sessionResetText
                    self.weeklyPercent = snapshot.weeklyPercentUsed ?? 0
                    self.weeklyPercentRemaining = snapshot.weeklyPercentRemaining ?? 0
                    self.weeklyResetText = snapshot.weeklyResetText
                    self.accountLabel = snapshot.accountLabel
                    self.metrics = snapshot.metrics
                    self.lastUpdatedText = Self.timestampFormatter.string(from: Date())
                    self.lastErrorMessage = nil
                    self.isReloading = false
                }
            } catch {
                await MainActor.run {
                    self.lastErrorMessage = error.localizedDescription
                    self.weeklyPercent = 0
                    self.weeklyPercentRemaining = 0
                    self.weeklyResetText = nil
                    self.accountLabel = nil
                    self.metrics = []
                    self.lastUpdatedText = Self.timestampFormatter.string(from: Date())
                    self.isReloading = false
                }
            }
        }
    }

    func revealProbeDirectory() {
        NSWorkspace.shared.activateFileViewerSelecting([provider.effectiveWorkingDirectoryURL])
    }

    private func startRefreshTask() {
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))

                guard !Task.isCancelled else {
                    break
                }

                await MainActor.run {
                    self?.reload()
                }
            }
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
