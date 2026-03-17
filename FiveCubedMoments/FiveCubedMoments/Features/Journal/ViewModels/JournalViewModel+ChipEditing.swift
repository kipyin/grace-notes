import Foundation

extension JournalViewModel {
    private func summarizeForChip(_ text: String, section: SummarizationSection) async -> SummarizationResult {
        await Task.detached(priority: .utility) { [summarizerProvider] in
            let summarizer = summarizerProvider.currentSummarizer()
            do {
                return try await summarizer.summarize(text, section: section)
            } catch {
                return (try? await NaturalLanguageSummarizer().summarize(text, section: section))
                    ?? SummarizationResult(
                        label: String(text.prefix(Self.interimLabelMaxChars)),
                        isTruncated: text.count > Self.interimLabelMaxChars
                    )
            }
        }.value
    }

    private func makeInterimResult(for text: String) -> SummarizationResult {
        SummarizationResult(
            label: String(text.prefix(Self.interimLabelMaxChars)),
            isTruncated: text.count > Self.interimLabelMaxChars
        )
    }

    private func makeInterimItem(fullText: String, id: UUID = UUID()) -> JournalItem {
        JournalItem(
            fullText: fullText,
            chipLabel: String(fullText.prefix(Self.interimLabelMaxChars)),
            isTruncated: fullText.count > Self.interimLabelMaxChars,
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
        applySummaryResultIfValid(
            result,
            section: section,
            itemId: snapshot.id,
            expectedFullText: snapshot.fullText
        )
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
}
