#if USE_DEMO_DATABASE
import Foundation
import SwiftData

@MainActor
enum DemoDataSeeder {
    private static let seedVersion = 1
    private static let seedVersionKey = "demoDataSeedVersion"

    static func seedIfNeeded(context: ModelContext, calendar: Calendar = .current) {
        guard shouldSeed(context: context, calendar: calendar) else { return }

        let now = Date.now
        let today = calendar.startOfDay(for: now)
        let entries = makeSeedEntries(today: today, now: now, calendar: calendar)

        for payload in entries {
            upsertEntry(payload, context: context, calendar: calendar, now: now)
        }

        do {
            try context.save()
            UserDefaults.standard.set(seedVersion, forKey: seedVersionKey)
        } catch {
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
            existing.bibleNotes = payload.bibleNotes
            existing.reflections = payload.reflections
            existing.updatedAt = now
            existing.completedAt = payload.completedAt
            return
        }

        context.insert(
            JournalEntry(
                entryDate: payload.entryDate,
                gratitudes: payload.gratitudes,
                needs: payload.needs,
                people: payload.people,
                bibleNotes: payload.bibleNotes,
                reflections: payload.reflections,
                createdAt: now,
                updatedAt: now,
                completedAt: payload.completedAt
            )
        )
    }

    private static func fetchEntry(for date: Date, context: ModelContext, calendar: Calendar) -> JournalEntry? {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
        let descriptor = FetchDescriptor<JournalEntry>(
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

        return [
            DemoEntryPayload(
                entryDate: today,
                gratitudes: [
                    item("感恩 morning coffee 讓我開始美好的一天", "Morning coffee 美好開始"),
                    item("Thanks to 小明 for helping with the project", "小明幫 project"),
                    item("和 Sarah 的 lunch meeting 很愉快", "Sarah lunch 愉快"),
                    item("Family dinner with lots of laughter", "Family dinner"),
                    item("天氣很好，散步很舒服", "天氣好散步")
                ],
                needs: [
                    item("需要 more sleep 和規律作息", "More sleep 規律"),
                    item("想 find time for 運動", "Find time 運動"),
                    item("Need clearer priorities at work", "Clear priorities"),
                    item("今天需要安靜專注", "安靜專注"),
                    item("More water during the day", "Drink more water")
                ],
                people: [
                    item("和媽媽的 weekly call", "媽媽 weekly call"),
                    item("Coffee with 老闆討論 promotion", "老闆 coffee talk"),
                    item("Pray for my brother's travel", "Brother travel"),
                    item("Check in with mentor after lunch", "Mentor check-in"),
                    item("Send encouragement to team", "Encourage team")
                ],
                bibleNotes: "John 15 reminded me to remain connected and let daily habits flow from that place.",
                reflections: "Today I feel grounded and hopeful. I want to move slowly, stay kind, and finish what matters most.",
                completedAt: now
            ),
            DemoEntryPayload(
                entryDate: yesterday,
                gratitudes: [
                    item("Grateful for quiet morning time", "Quiet morning"),
                    item("感恩同事主動幫忙", "同事幫忙"),
                    item("Nice walk after dinner", "Evening walk")
                ],
                needs: [
                    item("Need to rest my eyes", "Rest eyes"),
                    item("想要更好的時間管理", "時間管理"),
                    item("Need to follow up on one message", "Follow up"),
                    item("需要提早睡覺", "提早睡")
                ],
                people: [
                    item("Pray for my friend interview", "Friend interview"),
                    item("Call dad tonight", "Call dad")
                ],
                bibleNotes: "",
                reflections: "A little tired, but still thankful.",
                completedAt: nil
            ),
            DemoEntryPayload(
                entryDate: twoDaysAgo,
                gratitudes: [],
                needs: [],
                people: [],
                bibleNotes: "",
                reflections: "",
                completedAt: nil
            ),
            DemoEntryPayload(
                entryDate: threeDaysAgo,
                gratitudes: [
                    item("感謝朋友幫忙搬家", "朋友幫忙"),
                    item("感謝今天的陽光", "今日陽光"),
                    item("感謝午餐很美味", "午餐美味"),
                    item("感謝有時間禱告", "禱告時間"),
                    item("感謝身體恢復中", "身體恢復")
                ],
                needs: [
                    item("想找時間運動", "找時間運動"),
                    item("需要多休息", "多休息"),
                    item("需要整理房間", "整理房間"),
                    item("想減少滑手機", "少滑手機"),
                    item("需要補充水分", "補充水分")
                ],
                people: [
                    item("感謝媽媽的提醒", "媽媽提醒"),
                    item("想關心同事近況", "關心同事"),
                    item("為教會小組代禱", "小組代禱"),
                    item("感謝鄰居借工具", "鄰居借工具"),
                    item("想約朋友散步", "約朋友散步")
                ],
                bibleNotes: "詩篇提醒我在忙碌裡仍然可以安靜等候。",
                reflections: "今天節奏很滿，但仍有很多值得感恩的片刻。",
                completedAt: now
            ),
            DemoEntryPayload(
                entryDate: fourDaysAgo,
                gratitudes: [
                    item("Grateful for morning prayer", "Morning prayer"),
                    item("Thankful for smooth commute", "Smooth commute"),
                    item("感恩 coffee break", "Coffee break"),
                    item("Great feedback from teammate", "Team feedback")
                ],
                needs: [
                    item("Need one focused work block", "Focused block"),
                    item("需要 more patience", "More patience"),
                    item("Need to prep tomorrow plan", "Prep tomorrow")
                ],
                people: [
                    item("Check on grandma", "Grandma check"),
                    item("Message project partner", "Partner message"),
                    item("Pray for pastor", "Pray pastor")
                ],
                bibleNotes: "A short note on practicing patience during interruptions.",
                reflections: "I handled less than planned but stayed calm.",
                completedAt: nil
            )
        ]
    }

    private static func item(_ fullText: String, _ chipLabel: String) -> JournalItem {
        JournalItem(fullText: fullText, chipLabel: chipLabel, isTruncated: false)
    }
}

private struct DemoEntryPayload {
    let entryDate: Date
    let gratitudes: [JournalItem]
    let needs: [JournalItem]
    let people: [JournalItem]
    let bibleNotes: String
    let reflections: String
    let completedAt: Date?
}
#endif
