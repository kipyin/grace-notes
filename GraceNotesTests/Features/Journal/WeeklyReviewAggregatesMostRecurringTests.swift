import XCTest
@testable import GraceNotes

final class WeeklyReviewAggregatesMostRecurringTests: XCTestCase {
    private var calendar: Calendar!
    private var builder: WeeklyReviewAggregatesBuilder!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1 // Sunday
        builder = WeeklyReviewAggregatesBuilder()
    }
}

extension WeeklyReviewAggregatesMostRecurringTests {
    func test_buildThemeSections_usesSimplifiedChineseLabelsWhenResolverSelectsChineseLocale() throws {
        builder.themeJournalLanguageResolver = FixedReviewJournalThemeLanguageResolver(
            locale: Locale(identifier: "zh-Hans")
        )
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 16), needs: ["Rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), needs: ["recover"]),
            makeEntry(on: date(year: 2026, month: 3, day: 18), needs: ["休息"])
        ]
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        let restTheme = try XCTUnwrap(aggregates.stats.mostRecurringThemes.first(where: { $0.label == "休息" }))
        XCTAssertEqual(restTheme.totalCount, 3)
    }

    func test_buildThemeSections_mixedJournalCorpusStillUsesEnglishLabelsWhenResolverSelectsEnglish() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 16), needs: ["Rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), needs: ["recover"]),
            makeEntry(on: date(year: 2026, month: 3, day: 18), needs: ["休息"])
        ]
        builder.themeJournalLanguageResolver = FixedReviewJournalThemeLanguageResolver(locale: Locale(identifier: "en"))
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        let restTheme = try XCTUnwrap(aggregates.stats.mostRecurringThemes.first(where: { $0.label == "Rest" }))
        XCTAssertEqual(restTheme.totalCount, 3)
    }

    func test_buildThemeSections_mostRecurringUsesCustomFourWeekWindowAndMinimumSignals() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let insideWindow = [
            makeEntry(on: date(year: 2026, month: 3, day: 3), needs: ["quiet morning"]),
            makeEntry(on: date(year: 2026, month: 3, day: 10), needs: ["quiet morning"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), needs: ["quiet morning"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), needs: ["therapy"])
        ]
        let outsideWindow = [
            makeEntry(on: date(year: 2026, month: 2, day: 1), needs: ["quiet morning"])
        ]

        let fourWeeksStats = PastStatisticsIntervalSelection(mode: .custom, quantity: 4, unit: .week)
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: insideWindow.filter { period.contains($0.entryDate) },
            previousWeekEntries: insideWindow.filter { previous.contains($0.entryDate) },
            allEntries: outsideWindow + insideWindow,
            calendar: calendar,
            referenceDate: referenceDate,
            pastStatisticsInterval: fourWeeksStats
        )

        let recurring = aggregates.stats.mostRecurringThemes
        let quiet = try XCTUnwrap(recurring.first(where: { $0.label == "Quiet time" }))
        XCTAssertEqual(quiet.totalCount, 3, "Most recurring totals use the custom four-week Past statistics window.")
        XCTAssertFalse(recurring.contains(where: { $0.label == "Therapy" }))
    }

    func test_buildThemeSections_appliesGlobalAliasesAndCrossLanguageMerges() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 16), needs: ["Rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), needs: ["recover"]),
            makeEntry(on: date(year: 2026, month: 3, day: 18), needs: ["休息"])
        ]
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        let restTheme = try XCTUnwrap(aggregates.stats.mostRecurringThemes.first(where: { $0.label == "Rest" }))
        XCTAssertEqual(restTheme.totalCount, 3)
    }

    /// Single-word chip gratitudes use phrase-token mining when NL tagging misses; they must still pass
    /// recurring floors (UI test wide-review seed relies on lines like `rest`).
    func test_buildThemeSections_shortGratitudeChipTextContributesToMostRecurring() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 16), gratitudes: ["rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), gratitudes: ["rest"])
        ]
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        let restTheme = try XCTUnwrap(
            aggregates.stats.mostRecurringThemes.first(where: { $0.label == "Rest" })
        )
        XCTAssertGreaterThanOrEqual(restTheme.totalCount, 2)
    }

    func test_buildThemeSections_peopleRemainLiteralWithLightNormalization() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 16), people: ["MIA"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), people: ["mia"]),
            makeEntry(on: date(year: 2026, month: 3, day: 18), people: [" Mia "])
        ]
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        let literal = try XCTUnwrap(aggregates.stats.mostRecurringThemes.first(where: { $0.label == "Mia" }))
        XCTAssertEqual(literal.totalCount, 3)
    }

    func test_buildThemeSections_trendingIncludesNewUpAndDownWithPriorVsCurrentCounts() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            // up: current 2, previous 1
            makeEntry(on: date(year: 2026, month: 3, day: 9), needs: ["rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 16), needs: ["rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), needs: ["rest"]),

            // down: current 1, previous 3 (balanced floor: previous >= 3)
            makeEntry(on: date(year: 2026, month: 3, day: 9), gratitudes: ["walking"]),
            makeEntry(on: date(year: 2026, month: 3, day: 10), gratitudes: ["walking"]),
            makeEntry(on: date(year: 2026, month: 3, day: 12), gratitudes: ["walking"]),
            makeEntry(on: date(year: 2026, month: 3, day: 16), gratitudes: ["walking"]),

            // new: current 2, previous 0 (floor: current >= 2)
            makeEntry(on: date(year: 2026, month: 3, day: 16), gratitudes: ["therapy"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), gratitudes: ["therapy"]),

            // stable: should not surface in trending
            makeEntry(on: date(year: 2026, month: 3, day: 9), needs: ["focus"]),
            makeEntry(on: date(year: 2026, month: 3, day: 16), needs: ["focus"])
        ]

        let stats = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        ).stats
        let trending = stats.movementThemes
        let buckets = stats.trendingBuckets

        let rest = try XCTUnwrap(trending.first(where: { $0.label == "Rest" }))
        XCTAssertEqual(rest.trend, .rising)
        XCTAssertEqual(rest.previousWeekCount, 1)
        XCTAssertEqual(rest.currentWeekCount, 2)

        let walking = try XCTUnwrap(trending.first(where: { $0.label == "Walking" }))
        XCTAssertEqual(walking.trend, .down)
        XCTAssertEqual(walking.previousWeekCount, 3)
        XCTAssertEqual(walking.currentWeekCount, 1)

        let therapy = try XCTUnwrap(trending.first(where: { $0.label == "Therapy" }))
        XCTAssertEqual(therapy.trend, .new)
        XCTAssertEqual(therapy.previousWeekCount, 0)
        XCTAssertEqual(therapy.currentWeekCount, 2)

        XCTAssertNil(trending.first(where: { $0.label == "Focus" }))

        XCTAssertEqual(buckets.newThemes.map(\.label), ["Therapy"])
        XCTAssertEqual(buckets.upThemes.map(\.label), ["Rest"])
        XCTAssertEqual(buckets.downThemes.map(\.label), ["Walking"])
        XCTAssertEqual(trending, buckets.flattened)
    }

    func test_trendingUsesCalendarCurrentWeekVersusPriorWeek() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        // Sun-start week for Mar 18 is Mar 15 … Mar 21; theme must fall in that interval to count as "new" this week.
        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 16), needs: ["therapy"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), needs: ["therapy"])
        ]

        let stats = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        ).stats

        let therapy = try XCTUnwrap(stats.trendingBuckets.newThemes.first(where: { $0.label == "Therapy" }))
        XCTAssertEqual(therapy.trend, .new)
        XCTAssertEqual(therapy.previousWeekCount, 0)
        XCTAssertEqual(therapy.currentWeekCount, 2)
        XCTAssertEqual(stats.trendingBuckets.newThemes.map(\.label), ["Therapy"])
        XCTAssertTrue(stats.trendingBuckets.upThemes.isEmpty)
        XCTAssertTrue(stats.trendingBuckets.downThemes.isEmpty)
    }

    func test_buildThemeSections_countsEachStructuredSurfaceOnceEqualWeight() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(
                on: date(year: 2026, month: 3, day: 17),
                gratitudes: ["rest"],
                needs: ["recover"]
            )
        ]
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        )
        let rest = try XCTUnwrap(aggregates.stats.mostRecurringThemes.first(where: { $0.label == "Rest" }))
        XCTAssertEqual(
            rest.totalCount,
            2,
            "Gratitudes and needs are separate surfaces; each counts once when they match."
        )
    }

    /// When two themes first appear on the same structured surface in one pass and later tie on recurring
    /// counts and day counts, ordering must follow per-theme debut order (`firstSeenOrder`), not arbitrary
    /// `Dictionary` key order.
    func test_buildThemeSections_mostRecurringTieBreakUsesSameSurfaceDebutOrder() throws {
        let surfacePhrase = "walking and rest"
        let normalizer = WeeklyInsightTextNormalizer()
        let distilled = normalizer.distillConcepts(
            from: surfacePhrase,
            source: .gratitudes,
            maximumCount: 3,
            highConfidenceOnly: false,
            journalThemeDisplayLocale: Locale(identifier: "en")
        )
        let restIndex = distilled.firstIndex { $0.canonicalConcept == "rest" }
        let walkingIndex = distilled.firstIndex { $0.canonicalConcept == "walking" }
        guard let restIndex, let walkingIndex else {
            XCTFail(
                "Test setup requires distillConcepts to surface both rest and walking from \"\(surfacePhrase)\"."
            )
            return
        }
        let walkingShouldRankAboveRest = walkingIndex < restIndex

        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 16), gratitudes: [surfacePhrase]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), gratitudes: [surfacePhrase])
        ]
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        )

        let recurring = aggregates.stats.mostRecurringThemes
        let walking = try XCTUnwrap(recurring.first(where: { $0.label == "Walking" }))
        let rest = try XCTUnwrap(recurring.first(where: { $0.label == "Rest" }))
        XCTAssertEqual(walking.totalCount, rest.totalCount)
        XCTAssertEqual(walking.dayCount, rest.dayCount)

        let walkingRank = try XCTUnwrap(recurring.firstIndex(where: { $0.label == "Walking" }))
        let restRank = try XCTUnwrap(recurring.firstIndex(where: { $0.label == "Rest" }))
        if walkingShouldRankAboveRest {
            XCTAssertLessThan(walkingRank, restRank)
        } else {
            XCTAssertLessThan(restRank, walkingRank)
        }
    }

    func test_buildThemeSections_hardBannedConceptsNeverSurface() {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 16), needs: ["reflection"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), gratitudes: ["journal"]),
            makeEntry(on: date(year: 2026, month: 3, day: 18), needs: ["things"]),
            makeEntry(on: date(year: 2026, month: 3, day: 16), needs: ["rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), needs: ["rest"])
        ]
        let recurring = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        ).stats.mostRecurringThemes

        XCTAssertTrue(recurring.contains(where: { $0.label == "Rest" }))
        let bannedLabels: Set<String> = ["Reflection", "Journal", "Things"]
        XCTAssertTrue(recurring.allSatisfy { !bannedLabels.contains($0.label) })
    }

    func test_buildThemeSections_penalizedGenericWorkOmittedWithoutStrongContext() {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 16), needs: ["work"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), needs: ["work"])
        ]
        let recurring = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        ).stats.mostRecurringThemes

        XCTAssertFalse(recurring.contains(where: { $0.label == "Work" }))
    }
}

