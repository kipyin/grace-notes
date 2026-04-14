import Foundation
import Combine
import Observation
import SwiftData

@MainActor
@Observable
final class JournalViewModel {
    var entryDate: Date = .now
    var gratitudes: [Entry] = []
    var needs: [Entry] = []
    var people: [Entry] = []
    var readingNotes: String = ""
    var reflections: String = ""
    private(set) var saveErrorMessage: String?
    private(set) var streakSummary: StreakSummary = .empty

    static let slotCount = Journal.slotCount
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let nowProvider: () -> Date
    @ObservationIgnored private let repository: JournalRepository
    @ObservationIgnored private let streakCalculator: StreakCalculator
    @ObservationIgnored private let autosaveTrigger = PassthroughSubject<Void, Never>()
    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var journalEntry: Journal?
    @ObservationIgnored private var hasLoadedToday = false
    @ObservationIgnored private var isHydrating = false
    @ObservationIgnored private var hasRecordedFirstSave = false
    @ObservationIgnored private var pendingDailyReminderRescheduleTask: Task<Void, Never>?
    /// When set, reschedules the daily reminder after today’s journal persists (debounced).
    @ObservationIgnored var dailyReminderRescheduleAction: (@MainActor () async -> Void)?

    init(
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init,
        repository: JournalRepository? = nil,
        streakCalculator: StreakCalculator? = nil,
        autosaveDebounceMilliseconds: Int? = nil
    ) {
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.repository = repository ?? JournalRepository(calendar: calendar)
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
        if loadEntry(for: nowProvider(), using: context) {
            hasLoadedToday = true
        }
    }

    @discardableResult
    func loadEntry(for date: Date, using context: ModelContext) -> Bool {
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
                return true
            }
            PerformanceTrace.end("JournalViewModel.loadEntry.fetchEntry.miss", startedAt: fetchTrace)
        } catch {
            PerformanceTrace.end("JournalViewModel.loadEntry.fetchEntry.failed", startedAt: fetchTrace)
            saveErrorMessage = String(localized: "journal.error.loadToday")
            PerformanceTrace.end("JournalViewModel.loadEntry.failed", startedAt: loadTrace)
            return false
        }

        let now = nowProvider()
        let newEntry = Journal(
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
        return true
    }

    private func hydrate(from entry: Journal) {
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
        saveCurrentJournalStateIfPossible()
    }

    /// Writes in-memory fields to the loaded journal immediately (e.g. before switching calendar day).
    func persistImmediately() {
        saveCurrentJournalStateIfPossible()
    }

    private func saveCurrentJournalStateIfPossible() {
        guard !isHydrating, let context = modelContext, let entry = journalEntry else { return }
        let saveTrace = PerformanceTrace.begin("JournalViewModel.persistChanges")

        entry.gratitudes = gratitudes
        entry.needs = needs
        entry.people = people
        entry.readingNotes = readingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.reflections = reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.updatedAt = nowProvider()
        // First time the user reaches harvest (all chip slots); cleared if chips drop below 5/5/5.
        entry.completedAt = entry.hasReachedBloom ? (entry.completedAt ?? nowProvider()) : nil

        do {
            try context.save()
            saveErrorMessage = nil
            refreshStreakSummary()
            scheduleDailyReminderRescheduleIfNeeded(for: entry)
            if !hasRecordedFirstSave {
                hasRecordedFirstSave = true
                PerformanceTrace.end("JournalViewModel.firstSave", startedAt: saveTrace)
            } else {
                PerformanceTrace.end("JournalViewModel.persistChanges", startedAt: saveTrace)
            }
        } catch {
            saveErrorMessage = String(localized: "journal.error.saveEntry")
            PerformanceTrace.end("JournalViewModel.persistChanges.failed", startedAt: saveTrace)
        }
    }

    /// Today mode only: if the calendar day is past the loaded journal, persist then load the current day.
    func refreshTodayIfStale(using context: ModelContext) {
        let now = nowProvider()
        let shownStart = calendar.startOfDay(for: entryDate)
        let todayStart = calendar.startOfDay(for: now)
        guard todayStart > shownStart else { return }
        persistImmediately()
        loadEntry(for: now, using: context)
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

    private func scheduleDailyReminderRescheduleIfNeeded(for entry: Journal) {
        guard let action = dailyReminderRescheduleAction else { return }
        let todayStart = calendar.startOfDay(for: nowProvider())
        guard calendar.startOfDay(for: entry.entryDate) == todayStart else { return }

        pendingDailyReminderRescheduleTask?.cancel()
        pendingDailyReminderRescheduleTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                await action()
            } catch {
                // Cancellation from rapid saves leaves the last scheduled reschedule in flight.
            }
        }
    }

    /// True when today's entry has all fifteen chips filled (Harvest / full grid).
    var completedToday: Bool {
        guard journalEntry != nil else { return false }
        return hasReachedBloom
    }

    /// Total chip slots across gratitudes, needs, and people (5 x 3 = 15).
    var sectionEntryCapacity: Int {
        JournalViewModel.slotCount * 3
    }

    /// Number of chips currently filled across gratitudes, needs, and people.
    var filledEntryCount: Int {
        gratitudes.count + needs.count + people.count
    }

    /// Whether all chip slots are filled, regardless of notes/reflections completion.
    var hasReachedBloom: Bool {
        gratitudes.count >= JournalViewModel.slotCount &&
            needs.count >= JournalViewModel.slotCount &&
            people.count >= JournalViewModel.slotCount
    }

    /// Localized progress text for the chips-only milestone.
    var entryCapacityProgressText: String {
        let formatKey = String(localized: "journal.completion.countOfTotal")
        return String(
            format: formatKey,
            locale: Locale.current,
            filledEntryCount,
            sectionEntryCapacity
        )
    }

    var completionLevel: JournalCompletionLevel {
        Journal.completionLevel(
            gratitudesCount: gratitudes.count,
            needsCount: needs.count,
            peopleCount: people.count
        )
    }

    /// True when gratitudes, needs, and people each have at least one chip (milestone 1/1/1 minimum).
    var hasAtLeastOneEntryInEachSection: Bool {
        Journal.minimumEntryCountAcrossSections(
            gratitudesCount: gratitudes.count,
            needsCount: needs.count,
            peopleCount: people.count
        ) >= 1
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
                reflections: reflections,
                completionLevel: completionLevel
            )
        )
    }
}
