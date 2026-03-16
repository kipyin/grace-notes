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
                    updateImmediate: viewModel.updateGratitudeImmediate,
                    addImmediate: viewModel.addGratitudeImmediate,
                    fullText: viewModel.fullTextForGratitude,
                    count: viewModel.gratitudes.count,
                    summarizeAndUpdateChip: { idx in
                        await viewModel.summarizeAndUpdateChip(section: SummarizationSection.gratitude, index: idx)
                    }
                )
            )
        case .need:
            JournalScreenChipHandling.performChipTap(
                tapIndex: index,
                input: $needInput,
                editingIndex: $editingNeedIndex,
                operations: ChipSectionOperations(
                    updateImmediate: viewModel.updateNeedImmediate,
                    addImmediate: viewModel.addNeedImmediate,
                    fullText: viewModel.fullTextForNeed,
                    count: viewModel.needs.count,
                    summarizeAndUpdateChip: { idx in
                        await viewModel.summarizeAndUpdateChip(section: SummarizationSection.need, index: idx)
                    }
                )
            )
        case .person:
            JournalScreenChipHandling.performChipTap(
                tapIndex: index,
                input: $personInput,
                editingIndex: $editingPersonIndex,
                operations: ChipSectionOperations(
                    updateImmediate: viewModel.updatePersonImmediate,
                    addImmediate: viewModel.addPersonImmediate,
                    fullText: viewModel.fullTextForPerson,
                    count: viewModel.people.count,
                    summarizeAndUpdateChip: { idx in
                        await viewModel.summarizeAndUpdateChip(section: SummarizationSection.person, index: idx)
                    }
                )
            )
        }
    }
}
