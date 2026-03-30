import Foundation

struct ClaudeUsageMetric: Sendable, Identifiable {
    let id: String
    let title: String
    let percentUsed: Int
    let percentRemaining: Int
    let resetText: String?
}

struct ClaudeUsageSnapshot: Sendable {
    let sessionPercentUsed: Int
    let sessionPercentRemaining: Int
    let sessionResetText: String?
    let weeklyPercentUsed: Int?
    let weeklyPercentRemaining: Int?
    let weeklyResetText: String?
    let accountLabel: String?
    let metrics: [ClaudeUsageMetric]
}

struct ClaudeUsageProvider: Sendable {
    static let environmentExclusions = ["CLAUDE_CODE_OAUTH_TOKEN"]

    let claudeBinary: String
    let timeout: TimeInterval

    init(claudeBinary: String = "claude", timeout: TimeInterval = 20) {
        self.claudeBinary = claudeBinary
        self.timeout = timeout
    }

    var probeDirectoryURL: URL {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory

        let directory = baseURL
            .appendingPathComponent("ClaudeUsageBar", isDirectory: true)
            .appendingPathComponent("Probe", isDirectory: true)

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    var effectiveWorkingDirectoryURL: URL {
        latestClaudeSessionWorkingDirectory() ?? probeDirectoryURL
    }

    func load() throws -> ClaudeUsageSnapshot {
        let runner = InteractiveRunner()
        var wroteTrust = false
        let workingDirectory = effectiveWorkingDirectoryURL

        while true {
            let result = try runner.run(
                binary: claudeBinary,
                input: "",
                options: .init(
                    timeout: timeout,
                    workingDirectory: workingDirectory,
                    arguments: ["/usage", "--allowed-tools", ""],
                    autoResponses: [
                        "Esc to cancel": "\r",
                        "Ready to code here?": "\r",
                        "Press Enter to continue": "\r",
                        "ctrl+t to disable": "\r",
                        "Yes, I trust this folder": "\r",
                    ],
                    environmentExclusions: Self.environmentExclusions
                )
            )

            do {
                return try parse(result.output)
            } catch ClaudeUsageError.folderTrustRequired {
                guard !wroteTrust, writeClaudeTrust(for: workingDirectory) else {
                    throw ClaudeUsageError.folderTrustRequired
                }
                wroteTrust = true
            }
        }
    }

    func parse(_ text: String) throws -> ClaudeUsageSnapshot {
        let clean = TerminalRenderer(cols: 160, rows: 50).render(text)

        if let error = extractUsageError(from: clean) {
            throw error
        }

        guard let sessionPercentRemaining = extractPercent(labelSubstring: "Current session", text: clean) else {
            throw ClaudeUsageError.parseFailed("Could not find the current session percentage in Claude /usage output.")
        }

        let metrics = [
            makeMetric(id: "session", title: "Current session", labelSubstring: "Current session", text: clean),
            makeMetric(id: "weekly-all", title: "Current week", labelSubstring: "Current week (all models)", text: clean),
            makeMetric(id: "weekly-opus", title: "Current week (Opus)", labelSubstring: "Current week (Opus)", text: clean),
            makeMetric(
                id: "weekly-sonnet",
                title: "Current week (Sonnet)",
                labelSubstring: "Current week (Sonnet only)",
                fallbackLabelSubstring: "Current week (Sonnet)",
                text: clean
            ),
        ].compactMap { $0 }

        return ClaudeUsageSnapshot(
            sessionPercentUsed: max(0, min(100, 100 - sessionPercentRemaining)),
            sessionPercentRemaining: sessionPercentRemaining,
            sessionResetText: cleanResetText(extractReset(labelSubstring: "Current session", text: clean)),
            weeklyPercentUsed: metrics.first(where: { $0.id == "weekly-all" })?.percentUsed,
            weeklyPercentRemaining: metrics.first(where: { $0.id == "weekly-all" })?.percentRemaining,
            weeklyResetText: metrics.first(where: { $0.id == "weekly-all" })?.resetText,
            accountLabel: extractAccountLabel(from: clean),
            metrics: metrics
        )
    }

    private func makeMetric(
        id: String,
        title: String,
        labelSubstring: String,
        fallbackLabelSubstring: String? = nil,
        text: String
    ) -> ClaudeUsageMetric? {
        let percentRemaining = extractPercent(labelSubstring: labelSubstring, text: text)
            ?? fallbackLabelSubstring.flatMap { extractPercent(labelSubstring: $0, text: text) }

        guard let percentRemaining else {
            return nil
        }

        let resetText = cleanResetText(
            extractReset(labelSubstring: labelSubstring, text: text)
                ?? fallbackLabelSubstring.flatMap { extractReset(labelSubstring: $0, text: text) }
        )

        return ClaudeUsageMetric(
            id: id,
            title: title,
            percentUsed: max(0, min(100, 100 - percentRemaining)),
            percentRemaining: percentRemaining,
            resetText: resetText
        )
    }

    private func extractPercent(labelSubstring: String, text: String) -> Int? {
        let lines = text.components(separatedBy: .newlines)
        let label = labelSubstring.lowercased()

        for (index, line) in lines.enumerated() where line.lowercased().contains(label) {
            let window = lines.dropFirst(index).prefix(12)
            for candidate in window {
                if let percent = percentFromLine(candidate) {
                    return percent
                }
            }
        }

        return nil
    }

    private func percentFromLine(_ line: String) -> Int? {
        let pattern = #"([0-9]{1,3})\s*%\s*(used|left)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let valueRange = Range(match.range(at: 1), in: line),
              let kindRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let rawValue = Int(line[valueRange]) ?? 0
        let isUsed = line[kindRange].lowercased().contains("used")
        return isUsed ? max(0, 100 - rawValue) : rawValue
    }

    private func extractReset(labelSubstring: String, text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        let label = labelSubstring.lowercased()

        for (index, line) in lines.enumerated() where line.lowercased().contains(label) {
            let window = lines.dropFirst(index).prefix(14)
            for candidate in window {
                let lower = candidate.lowercased()
                if lower.contains("reset") ||
                    (lower.contains("in") && (lower.contains("h") || lower.contains("m"))) {
                    return deduplicateResetText(candidate.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }

        return nil
    }

    private func deduplicateResetText(_ text: String) -> String {
        var positions: [Range<String.Index>] = []
        var searchStart = text.startIndex

        while let range = text.range(of: "resets", options: .caseInsensitive, range: searchStart..<text.endIndex) {
            positions.append(range)
            searchStart = text.index(after: range.lowerBound)
        }

        if positions.count > 1, let lastRange = positions.last {
            return String(text[lastRange.lowerBound...]).trimmingCharacters(in: .whitespaces)
        }

        return text
    }

    private func cleanResetText(_ text: String?) -> String? {
        guard let text else {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.lowercased().hasPrefix("reset") {
            return trimmed
        }

        return "Resets \(trimmed)"
    }

    private func extractAccountLabel(from text: String) -> String? {
        for line in text.components(separatedBy: .newlines) {
            let cleaned = cleanAccountLabel(line)
            guard cleaned.contains("·") else {
                continue
            }

            let lower = cleaned.lowercased()
            if lower.contains("claude max") || lower.contains("claude pro") || lower.contains("api usage billing") {
                return cleaned
            }
        }

        return nil
    }

    private func cleanAccountLabel(_ line: String) -> String {
        let borderScalars = Set("|¦│┃┆┊╎╏".unicodeScalars)
        let cleanedScalars = line.unicodeScalars.filter { scalar in
            !borderScalars.contains(scalar)
        }

        return String(String.UnicodeScalarView(cleanedScalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractUsageError(from text: String) -> ClaudeUsageError? {
        let lower = text.lowercased()

        if (lower.contains("do you trust the files in this folder?") ||
            lower.contains("is this a project you created or one you trust")),
           !lower.contains("current session") {
            return .folderTrustRequired
        }

        if lower.contains("authentication_error") ||
            lower.contains("token_expired") ||
            lower.contains("token has expired") ||
            lower.contains("not logged in") ||
            lower.contains("please log in") {
            return .authenticationRequired
        }

        if lower.contains("update required") || lower.contains("please update") {
            return .updateRequired
        }

        return nil
    }

    private func writeClaudeTrust(for directory: URL) -> Bool {
        let configDirectory = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]
            .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) }
        let claudeConfigURL = (configDirectory ?? FileManager.default.homeDirectoryForCurrentUser)
            .appendingPathComponent(".claude.json")

        guard FileManager.default.fileExists(atPath: claudeConfigURL.path),
              let data = try? Data(contentsOf: claudeConfigURL),
              var root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return false
        }

        var projects = root["projects"] as? [String: Any] ?? [:]
        var entry = projects[directory.path] as? [String: Any] ?? [:]

        if entry["hasTrustDialogAccepted"] as? Bool == true {
            return false
        }

        entry["hasTrustDialogAccepted"] = true
        projects[directory.path] = entry
        root["projects"] = projects

        guard let updatedData = try? JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        ) else {
            return false
        }

        do {
            try updatedData.write(to: claudeConfigURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    private func latestClaudeSessionWorkingDirectory() -> URL? {
        let sessionsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("sessions", isDirectory: true)

        guard let sessionFiles = try? FileManager.default.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        let decoder = JSONDecoder()

        let latest = sessionFiles
            .filter { $0.pathExtension == "json" }
            .compactMap { fileURL -> ClaudeSessionRecord? in
                guard let data = try? Data(contentsOf: fileURL) else {
                    return nil
                }
                return try? decoder.decode(ClaudeSessionRecord.self, from: data)
            }
            .sorted { $0.startedAt > $1.startedAt }
            .first

        guard let latest else {
            return nil
        }

        let directory = URL(fileURLWithPath: latest.cwd, isDirectory: true)
        return FileManager.default.fileExists(atPath: directory.path) ? directory : nil
    }
}

private struct ClaudeSessionRecord: Decodable {
    let cwd: String
    let startedAt: Int64
}

enum ClaudeUsageError: LocalizedError {
    case folderTrustRequired
    case authenticationRequired
    case updateRequired
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .folderTrustRequired:
            return "Claude needs this probe folder trusted before /usage can run."
        case .authenticationRequired:
            return "Claude CLI is not authenticated. Run `claude login` first."
        case .updateRequired:
            return "Claude CLI needs to be updated before usage can be read."
        case let .parseFailed(message):
            return message
        }
    }
}
