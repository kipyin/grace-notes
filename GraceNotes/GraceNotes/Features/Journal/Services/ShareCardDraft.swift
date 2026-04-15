import Foundation
import UIKit

/// Stable identity for a tappable line when refining what appears on the share image.
enum ShareLineIdentity: Hashable, Sendable {
    case gratitude(Int)
    case need(Int)
    case person(Int)
    case readingLine(Int)
    case reflectionLine(Int)
}

/// Journal section corresponding to share visibility toggles.
enum ShareSectionKind: Hashable, Sendable {
    case gratitudes
    case needs
    case people
    case readingNotes
    case reflections
}

/// User-editable share state: card style, whole-section visibility, and per-line redaction.
struct ShareCardDraft: Equatable, Sendable {
    var style: ShareCardStyle
    var showGratitudes: Bool
    var showNeeds: Bool
    var showPeople: Bool
    var showReadingNotes: Bool
    var showReflections: Bool

    var showWatermark: Bool
    var showCompletionBadge: Bool
    /// When `true`, the share image uses the dark card palette; when `false`, the classic light card.
    /// Default follows app appearance when the composer opens (Bloom is always treated as light).
    var shareCardUsesDarkTheme: Bool

    var redactedGratitudeIndices: Set<Int>
    var redactedNeedIndices: Set<Int>
    var redactedPersonIndices: Set<Int>
    var redactedReadingLineIndices: Set<Int>
    var redactedReflectionLineIndices: Set<Int>

    static func initial(from payload: JournalExportPayload) -> ShareCardDraft {
        ShareCardDraft(
            style: .paperWarm,
            showGratitudes: !payload.gratitudes.isEmpty,
            showNeeds: !payload.needs.isEmpty,
            showPeople: !payload.people.isEmpty,
            showReadingNotes: !payload.readingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            showReflections: !payload.reflections.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            showWatermark: true,
            showCompletionBadge: false,
            shareCardUsesDarkTheme: Self.defaultShareCardUsesDarkThemeForCurrentAppAppearance(),
            redactedGratitudeIndices: [],
            redactedNeedIndices: [],
            redactedPersonIndices: [],
            redactedReadingLineIndices: [],
            redactedReflectionLineIndices: []
        )
    }

    /// Bloom forces light app chrome; otherwise use the system interface style (matches share composer sheet).
    /// `UITraitCollection.current` is main-thread-only; off the main thread we default to the light card.
    private static func defaultShareCardUsesDarkThemeForCurrentAppAppearance() -> Bool {
        let raw = UserDefaults.standard.string(forKey: JournalAppearanceStorageKeys.todayMode)
            ?? JournalAppearanceMode.standard.rawValue
        if JournalAppearanceMode.resolveStored(rawValue: raw) == .bloom {
            return false
        }
        guard Thread.isMainThread else {
            return false
        }
        return UITraitCollection.current.userInterfaceStyle == .dark
    }

    mutating func setGratitudesIncluded(_ included: Bool) {
        showGratitudes = included
        if !included { redactedGratitudeIndices = [] }
    }

    mutating func setNeedsIncluded(_ included: Bool) {
        showNeeds = included
        if !included { redactedNeedIndices = [] }
    }

    mutating func setPeopleIncluded(_ included: Bool) {
        showPeople = included
        if !included { redactedPersonIndices = [] }
    }

    mutating func setReadingNotesIncluded(_ included: Bool) {
        showReadingNotes = included
        if !included { redactedReadingLineIndices = [] }
    }

    mutating func setReflectionsIncluded(_ included: Bool) {
        showReflections = included
        if !included { redactedReflectionLineIndices = [] }
    }

    mutating func toggleSectionVisibility(_ kind: ShareSectionKind) {
        switch kind {
        case .gratitudes: setGratitudesIncluded(!showGratitudes)
        case .needs: setNeedsIncluded(!showNeeds)
        case .people: setPeopleIncluded(!showPeople)
        case .readingNotes: setReadingNotesIncluded(!showReadingNotes)
        case .reflections: setReflectionsIncluded(!showReflections)
        }
    }

