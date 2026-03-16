import Foundation
import Combine
import SwiftData

struct JournalExportPayload {
    let dateFormatted: String
    let gratitudes: [String]
    let needs: [String]
    let people: [String]
    let bibleNotes: String
    let reflections: String
}

@MainActor
final class JournalViewModel: ObservableObject {
    @Published var entryDate: Date = .now
    @Published var gratitudes: [JournalItem] = []
    @Published var needs: [JournalItem] = []
    @Published var people: [JournalItem] = []
    @Published var bibleNotes: String = ""
    @Published var reflections: String = ""
    @Published private(set) var saveErrorMessage: String?

    static let slotCount = JournalEntry.slotCount

    private let calendar: Calendar
    private let nowProvider: () -> Date
    private let repository: JournalRepository
    private let summarizerProvider: SummarizerProvider
    private let autosaveTrigger = PassthroughSubject<Void, Never>()
    private var cancellables: Set<AnyCancellable> = []

    private var modelContext: ModelContext?
    private var journalEntry: JournalEntry?
    private var hasLoadedToday = false
    private var isHydrating = false

    init(
        calendar: Calendar = .current,
        nowProvider: @escaping () -> Date = Date.init,
        repository: JournalRepository? = nil,
        summarizerProvider: SummarizerProvider = .shared
    ) {
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.repository = repository ?? JournalRepository(calendar: calendar)
        self.summarizerProvider = summarizerProvider

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
        modelContext = context
        let dayStart = calendar.startOfDay(for: date)

        do {
            if let existing = try repository.fetchEntry(for: date, context: context) {
                hydrate(from: existing)
                return
            }
        } catch {
            saveErrorMessage = String(localized: "Unable to load today's entry.")
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
        persistChanges()
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
        } catch {
            saveErrorMessage = String(localized: "Unable to save your journal entry.")
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
        let summarizer = summarizerProvider.currentSummarizer()
        do {
            return try await summarizer.summarize(text, section: section)
        } catch {
            return (try? await NaturalLanguageSummarizer().summarize(text, section: section))
                ?? SummarizationResult(label: String(text.prefix(20)), isTruncated: text.count > 20)
        }
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

    /// Updates the item immediately with interim label (first 20 chars). Returns index or nil.
    func updateGratitudeImmediate(at index: Int, fullText: String) -> Int? {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < gratitudes.count, !trimmed.isEmpty else { return nil }

        let interimLabel = String(trimmed.prefix(20))
        gratitudes[index] = JournalItem(
            fullText: trimmed,
            chipLabel: interimLabel,
            isTruncated: trimmed.count > 20,
            id: gratitudes[index].id
        )
        scheduleAutosave()
        return index
    }

    /// Appends item with interim label. Returns new index or nil.
    func addGratitudeImmediate(_ sentence: String) -> Int? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, gratitudes.count < Self.slotCount else { return nil }

        let interimLabel = String(trimmed.prefix(20))
        gratitudes.append(JournalItem(fullText: trimmed, chipLabel: interimLabel, isTruncated: trimmed.count > 20))
        scheduleAutosave()
        return gratitudes.count - 1
    }

    /// Updates the item immediately with interim label. Returns index or nil.
    func updateNeedImmediate(at index: Int, fullText: String) -> Int? {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < needs.count, !trimmed.isEmpty else { return nil }

        let interimLabel = String(trimmed.prefix(20))
        needs[index] = JournalItem(
            fullText: trimmed,
            chipLabel: interimLabel,
            isTruncated: trimmed.count > 20,
            id: needs[index].id
        )
        scheduleAutosave()
        return index
    }

    /// Appends item with interim label. Returns new index or nil.
    func addNeedImmediate(_ sentence: String) -> Int? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, needs.count < Self.slotCount else { return nil }

        let interimLabel = String(trimmed.prefix(20))
        needs.append(JournalItem(fullText: trimmed, chipLabel: interimLabel, isTruncated: trimmed.count > 20))
        scheduleAutosave()
        return needs.count - 1
    }

    /// Updates the item immediately with interim label. Returns index or nil.
    func updatePersonImmediate(at index: Int, fullText: String) -> Int? {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < people.count, !trimmed.isEmpty else { return nil }

        let interimLabel = String(trimmed.prefix(20))
        people[index] = JournalItem(
            fullText: trimmed,
            chipLabel: interimLabel,
            isTruncated: trimmed.count > 20,
            id: people[index].id
        )
        scheduleAutosave()
        return index
    }

    /// Appends item with interim label. Returns new index or nil.
    func addPersonImmediate(_ sentence: String) -> Int? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, people.count < Self.slotCount else { return nil }

        let interimLabel = String(trimmed.prefix(20))
        people.append(JournalItem(fullText: trimmed, chipLabel: interimLabel, isTruncated: trimmed.count > 20))
        scheduleAutosave()
        return people.count - 1
    }

    /// Runs summarization (offloaded from main actor when possible), then applies result and schedules autosave.
    func summarizeAndUpdateChip(section: SummarizationSection, index: Int) async {
        guard let fullText = fullTextForSection(section, at: index) else { return }
        let result = await summarizeForChip(fullText, section: section)
        applySummaryResult(result, to: section, at: index)
        scheduleAutosave()
    }

    private func fullTextForSection(_ section: SummarizationSection, at index: Int) -> String? {
        switch section {
        case .gratitude: return index >= 0 && index < gratitudes.count ? gratitudes[index].fullText : nil
        case .need: return index >= 0 && index < needs.count ? needs[index].fullText : nil
        case .person: return index >= 0 && index < people.count ? people[index].fullText : nil
        }
    }

    private func applySummaryResult(_ result: SummarizationResult, to section: SummarizationSection, at index: Int) {
        switch section {
        case .gratitude where index >= 0 && index < gratitudes.count:
            gratitudes[index] = JournalItem(
                fullText: gratitudes[index].fullText,
                chipLabel: result.label,
                isTruncated: result.isTruncated,
                id: gratitudes[index].id
            )
        case .need where index >= 0 && index < needs.count:
            needs[index] = JournalItem(
                fullText: needs[index].fullText,
                chipLabel: result.label,
                isTruncated: result.isTruncated,
                id: needs[index].id
            )
        case .person where index >= 0 && index < people.count:
            people[index] = JournalItem(
                fullText: people[index].fullText,
                chipLabel: result.label,
                isTruncated: result.isTruncated,
                id: people[index].id
            )
        default:
            break
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
