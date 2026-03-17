import XCTest
@testable import FiveCubedMoments

final class ReviewInsightsGeneratorTests: XCTestCase {
    private var calendar: Calendar!
    private var generator: DeterministicReviewInsightsGenerator!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        generator = DeterministicReviewInsightsGenerator()
    }

    func test_generateInsights_usesCurrentWeekOnly() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let inWeekEntry = makeEntry(
            on: date(year: 2026, month: 3, day: 17),
            gratitudes: ["Family"]
        )
        let previousWeekEntry = makeEntry(
            on: date(year: 2026, month: 3, day: 8),
            gratitudes: ["Travel"]
        )

        let insights = try await generator.generateInsights(
            from: [inWeekEntry, previousWeekEntry],
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.recurringGratitudes.first?.label, "Family")
        XCTAssertFalse(insights.recurringGratitudes.contains(where: { $0.label == "Travel" }))
    }

    func test_generateInsights_ranksThemesByCountThenAlphabetically() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let first = makeEntry(
            on: date(year: 2026, month: 3, day: 17),
            gratitudes: ["Family", "Coffee"],
            needs: ["Rest"]
        )
        let second = makeEntry(
            on: date(year: 2026, month: 3, day: 18),
            gratitudes: ["Coffee"],
            needs: ["Rest"]
        )
        let third = makeEntry(
            on: date(year: 2026, month: 3, day: 19),
            gratitudes: ["Coffee"],
            needs: ["Clarity"]
        )

        let insights = try await generator.generateInsights(
            from: [first, second, third],
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.recurringGratitudes.prefix(2).map(\.label), ["Coffee", "Family"])
        XCTAssertEqual(insights.recurringGratitudes.first?.count, 3)
        XCTAssertEqual(insights.recurringNeeds.prefix(2).map(\.label), ["Rest", "Clarity"])
    }

    func test_generateInsights_resurfacingPrioritizesRecurringNeed() async throws {
        let reference = date(year: 2026, month: 3, day: 18)
        let first = makeEntry(
            on: date(year: 2026, month: 3, day: 17),
            needs: ["Rest"]
        )
        let second = makeEntry(
            on: date(year: 2026, month: 3, day: 18),
            needs: ["Rest"]
        )

        let insights = try await generator.generateInsights(
            from: [first, second],
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(insights.resurfacingMessage, "You mentioned Rest 2 times this week.")
        XCTAssertTrue(insights.continuityPrompt.contains("Rest"))
    }

    func test_generateInsights_withoutEntries_returnsStarterGuidance() async throws {
        let reference = date(year: 2026, month: 3, day: 18)

        let insights = try await generator.generateInsights(
            from: [],
            referenceDate: reference,
            calendar: calendar
        )

        XCTAssertEqual(
            insights.resurfacingMessage,
            "Start with one reflection today to build your weekly review."
        )
        XCTAssertEqual(insights.continuityPrompt, "What feels most important to carry into next week?")
        XCTAssertNil(insights.narrativeSummary)
    }

    private func makeEntry(
        on date: Date,
        gratitudes: [String] = [],
        needs: [String] = [],
        people: [String] = []
    ) -> JournalEntry {
        JournalEntry(
            entryDate: date,
            gratitudes: gratitudes.map { JournalItem(fullText: $0, chipLabel: $0) },
            needs: needs.map { JournalItem(fullText: $0, chipLabel: $0) },
            people: people.map { JournalItem(fullText: $0, chipLabel: $0) }
        )
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}
