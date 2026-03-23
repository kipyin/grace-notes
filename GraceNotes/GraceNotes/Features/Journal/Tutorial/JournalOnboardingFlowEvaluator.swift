import Foundation

enum JournalOnboardingStep: Equatable {
    case gratitude
    case need
    case person
    case ripening
    case harvest
    case abundance
}

enum JournalOnboardingSection: Hashable {
    case gratitude
    case need
    case person
    case readingNotes
    case reflections
}

enum JournalOnboardingSectionState: Equatable {
    case standard
    case active
    case available
    case locked(reason: String)
}

/// Title + body copy shown above a single journal section during guided onboarding.
struct JournalOnboardingSectionGuidance: Equatable {
    let title: String
    let message: String
    /// Optional second line under `message` (e.g. keyboard hint under the first gratitude sentence).
    let messageSecondary: String?

    init(title: String, message: String, messageSecondary: String? = nil) {
        self.title = title
        self.message = message
        self.messageSecondary = messageSecondary
    }
}

struct JournalOnboardingPresentation: Equatable {
    let step: JournalOnboardingStep?
    let title: String?
    let message: String?
    let sectionStates: [JournalOnboardingSection: JournalOnboardingSectionState]

    static let inactive = JournalOnboardingPresentation(
        step: nil,
        title: nil,
        message: nil,
        sectionStates: [:]
    )

    var isGuidanceActive: Bool {
        step != nil
    }

    func state(for section: JournalOnboardingSection) -> JournalOnboardingSectionState {
        sectionStates[section] ?? .standard
    }

    /// Per-section placement: linear steps use the active row; multi-active chips use Gratitudes.
    /// Abundance uses Reading Notes.
    func sectionGuidance(for section: JournalOnboardingSection) -> JournalOnboardingSectionGuidance? {
        guard let title, let message, let step else { return nil }
        let bannerSection: JournalOnboardingSection = switch step {
        case .gratitude:
            .gratitude
        case .need:
            .need
        case .person:
            .person
        case .ripening, .harvest:
            .gratitude
        case .abundance:
            .readingNotes
        }
        guard section == bannerSection else { return nil }
        let secondary: String? = switch step {
        case .gratitude:
            String(localized: "When you're finished, press Return or Enter on your keyboard.")
        case .need, .person, .ripening, .harvest, .abundance:
            nil
        }
        return JournalOnboardingSectionGuidance(title: title, message: message, messageSecondary: secondary)
    }
}

struct JournalOnboardingContext: Equatable {
    let entryDate: Date?
    let gratitudesCount: Int
    let needsCount: Int
    let peopleCount: Int
    let readingNotes: String
    let reflections: String
    let hasCompletedGuidedJournal: Bool

