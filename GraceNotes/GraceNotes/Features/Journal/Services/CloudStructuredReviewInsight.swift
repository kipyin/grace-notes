import Foundation

// MARK: - API payload (cloud returns this; app renders user-facing copy)

enum CloudStructuredInsightKind: String, Decodable, Sendable {
    case cooccurrence
    case contrast
    case temporalShift
    case personThemePairing
    case dominantCategory
}

enum CloudReviewThemeCategory: String, Decodable, Sendable {
    case gratitudes
    case needs
    case people
}

struct CloudTypedThemeRef: Decodable, Equatable, Sendable {
    let label: String
    let category: CloudReviewThemeCategory
}

/// Typed insight selection from the cloud model. User-facing strings are rendered locally.
struct CloudTypedInsightAPIResponse: Decodable, Sendable {
    let insightType: CloudStructuredInsightKind
    let primaryTheme: CloudTypedThemeRef
    let secondaryTheme: CloudTypedThemeRef?
    let evidenceDays: Int?
    let recurringGratitudes: [CloudReviewTheme]
    let recurringNeeds: [CloudReviewTheme]
    let recurringPeople: [CloudReviewTheme]

    enum CodingKeys: String, CodingKey {
        case insightType
        case primaryTheme
        case secondaryTheme
        case evidenceDays
        case recurringGratitudes
        case recurringNeeds
        case recurringPeople
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        insightType = try container.decode(CloudStructuredInsightKind.self, forKey: .insightType)
        primaryTheme = try container.decode(CloudTypedThemeRef.self, forKey: .primaryTheme)
        secondaryTheme = try container.decodeIfPresent(CloudTypedThemeRef.self, forKey: .secondaryTheme)
        evidenceDays = try container.decodeIfPresent(Int.self, forKey: .evidenceDays)
        recurringGratitudes = try container.decodeIfPresent([CloudReviewTheme].self, forKey: .recurringGratitudes) ?? []
        recurringNeeds = try container.decodeIfPresent([CloudReviewTheme].self, forKey: .recurringNeeds) ?? []
        recurringPeople = try container.decodeIfPresent([CloudReviewTheme].self, forKey: .recurringPeople) ?? []
    }
}

// MARK: - Resolved insight for rendering

enum CloudResolvedStructuredInsight: Equatable, Sendable {
    case cooccurrence(
        first: CloudReviewTheme,
        second: CloudReviewTheme,
        firstCategory: CloudReviewThemeCategory,
        secondCategory: CloudReviewThemeCategory
    )
    case contrast(gratitude: CloudReviewTheme, need: CloudReviewTheme)
    case temporalShift(theme: CloudReviewTheme, category: CloudReviewThemeCategory, evidenceDays: Int?)
    case personThemePairing(person: CloudReviewTheme, theme: CloudReviewTheme, themeCategory: CloudReviewThemeCategory)
    case dominantCategory(theme: CloudReviewTheme, category: CloudReviewThemeCategory)
}

// MARK: - Theme matching (shared normalization)

enum CloudReviewInsightThemeMatching {
    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func labelsMatch(_ lhs: String, _ rhs: String) -> Bool {
        normalize(lhs) == normalize(rhs)
    }

    static func findTheme(label: String, in themes: [CloudReviewTheme]) -> CloudReviewTheme? {
        themes.first { labelsMatch($0.label, label) }
    }
}

// MARK: - Validate typed selection against sanitized recurring lists

private enum CloudStructuredInsightResolveSteps {
    static func bucket(
        _ category: CloudReviewThemeCategory,
        gratitudes: [CloudReviewTheme],
        needs: [CloudReviewTheme],
        people: [CloudReviewTheme]
    ) -> [CloudReviewTheme] {
        switch category {
        case .gratitudes: gratitudes
        case .needs: needs
        case .people: people
        }
    }

    static func resolveRef(
        _ ref: CloudTypedThemeRef,
        gratitudes: [CloudReviewTheme],
        needs: [CloudReviewTheme],
        people: [CloudReviewTheme]
    ) throws -> CloudReviewTheme {
        let trimmed = ref.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        let list = bucket(ref.category, gratitudes: gratitudes, needs: needs, people: people)
        guard let found = CloudReviewInsightThemeMatching.findTheme(label: trimmed, in: list) else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        return found
    }

    static func cooccurrence(
        raw: CloudTypedInsightAPIResponse,
        primary: CloudReviewTheme,
        secondary: CloudReviewTheme
    ) throws -> CloudResolvedStructuredInsight {
        guard let secondRef = raw.secondaryTheme else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        return .cooccurrence(
            first: primary,
            second: secondary,
            firstCategory: raw.primaryTheme.category,
            secondCategory: secondRef.category
        )
    }

