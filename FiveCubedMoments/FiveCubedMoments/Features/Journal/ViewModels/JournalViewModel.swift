import Foundation
import Combine
import Observation
import SwiftData

struct JournalExportPayload {
    let dateFormatted: String
    let gratitudes: [String]
    let needs: [String]
    let people: [String]
    let bibleNotes: String
    let reflections: String
}

/// Interim chip label length before summarization completes. Matches fallback in summarizers.
private let interimLabelMaxChars = 20

@MainActor
@Observable
final class JournalViewModel {
    var entryDate: Date = .now
    var gratitudes: [JournalItem] = []
    var needs: [JournalItem] = []
    var people: [JournalItem] = []
    var bibleNotes: String = ""
    var reflections: String = ""
    private(set) var saveErrorMessage: String?
    private(set) var streakSummary: StreakSummary = .empty

    static let slotCount = JournalEntry.slotCount

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
        bibleNotes = entry.bibleNotes
        reflections = entry.reflections
    }

    private func persistChanges() {
        guard !isHydrating, let context = modelContext, let entry = journalEntry else { return }
        let saveTrace = PerformanceTrace.begin("JournalViewModel.persistChanges")

        entry.gratitudes = gratitudes
        entry.needs = needs
        entry.people = people
        entry.bibleNotes = bibleNotes.trimmingCharacters(in: .whitespacesAndNewlines)
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
            bibleNotes: bibleNotes,
            reflections: reflections
        )
    }

    private func summarizeForChip(_ text: String, section: SummarizationSection) async -> SummarizationResult {
        await Task.detached(priority: .utility) { [summarizerProvider] in
            let summarizer = summarizerProvider.currentSummarizer()
            do {
                return try await summarizer.summarize(text, section: section)
            } catch {
                return (try? await NaturalLanguageSummarizer().summarize(text, section: section))
                    ?? SummarizationResult(
                        label: String(text.prefix(interimLabelMaxChars)),
                        isTruncated: text.count > interimLabelMaxChars
                    )
            }
        }.value
    }

    private func makeInterimResult(for text: String) -> SummarizationResult {
        SummarizationResult(
            label: String(text.prefix(interimLabelMaxChars)),
            isTruncated: text.count > interimLabelMaxChars
        )
    }

    private func makeInterimItem(fullText: String, id: UUID = UUID()) -> JournalItem {
        JournalItem(
            fullText: fullText,
            chipLabel: String(fullText.prefix(interimLabelMaxChars)),
            isTruncated: fullText.count > interimLabelMaxChars,
            id: id
        )
    }

    /// Returns true if the item was added (trimmed text non-empty and under slot limit).
    func addGratitude(_ sentence: String) async -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, gratitudes.count < Self.slotCount else { return false }

        let result = await summarizeForChip(trimmed, section: .gratitude)
        gratitudes.append(JournalItem(fullText: trimmed, chipLabel: result.label, isTruncated: result.isTruncated))
        scheduleAutosave()
        return true
    }

    /// Returns true if the item was added (trimmed text non-empty and under slot limit).
    func addNeed(_ sentence: String) async -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, needs.count < Self.slotCount else { return false }

        let result = await summarizeForChip(trimmed, section: .need)
        needs.append(JournalItem(fullText: trimmed, chipLabel: result.label, isTruncated: result.isTruncated))
        scheduleAutosave()
        return true
    }

    /// Returns true if the item was added (trimmed text non-empty and under slot limit).
    func addPerson(_ sentence: String) async -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, people.count < Self.slotCount else { return false }

        let result = await summarizeForChip(trimmed, section: .person)
        people.append(JournalItem(fullText: trimmed, chipLabel: result.label, isTruncated: result.isTruncated))
        scheduleAutosave()
        return true
    }

    /// Returns true if the item was updated (valid index and trimmed text non-empty).
    func updateGratitude(at index: Int, fullText: String) async -> Bool {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < gratitudes.count, !trimmed.isEmpty else { return false }

        // Fix 3: Skip summarization when fullText unchanged.
        guard trimmed != gratitudes[index].fullText else { return true }

        let result = await summarizeForChip(trimmed, section: .gratitude)
        gratitudes[index] = JournalItem(
            fullText: trimmed,
            chipLabel: result.label,
            isTruncated: result.isTruncated,
            id: gratitudes[index].id
        )
        scheduleAutosave()
        return true
    }

    /// Returns true if the item was updated (valid index and trimmed text non-empty).
    func updateNeed(at index: Int, fullText: String) async -> Bool {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < needs.count, !trimmed.isEmpty else { return false }

        // Fix 3: Skip summarization when fullText unchanged.
        guard trimmed != needs[index].fullText else { return true }

        let result = await summarizeForChip(trimmed, section: .need)
        needs[index] = JournalItem(
            fullText: trimmed,
            chipLabel: result.label,
            isTruncated: result.isTruncated,
            id: needs[index].id
        )
        scheduleAutosave()
        return true
    }

    /// Returns true if the item was updated (valid index and trimmed text non-empty).
    func updatePerson(at index: Int, fullText: String) async -> Bool {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < people.count, !trimmed.isEmpty else { return false }

        // Fix 3: Skip summarization when fullText unchanged.
        guard trimmed != people[index].fullText else { return true }

        let result = await summarizeForChip(trimmed, section: .person)
        people[index] = JournalItem(
            fullText: trimmed,
            chipLabel: result.label,
            isTruncated: result.isTruncated,
            id: people[index].id
        )
        scheduleAutosave()
        return true
    }

    // MARK: - Immediate update/add (no await) for instant chip switching

    /// Updates the item immediately with interim label. Returns index or nil.
    func updateGratitudeImmediate(at index: Int, fullText: String) -> Int? {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < gratitudes.count, !trimmed.isEmpty else { return nil }

        gratitudes[index] = makeInterimItem(fullText: trimmed, id: gratitudes[index].id)
        scheduleAutosave()
        return index
    }

    /// Appends item with interim label. Returns new index or nil.
    func addGratitudeImmediate(_ sentence: String) -> Int? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, gratitudes.count < Self.slotCount else { return nil }

        gratitudes.append(makeInterimItem(fullText: trimmed))
        scheduleAutosave()
        return gratitudes.count - 1
    }

    /// Updates the item immediately with interim label. Returns index or nil.
    func updateNeedImmediate(at index: Int, fullText: String) -> Int? {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < needs.count, !trimmed.isEmpty else { return nil }

        needs[index] = makeInterimItem(fullText: trimmed, id: needs[index].id)
        scheduleAutosave()
        return index
    }

    /// Appends item with interim label. Returns new index or nil.
    func addNeedImmediate(_ sentence: String) -> Int? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, needs.count < Self.slotCount else { return nil }

        needs.append(makeInterimItem(fullText: trimmed))
        scheduleAutosave()
        return needs.count - 1
    }

    /// Updates the item immediately with interim label. Returns index or nil.
    func updatePersonImmediate(at index: Int, fullText: String) -> Int? {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < people.count, !trimmed.isEmpty else { return nil }

        people[index] = makeInterimItem(fullText: trimmed, id: people[index].id)
        scheduleAutosave()
        return index
    }

    /// Appends item with interim label. Returns new index or nil.
    func addPersonImmediate(_ sentence: String) -> Int? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, people.count < Self.slotCount else { return nil }

        people.append(makeInterimItem(fullText: trimmed))
        scheduleAutosave()
        return people.count - 1
    }

    /// Runs summarization, then applies result only if the item still exists with same fullText.
    /// Captures item id + fullText at start so rapid edits/deletes/reorders don't apply stale labels.
    func summarizeAndUpdateChip(section: SummarizationSection, index: Int) async {
        guard let snapshot = snapshotForSection(section, at: index) else { return }
        let result = await summarizeForChip(snapshot.fullText, section: section)
        applySummaryResultIfValid(result, section: section, itemId: snapshot.id, expectedFullText: snapshot.fullText)
        scheduleAutosave()
    }

    private struct SectionSnapshot {
        let id: UUID
        let fullText: String
    }

    private func snapshotForSection(_ section: SummarizationSection, at index: Int) -> SectionSnapshot? {
        switch section {
        case .gratitude where index >= 0 && index < gratitudes.count:
            return SectionSnapshot(id: gratitudes[index].id, fullText: gratitudes[index].fullText)
        case .need where index >= 0 && index < needs.count:
            return SectionSnapshot(id: needs[index].id, fullText: needs[index].fullText)
        case .person where index >= 0 && index < people.count:
            return SectionSnapshot(id: people[index].id, fullText: people[index].fullText)
        default:
            return nil
        }
    }

    private func applySummaryResultIfValid(
        _ result: SummarizationResult,
        section: SummarizationSection,
        itemId: UUID,
        expectedFullText: String
    ) {
        switch section {
        case .gratitude:
            if let idx = gratitudes.firstIndex(where: { $0.id == itemId }),
               gratitudes[idx].fullText == expectedFullText {
                gratitudes[idx] = JournalItem(
                    fullText: gratitudes[idx].fullText,
                    chipLabel: result.label,
                    isTruncated: result.isTruncated,
                    id: gratitudes[idx].id
                )
            }
        case .need:
            if let idx = needs.firstIndex(where: { $0.id == itemId }),
               needs[idx].fullText == expectedFullText {
                needs[idx] = JournalItem(
                    fullText: needs[idx].fullText,
                    chipLabel: result.label,
                    isTruncated: result.isTruncated,
                    id: needs[idx].id
                )
            }
        case .person:
            if let idx = people.firstIndex(where: { $0.id == itemId }),
               people[idx].fullText == expectedFullText {
                people[idx] = JournalItem(
                    fullText: people[idx].fullText,
                    chipLabel: result.label,
                    isTruncated: result.isTruncated,
                    id: people[idx].id
                )
            }
        }
    }

    /// Returns true if the item was removed (valid index).
    func removeGratitude(at index: Int) -> Bool {
        guard index >= 0, index < gratitudes.count else { return false }
        gratitudes.remove(at: index)
        scheduleAutosave()
        return true
    }

    /// Returns true if the item was removed (valid index).
    func removeNeed(at index: Int) -> Bool {
        guard index >= 0, index < needs.count else { return false }
        needs.remove(at: index)
        scheduleAutosave()
        return true
    }

    /// Returns true if the item was removed (valid index).
    func removePerson(at index: Int) -> Bool {
        guard index >= 0, index < people.count else { return false }
        people.remove(at: index)
        scheduleAutosave()
        return true
    }

    func updateBibleNotes(_ value: String) {
        bibleNotes = value
        scheduleAutosave()
    }

    func updateReflections(_ value: String) {
        reflections = value
        scheduleAutosave()
    }

    func fullTextForGratitude(at index: Int) -> String? {
        guard index >= 0, index < gratitudes.count else { return nil }
        return gratitudes[index].fullText
    }

    func fullTextForNeed(at index: Int) -> String? {
        guard index >= 0, index < needs.count else { return nil }
        return needs[index].fullText
    }

    func fullTextForPerson(at index: Int) -> String? {
        guard index >= 0, index < people.count else { return nil }
        return people[index].fullText
    }

    func exportSnapshot() -> JournalExportPayload {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .long
        let dateStr = formatter.string(from: entryDate)
        return JournalExportPayload(
            dateFormatted: dateStr,
            gratitudes: gratitudes.map(\.fullText),
            needs: needs.map(\.fullText),
            people: people.map(\.fullText),
            bibleNotes: bibleNotes.trimmingCharacters(in: .whitespacesAndNewlines),
            reflections: reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
