import Foundation
import Combine
import Observation
import SwiftData

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
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let nowProvider: () -> Date
    @ObservationIgnored private let repository: JournalRepository
    @ObservationIgnored let summarizerProvider: SummarizerProvider
    @ObservationIgnored private let streakCalculator: StreakCalculator
    @ObservationIgnored private let autosaveTrigger = PassthroughSubject<Void, Never>()
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var journalEntry: JournalEntry?
    @ObservationIgnored private var hasLoadedToday = false
    @ObservationIgnored private var isHydrating = false
    @ObservationIgnored private var hasRecordedFirstSave = false

    init(
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init,
        repository: JournalRepository? = nil,
        summarizerProvider: SummarizerProvider = .shared,
        streakCalculator: StreakCalculator? = nil,
        autosaveDebounceMilliseconds: Int? = nil
    ) {
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.repository = repository ?? JournalRepository(calendar: calendar)
        self.summarizerProvider = summarizerProvider
        self.streakCalculator = streakCalculator ?? StreakCalculator(calendar: calendar)

        let debounceMs: Int
        if let autosaveDebounceMilliseconds {
            debounceMs = autosaveDebounceMilliseconds
        } else if ProcessInfo.processInfo.arguments.contains("-grace-notes-uitest-short-autosave") {
            debounceMs = 50
        } else {
            debounceMs = 400
        }

        autosaveTrigger
            .debounce(for: .milliseconds(debounceMs), scheduler: RunLoop.main)
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

        let fetchTrace = PerformanceTrace.begin("JournalViewModel.loadEntry.fetchEntry")
        do {
            if let existing = try repository.fetchEntry(for: date, context: context) {
                PerformanceTrace.end("JournalViewModel.loadEntry.fetchEntry", startedAt: fetchTrace)
                let hydrateTrace = PerformanceTrace.begin("JournalViewModel.loadEntry.hydrate")
                hydrate(from: existing)
                PerformanceTrace.end("JournalViewModel.loadEntry.hydrate", startedAt: hydrateTrace)
                let streakTrace = PerformanceTrace.begin("JournalViewModel.loadEntry.streakRefresh")
                refreshStreakSummary()
                PerformanceTrace.end("JournalViewModel.loadEntry.streakRefresh", startedAt: streakTrace)
                PerformanceTrace.end("JournalViewModel.loadEntry.existing", startedAt: loadTrace)
                return
            }
            PerformanceTrace.end("JournalViewModel.loadEntry.fetchEntry.miss", startedAt: fetchTrace)
        } catch {
            PerformanceTrace.end("JournalViewModel.loadEntry.fetchEntry.failed", startedAt: fetchTrace)
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
        let hydrateTrace = PerformanceTrace.begin("JournalViewModel.loadEntry.hydrate")
        hydrate(from: newEntry)
        PerformanceTrace.end("JournalViewModel.loadEntry.hydrate", startedAt: hydrateTrace)
        let streakTrace = PerformanceTrace.begin("JournalViewModel.loadEntry.streakRefresh")
        refreshStreakSummary()
        PerformanceTrace.end("JournalViewModel.loadEntry.streakRefresh", startedAt: streakTrace)
        PerformanceTrace.end("JournalViewModel.loadEntry.newUnsaved", startedAt: loadTrace)
    }

    private func hydrate(from entry: JournalEntry) {
        journalEntry = entry
        isHydrating = true
        defer { isHydrating = false }

        entryDate = entry.entryDate
        gratitudes = entry.gratitudes ?? []
        needs = entry.needs ?? []
        people = entry.people ?? []
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
        // First time the user reaches harvest (all chip slots); cleared if chips drop below 5/5/5.
        entry.completedAt = entry.hasHarvestChips ? (entry.completedAt ?? nowProvider()) : nil

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
            saveErrorMessage = String(localized: "Unable to save your entry.")
            PerformanceTrace.end("JournalViewModel.persistChanges.failed", startedAt: saveTrace)
        }
    }

    private func refreshStreakSummary() {
        guard let context = modelContext else {
            streakSummary = .empty
            return
        }

        let streakTrace = PerformanceTrace.begin("JournalViewModel.refreshStreakSummary")
        do {
            streakSummary = try JournalStreakSummaryRefresher.loadSummary(
                repository: repository,
                calculator: streakCalculator,
                context: context,
                now: nowProvider()
            )
            PerformanceTrace.end("JournalViewModel.refreshStreakSummary", startedAt: streakTrace)
        } catch {
            streakSummary = .empty
            PerformanceTrace.end("JournalViewModel.refreshStreakSummary.failed", startedAt: streakTrace)
        }
    }

    func scheduleAutosave() {
        guard !isHydrating else { return }
        autosaveTrigger.send(())
    }

    /// True when today's entry meets **Abundance** (full rhythm), not harvest-only.
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

    /// Total chip slots across gratitudes, needs, and people (5 x 3 = 15).
    var chipsFiveCubedSlotCount: Int {
        JournalViewModel.slotCount * 3
    }

    /// Number of chips currently filled across gratitudes, needs, and people.
    var chipsFilledCount: Int {
        gratitudes.count + needs.count + people.count
    }

    /// Whether all chip slots are filled, regardless of notes/reflections completion.
    var isChipsFiveCubedComplete: Bool {
        gratitudes.count >= JournalViewModel.slotCount &&
            needs.count >= JournalViewModel.slotCount &&
            people.count >= JournalViewModel.slotCount
    }

    /// Localized progress text for the chips-only milestone.
    var chipsProgressText: String {
        let formatKey = String(localized: "%d of %d")
        return String(
            format: formatKey,
            locale: Locale.current,
            chipsFilledCount,
            chipsFiveCubedSlotCount
        )
    }

    var completionLevel: JournalCompletionLevel {
        JournalEntry.completionLevel(
            gratitudesCount: gratitudes.count,
            needsCount: needs.count,
            peopleCount: people.count
        )
    }
}

extension JournalViewModel {
    func exportSnapshot() -> JournalExportPayload {
        JournalExportPayload.make(
            from: JournalExportSnapshotSource(
                entryDate: entryDate,
                gratitudes: gratitudes,
                needs: needs,
                people: people,
                readingNotes: readingNotes,
                reflections: reflections
            )
        )
    }
}