    static func contrast(
        raw: CloudTypedInsightAPIResponse,
        primary: CloudReviewTheme,
        secondary: CloudReviewTheme
    ) throws -> CloudResolvedStructuredInsight {
        guard let secondRef = raw.secondaryTheme else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        let primaryCategory = raw.primaryTheme.category
        let secondaryCategory = secondRef.category
        switch (primaryCategory, secondaryCategory) {
        case (.gratitudes, .needs):
            return .contrast(gratitude: primary, need: secondary)
        case (.needs, .gratitudes):
            return .contrast(gratitude: secondary, need: primary)
        default:
            throw CloudReviewInsightsError.failedQualityGate
        }
    }

    static func temporalShift(
        raw: CloudTypedInsightAPIResponse,
        primary: CloudReviewTheme
    ) throws -> CloudResolvedStructuredInsight {
        if raw.secondaryTheme != nil { throw CloudReviewInsightsError.failedQualityGate }
        if let days = raw.evidenceDays, days < 2 { throw CloudReviewInsightsError.failedQualityGate }
        return .temporalShift(
            theme: primary,
            category: raw.primaryTheme.category,
            evidenceDays: raw.evidenceDays
        )
    }

    static func personPairing(
        raw: CloudTypedInsightAPIResponse,
        primary: CloudReviewTheme,
        secondary: CloudReviewTheme
    ) throws -> CloudResolvedStructuredInsight {
        guard let secondRef = raw.secondaryTheme else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        guard raw.primaryTheme.category == .people else { throw CloudReviewInsightsError.failedQualityGate }
        let themeCategory = secondRef.category
        guard themeCategory == .gratitudes || themeCategory == .needs else {
            throw CloudReviewInsightsError.failedQualityGate
        }
        return .personThemePairing(person: primary, theme: secondary, themeCategory: themeCategory)
    }

    static func dominantCategory(
        raw: CloudTypedInsightAPIResponse,
        primary: CloudReviewTheme
    ) throws -> CloudResolvedStructuredInsight {
        if raw.secondaryTheme != nil { throw CloudReviewInsightsError.failedQualityGate }
        return .dominantCategory(theme: primary, category: raw.primaryTheme.category)
    }
}

enum CloudStructuredInsightResolver {
    static func resolve(
        _ raw: CloudTypedInsightAPIResponse,
        gratitudes: [CloudReviewTheme],
        needs: [CloudReviewTheme],
        people: [CloudReviewTheme]
    ) throws -> CloudResolvedStructuredInsight {
        let primary = try CloudStructuredInsightResolveSteps.resolveRef(
            raw.primaryTheme,
            gratitudes: gratitudes,
            needs: needs,
            people: people
        )
        let secondaryResolved: CloudReviewTheme?
        if let secondaryRef = raw.secondaryTheme {
            secondaryResolved = try CloudStructuredInsightResolveSteps.resolveRef(
                secondaryRef,
                gratitudes: gratitudes,
                needs: needs,
                people: people
            )
        } else {
            secondaryResolved = nil
        }

        switch raw.insightType {
        case .cooccurrence:
            guard let second = secondaryResolved else { throw CloudReviewInsightsError.failedQualityGate }
            return try CloudStructuredInsightResolveSteps.cooccurrence(raw: raw, primary: primary, secondary: second)
        case .contrast:
            guard let second = secondaryResolved else { throw CloudReviewInsightsError.failedQualityGate }
            return try CloudStructuredInsightResolveSteps.contrast(raw: raw, primary: primary, secondary: second)
        case .temporalShift:
            return try CloudStructuredInsightResolveSteps.temporalShift(raw: raw, primary: primary)
        case .personThemePairing:
            guard let second = secondaryResolved else { throw CloudReviewInsightsError.failedQualityGate }
            return try CloudStructuredInsightResolveSteps.personPairing(raw: raw, primary: primary, secondary: second)
        case .dominantCategory:
            return try CloudStructuredInsightResolveSteps.dominantCategory(raw: raw, primary: primary)
        }
    }
}

// MARK: - Deterministic copy

private struct CloudStructuredReviewStrings {
    let resurfacing: String
    let narrative: String
    let continuity: String
}

private enum CloudStructuredReviewInsightRenderParts {
    static func cooccurrence(first: CloudReviewTheme, second: CloudReviewTheme) -> CloudStructuredReviewStrings {
        CloudStructuredReviewStrings(
            resurfacing: String(
                format: String(localized: "You noted %1$@ %2$lld times and %3$@ %4$lld times this week."),
                first.label,
                Int64(first.count),
                second.label,
                Int64(second.count)
            ),
            narrative: String(
                format: String(localized: "%1$@ kept showing up alongside %2$@ in what you wrote this week."),
                first.label,
                second.label
            ),
            continuity: String(
                format: String(
                    localized: "What is one small way to support %1$@ tomorrow without dropping %2$@?"
                ),
                first.label,
                second.label
            )
        )
    }

