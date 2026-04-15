import Foundation

enum JournalOnboardingStep: Equatable {
    case gratitude
    case need
    case person
}

private extension JournalOnboardingStep {
    /// Section whose row hosts the onboarding banner for this linear step.
    var bannerSection: JournalOnboardingSection {
        switch self {
        case .gratitude:
            .gratitude
        case .need:
            .need
        case .person:
            .person
        }
    }
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

    /// Guided step plus body copy; both are required for a visible banner (`sectionGuidance`).
    private var guidedStepWithMessage: (step: JournalOnboardingStep, message: String)? {
        guard let step, let message else { return nil }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return (step, trimmed)
    }

    var isGuidanceActive: Bool {
        step != nil && !(message?.isEmpty ?? true)
    }

    func state(for section: JournalOnboardingSection) -> JournalOnboardingSectionState {
        sectionStates[section] ?? .standard
    }

    /// Per-section placement: linear steps use the active row.
    func sectionGuidance(for section: JournalOnboardingSection) -> JournalOnboardingSectionGuidance? {
        guard let message, let step else { return nil }
        guard !message.isEmpty else { return nil }
        guard section == step.bannerSection else { return nil }
        let secondary: String? = switch step {
        case .gratitude:
            String(localized: "journal.onboarding.keyboardFinishHint")
        case .need, .person:
            nil
        }
        return JournalOnboardingSectionGuidance(
            title: title ?? "",
            message: message,
            messageSecondary: secondary
        )
    }
}

struct JournalOnboardingContext: Equatable {
    let entryDate: Date?
    let gratitudesCount: Int
    let needsCount: Int
    let peopleCount: Int
    let hasCompletedGuidedJournal: Bool
}

enum JournalOnboardingFlowEvaluator {
    /// Linear guided steps through first 1/1/1; afterwards presentation is inactive on Today.
    static func presentation(for context: JournalOnboardingContext) -> JournalOnboardingPresentation {
        guard context.entryDate == nil, !context.hasCompletedGuidedJournal else {
            return .inactive
        }

        let gratitudes = max(0, context.gratitudesCount)
        let needs = max(0, context.needsCount)
        let people = max(0, context.peopleCount)

        if gratitudes == 0 {
            return firstGratitudePresentation()
        }

        if needs == 0 {
            return firstNeedPresentation()
        }

        if people == 0 {
            return firstPersonPresentation()
        }

        return .inactive
    }
}

private extension JournalOnboardingFlowEvaluator {
    static func presentation(
        step: JournalOnboardingStep,
        title: String?,
        message: String,
        states: [JournalOnboardingSection: JournalOnboardingSectionState]
    ) -> JournalOnboardingPresentation {
        if message.isEmpty {
            #if DEBUG
            assertionFailure(
                "Journal onboarding requires non-empty message for step \(step); "
                    + "treating as inactive to avoid locked sections without copy."
            )
            #endif
            return .inactive
        }
        return JournalOnboardingPresentation(
            step: step,
            title: title,
            message: message,
            sectionStates: states
        )
    }

    static func lockedNotesState() -> JournalOnboardingSectionState {
        .locked(reason: String(localized: "journal.onboarding.readingNotesLockedReason"))
    }

    static func lockedReflectionsState() -> JournalOnboardingSectionState {
        .locked(reason: String(localized: "journal.onboarding.reflectionsLockedReason"))
    }

    static func firstGratitudePresentation() -> JournalOnboardingPresentation {
        presentation(
            step: .gratitude,
            title: nil,
            message: String(localized: "journal.onboarding.startWithGratitude"),
            states: [
                .gratitude: .active,
                .need: .locked(reason: String(localized: "journal.onboarding.needsLockedReason")),
                .person: .locked(
                    reason: String(localized: "journal.onboarding.peopleLockedAfterGratitude")
                ),
                .readingNotes: lockedNotesState(),
                .reflections: lockedReflectionsState()
            ]
        )
    }

    static func firstNeedPresentation() -> JournalOnboardingPresentation {
        presentation(
            step: .need,
            title: String(localized: "journal.onboarding.keepGoingTitle"),
            message: String(localized: "journal.onboarding.addOneNeedMessage"),
            states: [
                .gratitude: .available,
                .need: .active,
                .person: .locked(reason: String(localized: "journal.onboarding.peopleLockedAfterNeed")),
                .readingNotes: lockedNotesState(),
                .reflections: lockedReflectionsState()
            ]
        )
    }

    static func firstPersonPresentation() -> JournalOnboardingPresentation {
        presentation(
            step: .person,
            title: String(localized: "journal.onboarding.oneMoreStepTitle"),
            message: String(localized: "journal.onboarding.whoOnMind"),
            states: [
                .gratitude: .available,
                .need: .available,
                .person: .active,
                .readingNotes: lockedNotesState(),
                .reflections: lockedReflectionsState()
            ]
        )
    }
}
