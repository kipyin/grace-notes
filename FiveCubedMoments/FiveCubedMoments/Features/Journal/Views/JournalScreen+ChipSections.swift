import SwiftUI

extension JournalScreen {

    enum ChipSection {
        case gratitude, need, person
    }

    func addNewTapped(section: ChipSection) {
        switch section {
        case .gratitude:
            JournalScreenChipHandling.clearChipInput(input: $gratitudeInput, editingIndex: $editingGratitudeIndex)
        case .need:
            JournalScreenChipHandling.clearChipInput(input: $needInput, editingIndex: $editingNeedIndex)
        case .person:
            JournalScreenChipHandling.clearChipInput(input: $personInput, editingIndex: $editingPersonIndex)
        }
    }

    func deleteChip(section: ChipSection, index: Int) {
        switch section {
        case .gratitude:
            JournalScreenChipHandling.performDelete(
                index: index,
                remove: { viewModel.removeGratitude(at: $0) },
                input: $gratitudeInput,
                editingIndex: $editingGratitudeIndex
            )
        case .need:
            JournalScreenChipHandling.performDelete(
                index: index,
                remove: { viewModel.removeNeed(at: $0) },
                input: $needInput,
                editingIndex: $editingNeedIndex
            )
        case .person:
            JournalScreenChipHandling.performDelete(
                index: index,
                remove: { viewModel.removePerson(at: $0) },
                input: $personInput,
                editingIndex: $editingPersonIndex
            )
        }
    }

    func chipTapped(section: ChipSection, index: Int) {
        switch section {
        case .gratitude:
            JournalScreenChipHandling.performChipTap(
                tapIndex: index,
                input: $gratitudeInput,
                editingIndex: $editingGratitudeIndex,
                operations: ChipSectionOperations(
                    update: viewModel.updateGratitude,
                    add: viewModel.addGratitude,
                    fullText: viewModel.fullTextForGratitude,
                    count: viewModel.gratitudes.count
                )
            )
        case .need:
            JournalScreenChipHandling.performChipTap(
                tapIndex: index,
                input: $needInput,
                editingIndex: $editingNeedIndex,
                operations: ChipSectionOperations(
                    update: viewModel.updateNeed,
                    add: viewModel.addNeed,
                    fullText: viewModel.fullTextForNeed,
                    count: viewModel.needs.count
                )
            )
        case .person:
            JournalScreenChipHandling.performChipTap(
                tapIndex: index,
                input: $personInput,
                editingIndex: $editingPersonIndex,
                operations: ChipSectionOperations(
                    update: viewModel.updatePerson,
                    add: viewModel.addPerson,
                    fullText: viewModel.fullTextForPerson,
                    count: viewModel.people.count
                )
            )
        }
    }
}