    var notesTrimmed: String {
        readingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var reflectionsTrimmed: String {
        reflections.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasRipening: Bool {
        JournalEntry.minChipSectionCount(
            gratitudesCount: gratitudesCount,
            needsCount: needsCount,
            peopleCount: peopleCount
        ) >= 3
    }

    var hasHarvest: Bool {
        JournalEntry.hasAllFifteenChips(
            gratitudesCount: gratitudesCount,
            needsCount: needsCount,
            peopleCount: peopleCount
        )
    }
}

enum JournalOnboardingFlowEvaluator {
    static func presentation(for context: JournalOnboardingContext) -> JournalOnboardingPresentation {
        guard context.entryDate == nil, !context.hasCompletedGuidedJournal else {
            return .inactive
        }

        if context.gratitudesCount == 0 {
            return firstGratitudePresentation()
        }

        if context.needsCount == 0 {
            return firstNeedPresentation()
        }

        if context.peopleCount == 0 {
            return firstPersonPresentation()
        }

        if !context.hasRipening {
            return ripeningPresentation()
        }

        if !context.hasHarvest {
            return harvestPresentation()
        }

        if context.notesTrimmed.isEmpty || context.reflectionsTrimmed.isEmpty {
            return abundancePresentation()
        }

        return .inactive
    }
}

private extension JournalOnboardingFlowEvaluator {
    static func presentation(
        step: JournalOnboardingStep,
        title: String,
        message: String,
        states: [JournalOnboardingSection: JournalOnboardingSectionState]
    ) -> JournalOnboardingPresentation {
        JournalOnboardingPresentation(
            step: step,
            title: title,
            message: message,
            sectionStates: states
        )
    }

    static func chipSectionPresentation(
        chipState: JournalOnboardingSectionState,
        notesState: JournalOnboardingSectionState,
        reflectionsState: JournalOnboardingSectionState
    ) -> [JournalOnboardingSection: JournalOnboardingSectionState] {
        [
            .gratitude: chipState,
            .need: chipState,
            .person: chipState,
            .readingNotes: notesState,
            .reflections: reflectionsState
        ]
    }

    static func lockedNotesState() -> JournalOnboardingSectionState {
        .locked(reason: String(localized: "Reading Notes open after Gratitudes, Needs, and People are full."))
    }

    static func lockedReflectionsState() -> JournalOnboardingSectionState {
        .locked(reason: String(localized: "Reflections open after Gratitudes, Needs, and People are full."))
    }

    static func firstGratitudePresentation() -> JournalOnboardingPresentation {
        presentation(
            step: .gratitude,
            title: String(localized: "Start gently"),
            message: String(localized: "Start with one gratitude."),
            states: [
                .gratitude: .active,
                .need: .locked(reason: String(localized: "Needs will open after your first gratitude.")),
                .person: .locked(
                    reason: String(localized: "People in Mind will open after your first gratitude.")
                ),
                .readingNotes: lockedNotesState(),
                .reflections: lockedReflectionsState()
            ]
        )
    }

    static func firstNeedPresentation() -> JournalOnboardingPresentation {
        presentation(
            step: .need,
            title: String(localized: "Keep going"),
            message: String(localized: "Now add one need for today."),
            states: [
                .gratitude: .available,
                .need: .active,
                .person: .locked(reason: String(localized: "People in Mind will open after your first need.")),
                .readingNotes: lockedNotesState(),
                .reflections: lockedReflectionsState()
            ]
        )
    }

    static func firstPersonPresentation() -> JournalOnboardingPresentation {
        presentation(
            step: .person,
            title: String(localized: "One more step"),
            message: String(localized: "Who is on your mind today?"),
            states: [
                .gratitude: .available,
                .need: .available,
                .person: .active,
                .readingNotes: lockedNotesState(),
                .reflections: lockedReflectionsState()
            ]
        )
    }

    static func ripeningPresentation() -> JournalOnboardingPresentation {
        presentation(
            step: .ripening,
            title: String(localized: "Seed"),
            message: String(localized: "You've planted Seed. Keep going until each section has three."),
            states: chipSectionPresentation(
                chipState: .active,
                notesState: .active,
                reflectionsState: .active
            )
        )
    }

    static func harvestPresentation() -> JournalOnboardingPresentation {
        presentation(
            step: .harvest,
            title: String(localized: "Ripening"),
            message: String(
                localized: "You're ready to keep filling the rows. Reach five in each section when it feels right."
            ),
            states: chipSectionPresentation(
                chipState: .active,
                notesState: .active,
                reflectionsState: .active
            )
        )
    }

    static func abundancePresentation() -> JournalOnboardingPresentation {
        presentation(
            step: .abundance,
            title: String(localized: "Harvest"),
            message: String(
                // swiftlint:disable:next line_length
                localized: "You've filled Gratitudes, Needs, and People. Add reading notes and reflections when you're ready for Abundance."
            ),
            states: chipSectionPresentation(
                chipState: .available,
                notesState: .active,
                reflectionsState: .active
            )
        )
    }
}
