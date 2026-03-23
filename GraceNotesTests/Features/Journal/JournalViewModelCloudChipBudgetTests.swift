import XCTest
import SwiftData
@testable import GraceNotes

/// Cloud chip route: skip `Summarizer` when trimmed text fits `ChipLabelUnitTruncator` budget (GH-69).
@MainActor
final class JournalViewModelCloudChipBudgetTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        UserDefaults.standard.set(false, forKey: SummarizerProvider.useCloudUserDefaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: SummarizerProvider.useCloudUserDefaultsKey)
        super.tearDown()
    }

    func test_addGratitude_cloudChipRouteWithinUnitBudget_skipsSummarizer() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let spy = SpySummarizer()
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(
                fixedSummarizer: spy,
                effectiveUsesCloudForChipsOverride: true
            )
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("0123456789")

        XCTAssertEqual(spy.summarizeCallCount, 0)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "0123456789")
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, "0123456789")
        XCTAssertFalse(viewModel.gratitudes[0].isTruncated)
    }

    func test_addGratitude_cloudChipRouteOverUnitBudget_callsSummarizer() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let spy = SpySummarizer()
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(
                fixedSummarizer: spy,
                effectiveUsesCloudForChipsOverride: true
            )
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("01234567890")

        XCTAssertEqual(spy.summarizeCallCount, 1)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, "01234567890")
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, "01234567890")
    }

    func test_addGratitude_cloudChipRouteExactlyTenHanUnits_skipsSummarizer() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let spy = SpySummarizer()
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(
                fixedSummarizer: spy,
                effectiveUsesCloudForChipsOverride: true
            )
        )
        let tenUnitsHan = "一二三四五"

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude(tenUnitsHan)

        XCTAssertEqual(spy.summarizeCallCount, 0)
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, tenUnitsHan)
        XCTAssertFalse(viewModel.gratitudes[0].isTruncated)
    }

    func test_addGratitude_cloudChipRouteElevenUnits_mixed_callsSummarizer() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let spy = SpySummarizer()
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(
                fixedSummarizer: spy,
                effectiveUsesCloudForChipsOverride: true
            )
        )
        let elevenUnits = "一二三四五A"

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude(elevenUnits)

        XCTAssertEqual(spy.summarizeCallCount, 1)
        XCTAssertEqual(viewModel.gratitudes[0].fullText, elevenUnits)
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, elevenUnits)
    }

    func test_summarizeAndUpdateChip_cloudChipRoute_shortText_skipsSummarizer() async throws {
        let context = try makeInMemoryContext()
        let now = Date(timeIntervalSince1970: 1_742_147_200)
        let spy = SpySummarizer()
        let viewModel = JournalViewModel(
            calendar: calendar,
            nowProvider: { now },
            summarizerProvider: SummarizerProvider(
                fixedSummarizer: spy,
                effectiveUsesCloudForChipsOverride: true
            )
        )

        viewModel.loadEntry(for: now, using: context)
        await viewModel.addGratitude("OK")
        XCTAssertEqual(spy.summarizeCallCount, 0)

        await viewModel.summarizeAndUpdateChip(section: .gratitude, index: 0)

        XCTAssertEqual(spy.summarizeCallCount, 0)
        XCTAssertEqual(viewModel.gratitudes[0].chipLabel, "OK")
        XCTAssertFalse(viewModel.gratitudes[0].isTruncated)
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([JournalEntry.self])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GraceNotesTests-\(UUID().uuidString).store")
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }
}
