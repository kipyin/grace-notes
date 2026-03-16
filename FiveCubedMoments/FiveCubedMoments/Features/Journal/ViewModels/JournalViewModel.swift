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
    private let summarizer: Summarizer
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
        summarizer: Summarizer = NaturalLanguageSummarizer()
    ) {
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.repository = repository ?? JournalRepository(calendar: calendar)
        self.summarizer = summarizer

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
            saveErrorMessage = "Unable to load today's entry."
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
        entry.completedAt = isCompleteEnough ? (entry.completedAt ?? nowProvider()) : nil

        do {
            try context.save()
            saveErrorMessage = nil
        } catch {
            saveErrorMessage = "Unable to save your journal entry."
        }
    }

    private func scheduleAutosave() {
        guard !isHydrating else { return }
        autosaveTrigger.send(())
    }

    private var isCompleteEnough: Bool {
        gratitudes.count >= Self.slotCount &&
        needs.count >= Self.slotCount &&
        people.count >= Self.slotCount &&
        !bibleNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !reflections.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var completedToday: Bool {
        guard journalEntry != nil else { return false }
        return isCompleteEnough
    }

    func addGratitude(_ sentence: String) {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, gratitudes.count < Self.slotCount else { return }

        let result = summarizer.summarize(trimmed)
        gratitudes.append(JournalItem(fullText: trimmed, chipLabel: result.label, isTruncated: result.isTruncated))
        scheduleAutosave()
    }

    func addNeed(_ sentence: String) {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, needs.count < Self.slotCount else { return }

        let result = summarizer.summarize(trimmed)
        needs.append(JournalItem(fullText: trimmed, chipLabel: result.label, isTruncated: result.isTruncated))
        scheduleAutosave()
    }

    func addPerson(_ sentence: String) {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, people.count < Self.slotCount else { return }

        let result = summarizer.summarize(trimmed)
        people.append(JournalItem(fullText: trimmed, chipLabel: result.label, isTruncated: result.isTruncated))
        scheduleAutosave()
    }

    func updateGratitude(at index: Int, fullText: String) {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < gratitudes.count, !trimmed.isEmpty else { return }

        let result = summarizer.summarize(trimmed)
        gratitudes[index] = JournalItem(fullText: trimmed, chipLabel: result.label, isTruncated: result.isTruncated)
        scheduleAutosave()
    }

    func updateNeed(at index: Int, fullText: String) {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < needs.count, !trimmed.isEmpty else { return }

        let result = summarizer.summarize(trimmed)
        needs[index] = JournalItem(fullText: trimmed, chipLabel: result.label, isTruncated: result.isTruncated)
        scheduleAutosave()
    }

    func updatePerson(at index: Int, fullText: String) {
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard index >= 0, index < people.count, !trimmed.isEmpty else { return }

        let result = summarizer.summarize(trimmed)
        people[index] = JournalItem(fullText: trimmed, chipLabel: result.label, isTruncated: result.isTruncated)
        scheduleAutosave()
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
