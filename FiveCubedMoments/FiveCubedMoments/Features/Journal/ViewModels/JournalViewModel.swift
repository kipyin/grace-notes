import Foundation
import Combine
import Observation
import SwiftData

struct JournalExportPayload {
    let dateFormatted: String
    let gratitudes: [String]
    let needs: [String]
    let people: [String]
    let readingNotes: String
    let reflections: String
}

@MainActor
@Observable
final class JournalViewModel {
    var entryDate: Date = .now
    var gratitudes: [JournalItem] = []
    var needs: [JournalItem] = []
    var people: [JournalItem] = []
    var readingNotes: String = ""
    var reflections: String = ""
    private(set) var saveErrorMessage: String?
    private(set) var streakSummary: StreakSummary = .empty

    static let slotCount = JournalEntry.slotCount
    private static let interimLabelMaxChars = 20
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let nowProvider: () -> Date
    @ObservationIgnored private let repository: JournalRepository
    @ObservationIgnored private let summarizerProvider: SummarizerProvider
    @ObservationIgnored private let streakCalculator: StreakCalculator
    @ObservationIgnored private let autosaveTrigger = PassthroughSubject<Void, Never>()
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var journalEntry: JournalEntry?
    @ObservationIgnored private var hasLoadedToday = false
    @ObservationIgnored private var isHydrating = false
    @ObservationIgnored private var hasRecordedFirstSave = false
    @ObservationIgnored private var hasLoadedStreakCache = false
    @ObservationIgnored private var cachedEntriesForStreak: [JournalEntry] = []

    init(
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init,
        repository: JournalRepository? = nil,
        summarizerProvider: SummarizerProvider = .shared,
        streakCalculator: StreakCalculator? = nil
    ) {
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.repository = repository ?? JournalRepository(calendar: calendar)
        self.summarizerProvider = summarizerProvider
        self.streakCalculator = streakCalculator ?? StreakCalculator(calendar: calendar)

        autosaveTrigger
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.persistChanges()
            }
            .store(in: &cancellables)
    }

    func loadTodayIfNeeded(using context: ModelContext) {
        guard !hasLoadedToday else { return }
        hasLoadedToday = true
        loadEntry(for: nowProvider(), using: context)
    }

    func loadEntry(for date: Date, using context: ModelContext) {
        let loadTrace = PerformanceTrace.begin("JournalViewModel.loadEntry")
        modelContext = context
        let dayStart = calendar.startOfDay(for: date)

        do {
            if let existing = try repository.fetchEntry(for: date, context: context) {
                hydrate(from: existing)
                refreshStreakSummary(forceReload: true)
                PerformanceTrace.end("JournalViewModel.loadEntry.existing", startedAt: loadTrace)
                return
            }
        } catch {
            saveErrorMessage = String(localized: "Unable to load today's entry.")
            PerformanceTrace.end("JournalViewModel.loadEntry.failed", startedAt: loadTrace)
            return
        }

        let now = nowProvider()
        let newEntry = JournalEntry(
            entryDate: dayStart,
            createdAt: now,
            updatedAt: now
        )
        context.insert(newEntry)
        hydrate(from: newEntry)
        refreshStreakSummary(forceReload: !hasLoadedStreakCache)
        PerformanceTrace.end("JournalViewModel.loadEntry.newUnsaved", startedAt: loadTrace)
    }

    private func hydrate(from entry: JournalEntry) {
        journalEntry = entry
        isHydrating = true
        defer { isHydrating = false }

        entryDate = entry.entryDate
        gratitudes = entry.gratitudes
        needs = entry.needs
        people = entry.people
        readingNotes = entry.readingNotes
        reflections = entry.reflections
    }

    private func persistChanges() {
        guard !isHydrating, let context = modelContext, let entry = journalEntry else { return }
        let saveTrace = PerformanceTrace.begin("JournalViewModel.persistChanges")

        entry.gratitudes = gratitudes
        entry.needs = needs
        entry.people = people
        entry.readingNotes = readingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.reflections = reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.updatedAt = nowProvider()
        entry.completedAt = entry.isComplete ? (entry.completedAt ?? nowProvider()) : nil

        do {
            try context.save()
            saveErrorMessage = nil
            refreshStreakSummary()
            if !hasRecordedFirstSave {
                hasRecordedFirstSave = true
                PerformanceTrace.end("JournalViewModel.firstSave", startedAt: saveTrace)
            } else {
                PerformanceTrace.end("JournalViewModel.persistChanges", startedAt: saveTrace)
            }
        } catch {
            saveErrorMessage = String(localized: "Unable to save your journal entry.")
            PerformanceTrace.end("JournalViewModel.persistChanges.failed", startedAt: saveTrace)
        }
    }

    private func refreshStreakSummary(forceReload: Bool = false) {
        guard let context = modelContext else {
            streakSummary = .empty
            return
        }

        let streakTrace = PerformanceTrace.begin("JournalViewModel.refreshStreakSummary")
        do {
            if forceReload || !hasLoadedStreakCache {
                cachedEntriesForStreak = try repository.fetchAllEntries(context: context)
                hasLoadedStreakCache = true
            }

            if let entry = journalEntry {
                if let index = cachedEntriesForStreak.firstIndex(where: { $0.id == entry.id }) {
                    cachedEntriesForStreak[index] = entry
                } else {
                    cachedEntriesForStreak.append(entry)
                    cachedEntriesForStreak.sort { $0.entryDate > $1.entryDate }
                }
            }

            streakSummary = streakCalculator.summary(from: cachedEntriesForStreak, now: nowProvider())
            PerformanceTrace.end("JournalViewModel.refreshStreakSummary", startedAt: streakTrace)
        } catch {
            streakSummary = .empty
            PerformanceTrace.end("JournalViewModel.refreshStreakSummary.failed", startedAt: streakTrace)
        }
    }

    private func scheduleAutosave() {
        guard !isHydrating else { return }
        autosaveTrigger.send(())
    }

    var completedToday: Bool {
        guard journalEntry != nil else { return false }
        return JournalEntry.criteriaMet(
            gratitudesCount: gratitudes.count,
            needsCount: needs.count,
            peopleCount: people.count,
            readingNotes: readingNotes,
            reflections: reflections
        )
    }
}

extension JournalViewModel {
    func exportSnapshot() -> JournalExportPayload {
        let dateStr = entryDate.formatted(date: .long, time: .omitted)
        return JournalExportPayload(
            dateFormatted: dateStr,
            gratitudes: gratitudes.map(\.fullText),
            needs: needs.map(\.fullText),
            people: people.map(\.fullText),
            readingNotes: readingNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            reflections: reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