    mutating func toggleRedaction(for identity: ShareLineIdentity) {
        switch identity {
        case .gratitude(let index):
            redactedGratitudeIndices.toggleMembership(index)
        case .need(let index):
            redactedNeedIndices.toggleMembership(index)
        case .person(let index):
            redactedPersonIndices.toggleMembership(index)
        case .readingLine(let index):
            redactedReadingLineIndices.toggleMembership(index)
        case .reflectionLine(let index):
            redactedReflectionLineIndices.toggleMembership(index)
        }
    }
}

// MARK: - Set helpers

private extension Set where Element == Int {
    mutating func toggleMembership(_ index: Int) {
        if contains(index) {
            remove(index)
        } else {
            insert(index)
        }
    }
}

// MARK: - Render model

enum ShareLineDisplayItem: Equatable, Sendable {
    case visible(displayText: String, identity: ShareLineIdentity)
    case redacted(identity: ShareLineIdentity)
    case previewStub(message: String)
}

struct ShareSectionRenderModel: Equatable, Sendable {
    let kind: ShareSectionKind
    let title: String
    let isPreviewStub: Bool
    let lines: [ShareLineDisplayItem]
}

struct ShareRenderPayload: Equatable, Sendable {
    let style: ShareCardStyle
    let typographyScript: ShareTypographyScript
    let dateFormatted: String
    let completionLevel: JournalCompletionLevel
    let showWatermark: Bool
    let showCompletionBadge: Bool
    let shareCardUsesDarkTheme: Bool
    let sections: [ShareSectionRenderModel]
}