extension WeeklyReviewAggregatesMostRecurringTests {
    func test_mostRecurringBrowseWindow_keepsPeopleEvidenceAlignedWithReviewCalendar() throws {
        let referenceDate = date(year: 2026, month: 3, day: 30)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)
        let refDay = calendar.startOfDay(for: referenceDate)

        var entries: [Journal] = []
        for dayOffset in 1...22 {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: refDay)!
            entries.append(makeEntry(on: day, gratitudes: ["rest"], needs: ["focus"], people: ["Dad"]))
        }

        let stats = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        ).stats

        let dad = try XCTUnwrap(stats.mostRecurringThemes.first(where: { $0.label == "Dad" }))
        XCTAssertTrue(dad.evidence.contains { $0.source == .people })

        let viewingRange = PastStatisticsIntervalSelection.default.resolvedHistoryRange(
            referenceDate: referenceDate,
            calendar: calendar,
            allEntries: entries
        )
        let windowedPeople = dad.evidence.filter { evidence in
            evidence.source == .people && viewingRange.contains(calendar.startOfDay(for: evidence.entryDate))
        }
        XCTAssertGreaterThan(
            windowedPeople.count,
            0,
            "Browse window filter should retain People in Mind evidence rows used in the sheet."
        )
    }

    func test_trending_warmUpSuppressesPartialDownUntilDayThree() throws {
        let warmUpReference = date(year: 2026, month: 3, day: 16)
        let afterWarmUpReference = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: warmUpReference, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 9), gratitudes: ["walking"]),
            makeEntry(on: date(year: 2026, month: 3, day: 10), gratitudes: ["walking"]),
            makeEntry(on: date(year: 2026, month: 3, day: 12), gratitudes: ["walking"]),
            makeEntry(on: date(year: 2026, month: 3, day: 16), gratitudes: ["walking"])
        ]

        let warmUpStats = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: warmUpReference
        ).stats
        XCTAssertNil(warmUpStats.movementThemes.first(where: { $0.label == "Walking" }))

        let balancedStats = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: afterWarmUpReference
        ).stats
        let walking = try XCTUnwrap(balancedStats.movementThemes.first(where: { $0.label == "Walking" }))
        XCTAssertEqual(walking.trend, .down)
    }

    func test_trending_warmUpAllowsRisingWhenFloorsMetOnSecondDay() throws {
        let warmUpReference = date(year: 2026, month: 3, day: 16)
        let period = ReviewInsightsPeriod.currentPeriod(containing: warmUpReference, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 9), needs: ["rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 16), needs: ["rest"]),
            makeEntry(on: date(year: 2026, month: 3, day: 17), needs: ["rest"])
        ]

        let stats = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: warmUpReference
        ).stats

        let rest = try XCTUnwrap(stats.movementThemes.first(where: { $0.label == "Rest" }))
        XCTAssertEqual(rest.trend, .rising)
        XCTAssertEqual(rest.previousWeekCount, 1)
        XCTAssertEqual(rest.currentWeekCount, 2)
    }

    func test_trending_warmUpAllowsDownWhenFellToZeroWithStrongPrior() throws {
        let warmUpReference = date(year: 2026, month: 3, day: 15)
        let period = ReviewInsightsPeriod.currentPeriod(containing: warmUpReference, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(on: date(year: 2026, month: 3, day: 9), gratitudes: ["walking"]),
            makeEntry(on: date(year: 2026, month: 3, day: 10), gratitudes: ["walking"]),
            makeEntry(on: date(year: 2026, month: 3, day: 12), gratitudes: ["walking"])
        ]

        let stats = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: warmUpReference
        ).stats

        let walking = try XCTUnwrap(stats.movementThemes.first(where: { $0.label == "Walking" }))
        XCTAssertEqual(walking.trend, .down)
        XCTAssertEqual(walking.previousWeekCount, 3)
        XCTAssertEqual(walking.currentWeekCount, 0)
    }

    func test_buildThemeSections_supportingEvidenceIncludesReadingAndReflectionsWithoutChangingCount() throws {
        let referenceDate = date(year: 2026, month: 3, day: 18)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previous = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)

        let entries = [
            makeEntry(
                on: date(year: 2026, month: 3, day: 16),
                needs: ["rest"],
                readingNotes: "I am practicing deeper rest this week."
            ),
            makeEntry(
                on: date(year: 2026, month: 3, day: 17),
                needs: ["rest"],
                reflections: "Rest helped me recover today."
            ),
            makeEntry(
                on: date(year: 2026, month: 3, day: 18),
                readingNotes: "Movement matters.",
                reflections: "Only long-form notes, no structured line."
            )
        ]

        let recurring = builder.build(
            currentPeriod: period,
            currentWeekEntries: entries.filter { period.contains($0.entryDate) },
            previousWeekEntries: entries.filter { previous.contains($0.entryDate) },
            allEntries: entries,
            calendar: calendar,
            referenceDate: referenceDate
        ).stats.mostRecurringThemes

        let rest = try XCTUnwrap(recurring.first(where: { $0.label == "Rest" }))
        XCTAssertEqual(rest.totalCount, 2, "Reading/reflection evidence should not inflate count totals.")
        XCTAssertTrue(rest.evidence.contains(where: { $0.source == .readingNotes }))
        XCTAssertTrue(rest.evidence.contains(where: { $0.source == .reflections }))
        XCTAssertFalse(recurring.contains(where: { $0.label == "Exercise" || $0.label == "Movement" }))
    }

    /// Mirrors `PersistenceController.seedUITestDataIfNeeded` default seed + Monday reference (issue #140 UI test).
    func test_uitestSeed_onePriorDayEntry_hasNoTrendingMovementThemes() throws {
        let referenceDate = date(year: 2026, month: 3, day: 30)
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let previousPeriod = ReviewInsightsPeriod.previousPeriod(before: period, calendar: calendar)
        let dayStart = calendar.startOfDay(for: referenceDate)
        let previousDay = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: dayStart))
        let entry = makeEntry(
            on: previousDay,
            gratitudes: ["sunlight"],
            needs: ["stretching"],
            people: ["Jordan"]
        )
        let aggregates = builder.build(
            currentPeriod: period,
            currentWeekEntries: [entry].filter { period.contains($0.entryDate) },
            previousWeekEntries: [entry].filter { previousPeriod.contains($0.entryDate) },
            allEntries: [entry],
            calendar: calendar,
            referenceDate: referenceDate
        )
        XCTAssertTrue(
            aggregates.stats.movementThemes.isEmpty,
            "Expected no surfacing trends for seed data; got: \(aggregates.stats.movementThemes.map(\.label))"
        )
    }
}

private struct FixedReviewJournalThemeLanguageResolver: ReviewJournalThemeLanguageResolving {
    let locale: Locale
    func resolvedDisplayLocale(forJournalCorpus: String) -> Locale { locale }
}

private extension WeeklyReviewAggregatesMostRecurringTests {
    func makeEntry(
        on date: Date,
        gratitudes: [String] = [],
        needs: [String] = [],
        people: [String] = [],
        readingNotes: String = "",
        reflections: String = ""
    ) -> Journal {
        Journal(
            entryDate: date,
            gratitudes: gratitudes.map { Entry(fullText: $0) },
            needs: needs.map { Entry(fullText: $0) },
            people: people.map { Entry(fullText: $0) },
            readingNotes: readingNotes,
            reflections: reflections
        )
    }

    func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.timeZone = calendar.timeZone
        return calendar.date(from: components)!
    }
}
