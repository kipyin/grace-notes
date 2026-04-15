import Foundation

extension JournalViewModel {
    /// Returns true if the item was added (trimmed text non-empty and under slot limit).
    func addGratitude(_ sentence: String) async -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, gratitudes.count < Self.slotCount else { return false }

        gratitudes.append(Entry(fullText: trimmed))
        scheduleAutosave()
        return true
    }

    /// Returns true if the item was added (trimmed text non-empty and under slot limit).
    func addNeed(_ sentence: String) async -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, needs.count < Self.slotCount else { return false }

        needs.append(Entry(fullText: trimmed))
        scheduleAutosave()
        return true
    }

    /// Returns true if the item was added (trimmed text non-empty and under slot limit).
    func addPerson(_ sentence: String) async -> Bool {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, people.count < Self.slotCount else { return false }

        people.append(Entry(fullText: trimmed))
        scheduleAutosave()
        return true
    }

    /// Returns false for an invalid index or empty trimmed text; returns true if the stored value
    /// already matches or was updated.
    func updateGratitude(at index: Int, fullText: String) async -> Bool {
        guard gratitudes.indices.contains(index) else { return false }
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let existing = gratitudes[index]
        guard trimmed != existing.fullText else { return true }

        gratitudes[index] = Entry(fullText: trimmed, id: existing.id)
        scheduleAutosave()
        return true
    }

    /// Returns false for an invalid index or empty trimmed text; returns true if the stored value
    /// already matches or was updated.
    func updateNeed(at index: Int, fullText: String) async -> Bool {
        guard needs.indices.contains(index) else { return false }
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let existing = needs[index]
        guard trimmed != existing.fullText else { return true }

        needs[index] = Entry(fullText: trimmed, id: existing.id)
        scheduleAutosave()
        return true
    }

    /// Returns false for an invalid index or empty trimmed text; returns true if the stored value
    /// already matches or was updated.
    func updatePerson(at index: Int, fullText: String) async -> Bool {
        guard people.indices.contains(index) else { return false }
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let existing = people[index]
        guard trimmed != existing.fullText else { return true }

        people[index] = Entry(fullText: trimmed, id: existing.id)
        scheduleAutosave()
        return true
    }

    // MARK: - Immediate update/add for instant entry-row switching

    /// Updates the item immediately. Returns index or nil.
    func updateGratitudeImmediate(at index: Int, fullText: String) -> Int? {
        guard gratitudes.indices.contains(index) else { return nil }
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = gratitudes[index]
        guard trimmed != existing.fullText else { return index }

        gratitudes[index] = Entry(fullText: trimmed, id: existing.id)
        scheduleAutosave()
        return index
    }

    /// Appends item. Returns new index or nil.
    func addGratitudeImmediate(_ sentence: String) -> Int? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, gratitudes.count < Self.slotCount else { return nil }

        gratitudes.append(Entry(fullText: trimmed))
        scheduleAutosave()
        return gratitudes.count - 1
    }

    /// Updates the item immediately. Returns index or nil.
    func updateNeedImmediate(at index: Int, fullText: String) -> Int? {
        guard needs.indices.contains(index) else { return nil }
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = needs[index]
        guard trimmed != existing.fullText else { return index }

        needs[index] = Entry(fullText: trimmed, id: existing.id)
        scheduleAutosave()
        return index
    }

    /// Appends item. Returns new index or nil.
    func addNeedImmediate(_ sentence: String) -> Int? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, needs.count < Self.slotCount else { return nil }

        needs.append(Entry(fullText: trimmed))
        scheduleAutosave()
        return needs.count - 1
    }

    /// Updates the item immediately. Returns index or nil.
    func updatePersonImmediate(at index: Int, fullText: String) -> Int? {
        guard people.indices.contains(index) else { return nil }
        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let existing = people[index]
        guard trimmed != existing.fullText else { return index }

        people[index] = Entry(fullText: trimmed, id: existing.id)
        scheduleAutosave()
        return index
    }

    /// Appends item. Returns new index or nil.
    func addPersonImmediate(_ sentence: String) -> Int? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, people.count < Self.slotCount else { return nil }

        people.append(Entry(fullText: trimmed))
        scheduleAutosave()
        return people.count - 1
    }

    /// Returns true if the item was removed (valid index).
    func removeGratitude(at index: Int) -> Bool {
        guard gratitudes.indices.contains(index) else { return false }
        gratitudes.remove(at: index)
        scheduleAutosave()
        return true
    }

    /// Returns true if the item was removed (valid index).
    func removeNeed(at index: Int) -> Bool {
        guard needs.indices.contains(index) else { return false }
        needs.remove(at: index)
        scheduleAutosave()
        return true
    }

    /// Returns true if the item was removed (valid index).
    func removePerson(at index: Int) -> Bool {
        guard people.indices.contains(index) else { return false }
        people.remove(at: index)
        scheduleAutosave()
        return true
    }

    /// Returns true if an item moved to a new position.
    func moveGratitude(from sourceIndex: Int, to destinationOffset: Int) -> Bool {
        moveItem(in: &gratitudes, from: sourceIndex, to: destinationOffset)
    }

    /// Returns true if an item moved to a new position.
    func moveNeed(from sourceIndex: Int, to destinationOffset: Int) -> Bool {
        moveItem(in: &needs, from: sourceIndex, to: destinationOffset)
    }

    /// Returns true if an item moved to a new position.
    func movePerson(from sourceIndex: Int, to destinationOffset: Int) -> Bool {
        moveItem(in: &people, from: sourceIndex, to: destinationOffset)
    }

    private func moveItem(in items: inout [Entry], from sourceIndex: Int, to destinationOffset: Int) -> Bool {
        guard items.indices.contains(sourceIndex) else { return false }
        guard (0...items.count).contains(destinationOffset) else { return false }

        let noOpOffset = sourceIndex + 1
        guard destinationOffset != sourceIndex, destinationOffset != noOpOffset else { return false }

        let movedItem = items.remove(at: sourceIndex)
        let insertIndex = destinationOffset > sourceIndex ? destinationOffset - 1 : destinationOffset
        items.insert(movedItem, at: insertIndex)
        scheduleAutosave()
        return true
    }

    func updateReadingNotes(_ value: String) {
        guard value != readingNotes else { return }
        readingNotes = value
        scheduleAutosave()
    }

    func updateReflections(_ value: String) {
        guard value != reflections else { return }
        reflections = value
        scheduleAutosave()
    }

    func fullTextForGratitude(at index: Int) -> String? {
        guard gratitudes.indices.contains(index) else { return nil }
        return gratitudes[index].fullText
    }

    func fullTextForNeed(at index: Int) -> String? {
        guard needs.indices.contains(index) else { return nil }
        return needs[index].fullText
    }

    func fullTextForPerson(at index: Int) -> String? {
        guard people.indices.contains(index) else { return nil }
        return people[index].fullText
    }
}