enum ShareRenderPayloadBuilder {
    static func proseLines(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return [] }
        let parts = trimmed.split(whereSeparator: \.isNewline).map(String.init)
        let nonEmpty = parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return nonEmpty.isEmpty ? [trimmed] : nonEmpty
    }

    static func build(
        full payload: JournalExportPayload,
        draft: ShareCardDraft,
        includePreviewStubs: Bool
    ) -> ShareRenderPayload {
        var sections: [ShareSectionRenderModel] = []
        gratitudesSection(payload: payload, draft: draft, includePreviewStubs: includePreviewStubs, sections: &sections)
        needsSection(payload: payload, draft: draft, includePreviewStubs: includePreviewStubs, sections: &sections)
        peopleSection(payload: payload, draft: draft, includePreviewStubs: includePreviewStubs, sections: &sections)
        readingSection(payload: payload, draft: draft, includePreviewStubs: includePreviewStubs, sections: &sections)
        reflectionsSection(
            payload: payload,
            draft: draft,
            includePreviewStubs: includePreviewStubs,
            sections: &sections
        )
        return ShareRenderPayload(
            style: draft.style,
            typographyScript: ShareTypographyScript.current(bundle: .main),
            dateFormatted: payload.dateFormatted,
            completionLevel: payload.completionLevel,
            showWatermark: draft.showWatermark,
            showCompletionBadge: draft.showCompletionBadge,
            shareCardUsesDarkTheme: draft.shareCardUsesDarkTheme,
            sections: sections
        )
    }

    private static func gratitudesSection(
        payload: JournalExportPayload,
        draft: ShareCardDraft,
        includePreviewStubs: Bool,
        sections: inout [ShareSectionRenderModel]
    ) {
        guard !payload.gratitudes.isEmpty else { return }
        let title = String(localized: "journal.section.gratitudesTitle")
        if draft.showGratitudes {
            let lines = listItems(
                strings: payload.gratitudes,
                redacted: draft.redactedGratitudeIndices,
                identity: { .gratitude($0) }
            )
            sections.append(ShareSectionRenderModel(
                kind: .gratitudes,
                title: title,
                isPreviewStub: false,
                lines: lines
            ))
        } else if includePreviewStubs {
            sections.append(ShareSectionRenderModel(
                kind: .gratitudes,
                title: title,
                isPreviewStub: true,
                lines: [.previewStub(message: String(localized: "sharing.stub.excluded"))]
            ))
        }
    }

    private static func needsSection(
        payload: JournalExportPayload,
        draft: ShareCardDraft,
        includePreviewStubs: Bool,
        sections: inout [ShareSectionRenderModel]
    ) {
        guard !payload.needs.isEmpty else { return }
        let title = String(localized: "journal.section.needsTitle")
        if draft.showNeeds {
            let lines = listItems(
                strings: payload.needs,
                redacted: draft.redactedNeedIndices,
                identity: { .need($0) }
            )
            sections.append(ShareSectionRenderModel(
                kind: .needs,
                title: title,
                isPreviewStub: false,
                lines: lines
            ))
        } else if includePreviewStubs {
            sections.append(ShareSectionRenderModel(
                kind: .needs,
                title: title,
                isPreviewStub: true,
                lines: [.previewStub(message: String(localized: "sharing.stub.excluded"))]
            ))
        }
    }

    private static func peopleSection(
        payload: JournalExportPayload,
        draft: ShareCardDraft,
        includePreviewStubs: Bool,
        sections: inout [ShareSectionRenderModel]
    ) {
        guard !payload.people.isEmpty else { return }
        let title = String(localized: "journal.section.peopleTitle")
        if draft.showPeople {
            let lines = listItems(
                strings: payload.people,
                redacted: draft.redactedPersonIndices,
                identity: { .person($0) }
            )
            sections.append(ShareSectionRenderModel(
                kind: .people,
                title: title,
                isPreviewStub: false,
                lines: lines
            ))
        } else if includePreviewStubs {
            sections.append(ShareSectionRenderModel(
                kind: .people,
                title: title,
                isPreviewStub: true,
                lines: [.previewStub(message: String(localized: "sharing.stub.excluded"))]
            ))
        }
    }

    private static func readingSection(
        payload: JournalExportPayload,
        draft: ShareCardDraft,
        includePreviewStubs: Bool,
        sections: inout [ShareSectionRenderModel]
    ) {
        guard !payload.readingNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let title = String(localized: "journal.section.readingNotesTitle")
        if draft.showReadingNotes {
            let lines = proseItems(
                text: payload.readingNotes,
                redacted: draft.redactedReadingLineIndices,
                identity: { .readingLine($0) }
            )
            guard !lines.isEmpty else { return }
            sections.append(ShareSectionRenderModel(
                kind: .readingNotes,
                title: title,
                isPreviewStub: false,
                lines: lines
            ))
        } else if includePreviewStubs {
            sections.append(ShareSectionRenderModel(
                kind: .readingNotes,
                title: title,
                isPreviewStub: true,
                lines: [.previewStub(message: String(localized: "sharing.stub.excluded"))]
            ))
        }
    }

    private static func reflectionsSection(
        payload: JournalExportPayload,
        draft: ShareCardDraft,
        includePreviewStubs: Bool,
        sections: inout [ShareSectionRenderModel]
    ) {
        guard !payload.reflections.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let title = String(localized: "journal.section.reflectionsTitle")
        if draft.showReflections {
            let lines = proseItems(
                text: payload.reflections,
                redacted: draft.redactedReflectionLineIndices,
                identity: { .reflectionLine($0) }
            )
            guard !lines.isEmpty else { return }
            sections.append(ShareSectionRenderModel(
                kind: .reflections,
                title: title,
                isPreviewStub: false,
                lines: lines
            ))
        } else if includePreviewStubs {
            sections.append(ShareSectionRenderModel(
                kind: .reflections,
                title: title,
                isPreviewStub: true,
                lines: [.previewStub(message: String(localized: "sharing.stub.excluded"))]
            ))
        }
    }

    private static func listItems(
        strings: [String],
        redacted: Set<Int>,
        identity: (Int) -> ShareLineIdentity
    ) -> [ShareLineDisplayItem] {
        strings.enumerated().map { index, raw in
            if redacted.contains(index) {
                .redacted(identity: identity(index))
            } else {
                .visible(
                    displayText: raw,
                    identity: identity(index)
                )
            }
        }
    }

    private static func proseItems(
        text: String,
        redacted: Set<Int>,
        identity: (Int) -> ShareLineIdentity
    ) -> [ShareLineDisplayItem] {
        let lines = proseLines(text)
        return lines.enumerated().map { index, raw in
            if redacted.contains(index) {
                .redacted(identity: identity(index))
            } else {
                .visible(
                    displayText: raw,
                    identity: identity(index)
                )
            }
        }
    }
}
