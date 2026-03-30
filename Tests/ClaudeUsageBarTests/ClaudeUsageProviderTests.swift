import Foundation
import Testing
@testable import ClaudeUsageBar

struct ClaudeUsageProviderTests {
    @Test
    func parsesLeftFormat() throws {
        let provider = ClaudeUsageProvider()

        let snapshot = try provider.parse(
            """
            Current session
            ████████████████░░░░ 65% left
            Resets in 2h 15m

            Current week (all models)
            ██████████░░░░░░░░░░ 35% left
            """
        )

        #expect(snapshot.sessionPercentUsed == 35)
        #expect(snapshot.sessionPercentRemaining == 65)
        #expect(snapshot.sessionResetText == "Resets in 2h 15m")
        #expect(snapshot.weeklyPercentUsed == 65)
        #expect(snapshot.weeklyPercentRemaining == 35)
        #expect(snapshot.metrics.count == 2)
        #expect(snapshot.metrics.first?.title == "Current session")
        #expect(snapshot.metrics.first?.percentUsed == 35)
        #expect(snapshot.metrics.last?.title == "Current week")
        #expect(snapshot.metrics.last?.percentUsed == 65)
    }

    @Test
    func parsesUsedFormatAsRemaining() throws {
        let provider = ClaudeUsageProvider()

        let snapshot = try provider.parse(
            """
            Current session
            ████████████████████ 25% used
            """
        )

        #expect(snapshot.sessionPercentUsed == 25)
        #expect(snapshot.sessionPercentRemaining == 75)
    }

    @Test
    func parsesAccountAndModelBreakdown() throws {
        let provider = ClaudeUsageProvider()

        let snapshot = try provider.parse(
            """
            Opus 4.5 · Claude Max · Personal

            Current session
            ████████████████░░░░ 65% left
            Resets in 2h 15m

            Current week (all models)
            ██████████░░░░░░░░░░ 35% left
            Resets Apr 1, 9:00am (Asia/Kuala_Lumpur)

            Current week (Opus)
            ████████████████████ 80% left

            Current week (Sonnet only)
            ████████░░░░░░░░░░░░ 40% left
            """
        )

        #expect(snapshot.accountLabel == "Opus 4.5 · Claude Max · Personal")
        #expect(snapshot.weeklyPercentUsed == 65)
        #expect(snapshot.metrics.count == 4)
        #expect(snapshot.metrics[1].percentUsed == 65)
        #expect(snapshot.metrics[2].title == "Current week (Opus)")
        #expect(snapshot.metrics[2].percentUsed == 20)
        #expect(snapshot.metrics[3].title == "Current week (Sonnet)")
        #expect(snapshot.metrics[3].percentUsed == 60)
    }

    @Test
    func trimsBorderCharactersFromAccountLabel() throws {
        let provider = ClaudeUsageProvider()

        let snapshot = try provider.parse(
            """
            │ Sonnet 4.6 · Claude Pro · azwandi@gmail.com's │

            Current session
            ████████████████████ 100% left
            """
        )

        #expect(snapshot.accountLabel == "Sonnet 4.6 · Claude Pro · azwandi@gmail.com's")
    }

    @Test
    func detectsTrustPrompt() {
        let provider = ClaudeUsageProvider()

        #expect(throws: ClaudeUsageError.self) {
            _ = try provider.parse(
                """
                Accessing workspace:

                /Users/testuser/Library/Application Support/ClaudeUsageBar/Probe

                Quick safety check: Is this a project you created or one you trust?
                ❯ 1. Yes, I trust this folder
                2. No, exit
                """
            )
        }
    }
}
