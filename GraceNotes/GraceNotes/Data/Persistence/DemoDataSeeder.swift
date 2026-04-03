#if USE_DEMO_DATABASE
import Foundation
import SwiftData

@MainActor
enum DemoDataSeeder {
    private static let seedVersion = 4
    private static let seedVersionKey = "demoDataSeedVersion"

    static func seedIfNeeded(context: ModelContext, calendar: Calendar = .current) {
        let seedTrace = PerformanceTrace.begin("DemoDataSeeder.seedIfNeeded")
        guard shouldSeed(context: context, calendar: calendar) else {
            PerformanceTrace.end("DemoDataSeeder.seedIfNeeded.skipped", startedAt: seedTrace)
            return
        }

        let now = Date.now
        let today = calendar.startOfDay(for: now)
        let entries = makeSeedEntries(today: today, now: now, calendar: calendar)

        for payload in entries {
            upsertEntry(payload, context: context, calendar: calendar, now: now)
        }

        do {
            try context.save()
            UserDefaults.standard.set(seedVersion, forKey: seedVersionKey)
            PerformanceTrace.end("DemoDataSeeder.seedIfNeeded", startedAt: seedTrace)
        } catch {
            PerformanceTrace.end("DemoDataSeeder.seedIfNeeded.failed", startedAt: seedTrace)
            assertionFailure("Failed to seed demo database: \(error)")
        }
    }

    private static func shouldSeed(context: ModelContext, calendar: Calendar) -> Bool {
        let savedVersion = UserDefaults.standard.integer(forKey: seedVersionKey)
        if savedVersion != seedVersion { return true }

        let today = calendar.startOfDay(for: .now)
        return fetchEntry(for: today, context: context, calendar: calendar) == nil
    }

    private static func upsertEntry(_ payload: DemoEntryPayload, context: ModelContext, calendar: Calendar, now: Date) {
        if let existing = fetchEntry(for: payload.entryDate, context: context, calendar: calendar) {
            existing.gratitudes = payload.gratitudes
            existing.needs = payload.needs
            existing.people = payload.people
            existing.readingNotes = payload.readingNotes
            existing.reflections = payload.reflections
            existing.updatedAt = now
            existing.completedAt = payload.completedAt
            return
        }

        context.insert(
            Journal(
                entryDate: payload.entryDate,
                gratitudes: payload.gratitudes,
                needs: payload.needs,
                people: payload.people,
                readingNotes: payload.readingNotes,
                reflections: payload.reflections,
                createdAt: now,
                updatedAt: now,
                completedAt: payload.completedAt
            )
        )
    }