    static func contrast(gratitude: CloudReviewTheme, need: CloudReviewTheme) -> CloudStructuredReviewStrings {
        CloudStructuredReviewStrings(
            resurfacing: String(
                format: String(
                    localized: "You often returned to %1$@ in gratitudes while naming %2$@ in needs."
                ),
                gratitude.label,
                need.label
            ),
            narrative: String(
                format: String(
                    localized: "%1$@ and %2$@ sat side by side in what you wrote—thankfulness and needs together."
                ),
                gratitude.label,
                need.label
            ),
            continuity: String(
                format: String(
                    localized: "What is one small step that could honor %1$@ while still supporting %2$@ tomorrow?"
                ),
                gratitude.label,
                need.label
            )
        )
    }

    static func temporalShift(theme: CloudReviewTheme) -> CloudStructuredReviewStrings {
        CloudStructuredReviewStrings(
            resurfacing: String(
                format: String(localized: "You wrote about %1$@ more in the second half of this week."),
                theme.label
            ),
            narrative: String(
                format: String(localized: "Toward the end of the week, %1$@ became a clearer thread in your entries."),
                theme.label
            ),
            continuity: String(
                format: String(localized: "What would help you carry %1$@ gently into next week?"),
                theme.label
            )
        )
    }

    static func personPairing(person: CloudReviewTheme, theme: CloudReviewTheme) -> CloudStructuredReviewStrings {
        CloudStructuredReviewStrings(
            resurfacing: String(
                format: String(localized: "You often wrote about %1$@ alongside %2$@."),
                person.label,
                theme.label
            ),
            narrative: String(
                format: String(localized: "%1$@ and %2$@ tended to appear together in what you captured."),
                person.label,
                theme.label
            ),
            continuity: String(
                format: String(
                    localized: "How could you connect with %1$@ in a way that also tends to %2$@ tomorrow?"
                ),
                person.label,
                theme.label
            )
        )
    }

    static func dominantCategory(
        theme: CloudReviewTheme,
        category: CloudReviewThemeCategory
    ) -> CloudStructuredReviewStrings {
        let resurfacing: String
        switch category {
        case .gratitudes:
            resurfacing = String(
                format: String(localized: "Your gratitudes most often returned to %1$@ (%2$lld mentions)."),
                theme.label,
                Int64(theme.count)
            )
        case .needs:
            resurfacing = String(
                format: String(localized: "Your needs most often returned to %1$@ (%2$lld mentions)."),
                theme.label,
                Int64(theme.count)
            )
        case .people:
            resurfacing = String(
                format: String(localized: "People in mind most often included %1$@ (%2$lld mentions)."),
                theme.label,
                Int64(theme.count)
            )
        }
        let narrative = String(
            format: String(localized: "That steady attention to %1$@ was the clearest thread this week."),
            theme.label
        )
        let continuity: String
        switch category {
        case .needs:
            continuity = String(
                format: String(localized: "What is one small step you can take to support %@ tomorrow?"),
                theme.label
            )
        case .people:
            continuity = String(
                format: String(localized: "How could you connect with %@ in a meaningful way this week?"),
                theme.label
            )
        case .gratitudes:
            continuity = String(
                format: String(localized: "How can you carry %@ into tomorrow?"),
                theme.label
            )
        }
        return CloudStructuredReviewStrings(resurfacing: resurfacing, narrative: narrative, continuity: continuity)
    }
}

enum CloudStructuredReviewInsightRenderer {
    static func makePayload(
        resolved: CloudResolvedStructuredInsight,
        recurringGratitudes: [CloudReviewTheme],
        recurringNeeds: [CloudReviewTheme],
        recurringPeople: [CloudReviewTheme]
    ) -> CloudReviewInsightsPayload {
        let strings: CloudStructuredReviewStrings
        switch resolved {
        case let .cooccurrence(first, second, _, _):
            strings = CloudStructuredReviewInsightRenderParts.cooccurrence(first: first, second: second)
        case let .contrast(gratitude, need):
            strings = CloudStructuredReviewInsightRenderParts.contrast(gratitude: gratitude, need: need)
        case let .temporalShift(theme, _, _):
            strings = CloudStructuredReviewInsightRenderParts.temporalShift(theme: theme)
        case let .personThemePairing(person, theme, _):
            strings = CloudStructuredReviewInsightRenderParts.personPairing(person: person, theme: theme)
        case let .dominantCategory(theme, category):
            strings = CloudStructuredReviewInsightRenderParts.dominantCategory(theme: theme, category: category)
        }
        return CloudReviewInsightsPayload(
            narrativeSummary: strings.narrative,
            resurfacingMessage: strings.resurfacing,
            continuityPrompt: strings.continuity,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople
        )
    }
}