    private static func fetchEntry(for date: Date, context: ModelContext, calendar: Calendar) -> Journal? {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
        let descriptor = FetchDescriptor<Journal>(
            predicate: #Predicate { entry in
                entry.entryDate >= date && entry.entryDate < nextDay
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try? context.fetch(descriptor).first
    }

    private static func makeSeedEntries(today: Date, now: Date, calendar: Calendar) -> [DemoEntryPayload] {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today) ?? today
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today) ?? today
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today) ?? today
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today) ?? today
        let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) ?? today

        return [
            makeTodayPayload(entryDate: today, completedAt: now),
            makeYesterdayPayload(entryDate: yesterday),
            makeBlankPayload(entryDate: twoDaysAgo),
            makeThreeDaysAgoPayload(entryDate: threeDaysAgo, completedAt: now),
            makeFourDaysAgoPayload(entryDate: fourDaysAgo),
            makeFiveDaysAgoPayload(entryDate: fiveDaysAgo),
            makeSixDaysAgoPayload(entryDate: sixDaysAgo),
            demoDecember2025Entry(calendar: calendar, now: now)
        ]
    }

    private static func makeTodayPayload(entryDate: Date, completedAt: Date) -> DemoEntryPayload {
        DemoEntryPayload(
            entryDate: entryDate,
            gratitudes: [
                item("感恩 morning coffee 讓我開始美好的一天"),
                item("Thanks to 小明 for helping with the project"),
                item("和 Sarah 的 lunch meeting 很愉快"),
                item("Family dinner with lots of laughter"),
                item("天氣很好，散步很舒服")
            ],
            needs: [
                item("需要 more sleep 和規律作息"),
                item("想 find time for 運動"),
                item("Need clearer priorities at work"),
                item("今天需要安靜專注"),
                item("More water during the day")
            ],
            people: [
                item("和媽媽的 weekly call"),
                item("Coffee with 老闆討論 promotion"),
                item("Pray for my brother's travel"),
                item("Check in with mentor after lunch"),
                item("Send encouragement to team")
            ],
            readingNotes: "John 15 reminded me to remain connected and let daily habits flow from that place.",
            reflections: "Today I feel grounded and hopeful. "
                + "I want to move slowly, stay kind, and finish what matters most.",
            completedAt: completedAt
        )
    }

    private static func makeYesterdayPayload(entryDate: Date) -> DemoEntryPayload {
        DemoEntryPayload(
            entryDate: entryDate,
            gratitudes: [
                item("Grateful for quiet morning time"),
                item("感恩同事主動幫忙"),
                item("Nice walk after dinner")
            ],
            needs: [
                item("Need to rest my eyes"),
                item("想要更好的時間管理"),
                item("Need to follow up on one message")
            ],
            people: [
                item("Pray for my friend interview"),
                item("Call dad tonight"),
                item("Thank my manager for yesterday's feedback")
            ],
            readingNotes: "",
            reflections: "A little tired, but still thankful.",
            completedAt: nil
        )
    }

    private static func makeBlankPayload(entryDate: Date) -> DemoEntryPayload {
        DemoEntryPayload(
            entryDate: entryDate,
            gratitudes: [],
            needs: [],
            people: [],
            readingNotes: "",
            reflections: "",
            completedAt: nil
        )
    }

    private static func makeThreeDaysAgoPayload(entryDate: Date, completedAt: Date) -> DemoEntryPayload {
        DemoEntryPayload(
            entryDate: entryDate,
            gratitudes: [
                item("感謝朋友幫忙搬家"),
                item("感謝今天的陽光"),
                item("感謝午餐很美味"),
                item("感謝有時間禱告"),
                item("感謝身體恢復中")
            ],
            needs: [
                item("想找時間運動"),
                item("需要多休息"),
                item("需要整理房間"),
                item("想減少滑手機"),
                item("需要補充水分")
            ],
            people: [
                item("感謝媽媽的提醒"),
                item("想關心同事近況"),
                item("為教會小組代禱"),
                item("感謝鄰居借工具"),
                item("想約朋友散步")
            ],
            readingNotes: "詩篇提醒我在忙碌裡仍然可以安靜等候。",
            reflections: "今天節奏很滿，但仍有很多值得感恩的片刻。",
            completedAt: completedAt
        )
    }

    private static func makeFourDaysAgoPayload(entryDate: Date) -> DemoEntryPayload {
        DemoEntryPayload(
            entryDate: entryDate,
            gratitudes: [
                item("Grateful for morning prayer"),
                item("Thankful for smooth commute"),
                item("感恩 coffee break"),
                item("Great feedback from teammate"),
                item("Lunch outside in good weather")
            ],
            needs: [
                item("Need one focused work block"),
                item("需要 more patience"),
                item("Need to prep tomorrow plan"),
                item("Need to drink more water"),
                item("Want one quiet evening")
            ],
            people: [
                item("Check on grandma"),
                item("Message project partner"),
                item("Pray for pastor"),
                item("Call mom after dinner"),
                item("Send notes to mentor")
            ],
            readingNotes: "",
            reflections: "",
            completedAt: nil
        )
    }

    /// A text-only day still counts as writing in Review without filling any chip sections.
    private static func makeFiveDaysAgoPayload(entryDate: Date) -> DemoEntryPayload {
        DemoEntryPayload(
            entryDate: entryDate,
            gratitudes: [],
            needs: [],
            people: [],
            readingNotes: "Psalm 23 stayed with me during a busier day than expected.",
            reflections: "I did not fill the prompts, but I still wanted to remember this feeling before sleep.",
            completedAt: nil
        )
    }

    private static func makeSixDaysAgoPayload(entryDate: Date) -> DemoEntryPayload {
        DemoEntryPayload(
            entryDate: entryDate,
            gratitudes: [
                item("Morning prayer before work")
            ],
            needs: [
                item("需要多休息")
            ],
            people: [
                item("Thinking of mom")
            ],
            readingNotes: "",
            reflections: "",
            completedAt: nil
        )
    }

    private static func item(_ fullText: String) -> Entry {
        Entry(fullText: fullText)
    }
}

/// Anchored historical row so Demo builds can sanity-check Past/review behavior across calendar years.
private func demoDecember2025Entry(calendar: Calendar, now: Date) -> DemoEntryPayload {
    var parts = DateComponents()
    parts.year = 2025
    parts.month = 12
    parts.day = 10
    parts.hour = 9
    parts.minute = 30
    let entryDate = calendar.date(from: parts) ?? calendar.startOfDay(for: now)
    return DemoEntryPayload(
        entryDate: entryDate,
        gratitudes: [
            demoLine("Grateful for closing out 2025 with calm routines"),
            demoLine("Thankful for friends who checked in"),
            demoLine("Quiet evening to reflect")
        ],
        needs: [
            demoLine("Need margin before the new year"),
            demoLine("Want to plan January lightly")
        ],
        people: [
            demoLine("Thinking of family gathering plans"),
            demoLine("Grateful for community support")
        ],
        readingNotes: "Demo note dated in 2025 for Past-tab and rhythm checks.",
        reflections: "This entry is intentionally in December 2025 to verify history outside the current week.",
        completedAt: nil
    )
}

private func demoLine(_ fullText: String) -> Entry {
    Entry(fullText: fullText)
}

private struct DemoEntryPayload {
    let entryDate: Date
    let gratitudes: [Entry]
    let needs: [Entry]
    let people: [Entry]
    let readingNotes: String
    let reflections: String
    let completedAt: Date?
}
#endif
