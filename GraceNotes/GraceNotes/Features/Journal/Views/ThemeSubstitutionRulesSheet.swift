import SwiftUI

// MARK: - List / add / edit

/// Where a ``ThemeSubstitutionRulesSheet`` is embedded: modal sheet (Done) vs Settings stack (back).
enum ThemeSubstitutionRulesPresentationStyle {
    case sheet
    case pushedInSettings
}

/// User rules: when a line contains a trigger phrase and NLP outputs `from`, count the theme as `to`.
struct ThemeSubstitutionRulesSheet: View {
    @ObservedObject var store: ThemeSubstitutionRulesStore
    /// Prefills the "when theme is" field when adding a rule (e.g. from a theme drilldown).
    var suggestedFromCanonical: String?
    var presentationStyle: ThemeSubstitutionRulesPresentationStyle = .sheet

    @Environment(\.dismiss) private var dismiss
    @State private var editing: ThemeSubstitutionRuleDraft?

    var body: some View {
        Group {
            switch presentationStyle {
            case .sheet:
                NavigationStack {
                    rulesContent
                }
            case .pushedInSettings:
                rulesContent
            }
        }
    }

    private var rulesContent: some View {
        List {
            Section {
                if store.allRules().isEmpty {
                    Text(String(localized: "review.themeSubstitutionRules.empty"))
                        .foregroundStyle(AppTheme.reviewTextMuted)
                } else {
                    ForEach(store.allRules()) { rule in
                        Button {
                            editing = ThemeSubstitutionRuleDraft(editing: rule)
                        } label: {
                            substitutionRuleRow(rule)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteRules)
                }
            } footer: {
                Text(footerText)
                    .font(AppTheme.warmPaperMeta)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.reviewBackground)
        .navigationTitle(String(localized: "review.themeSubstitutionRules.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if presentationStyle == .sheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.done")) {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "review.themeSubstitutionRules.addRule")) {
                    editing = ThemeSubstitutionRuleDraft.newRule(defaultFromCanonical: suggestedFromCanonical ?? "")
                }
            }
        }
        .sheet(item: $editing) { draft in
            ThemeSubstitutionRuleEditorSheet(store: store, draft: draft)
        }
    }

    private var footerText: String {
        switch presentationStyle {
        case .sheet:
            return String(localized: "review.themeSubstitutionRules.footer")
        case .pushedInSettings:
            return String(localized: "settings.advanced.themeSubstitutionRules.footer")
        }
    }

    private func substitutionRuleRow(_ rule: ThemeSubstitutionRule) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(rule.fromCanonical) → \(rule.toCanonical)")
                .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
                .foregroundStyle(AppTheme.reviewTextPrimary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(localized: "review.themeSubstitutionRules.lineContainsPrefix"))
                Text(rule.surfaceTextMustContain)
                    .font(AppTheme.warmPaperMeta.weight(.semibold))
            }
            .font(AppTheme.warmPaperMeta)
            .foregroundStyle(AppTheme.reviewTextMuted)
            if !rule.isEnabled {
                Text(String(localized: "review.themeSubstitutionRules.disabledTag"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.reviewTextMuted)
            }
        }
        .padding(.vertical, 2)
    }

    private func deleteRules(at offsets: IndexSet) {
        let rules = store.allRules()
        for offset in offsets {
            guard rules.indices.contains(offset) else { continue }
            store.deleteRule(id: rules[offset].id)
        }
    }
}

// MARK: - Editor

private struct ThemeSubstitutionRuleDraft: Identifiable {
    let id: UUID
    var existingId: UUID?
    var surfaceTextMustContain: String
    var fromCanonical: String
    var toCanonical: String
    var isEnabled: Bool

    private init(
        id: UUID,
        existingId: UUID?,
        surfaceTextMustContain: String,
        fromCanonical: String,
        toCanonical: String,
        isEnabled: Bool
    ) {
        self.id = id
        self.existingId = existingId
        self.surfaceTextMustContain = surfaceTextMustContain
        self.fromCanonical = fromCanonical
        self.toCanonical = toCanonical
        self.isEnabled = isEnabled
    }

    static func newRule(defaultFromCanonical: String) -> ThemeSubstitutionRuleDraft {
        ThemeSubstitutionRuleDraft(
            id: UUID(),
            existingId: nil,
            surfaceTextMustContain: "",
            fromCanonical: defaultFromCanonical,
            toCanonical: "",
            isEnabled: true
        )
    }

    init(editing rule: ThemeSubstitutionRule) {
        id = rule.id
        existingId = rule.id
        surfaceTextMustContain = rule.surfaceTextMustContain
        fromCanonical = rule.fromCanonical
        toCanonical = rule.toCanonical
        isEnabled = rule.isEnabled
    }
}

private struct ThemeSubstitutionRuleEditorSheet: View {
    @ObservedObject var store: ThemeSubstitutionRulesStore
    @State private var draft: ThemeSubstitutionRuleDraft
    @Environment(\.dismiss) private var dismiss

    init(store: ThemeSubstitutionRulesStore, draft: ThemeSubstitutionRuleDraft) {
        self.store = store
        _draft = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(
                        String(localized: "review.themeSubstitutionRules.fieldTrigger"),
                        text: $draft.surfaceTextMustContain
                    )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(
                        String(localized: "review.themeSubstitutionRules.fieldFrom"),
                        text: $draft.fromCanonical
                    )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField(
                        String(localized: "review.themeSubstitutionRules.fieldTo"),
                        text: $draft.toCanonical
                    )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Toggle(String(localized: "review.themeSubstitutionRules.enabledToggle"), isOn: $draft.isEnabled)
                } footer: {
                    Text(String(localized: "review.themeSubstitutionRules.editorFooter"))
                        .font(AppTheme.warmPaperMeta)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.reviewBackground)
            .navigationTitle(
                draft.existingId == nil
                    ? String(localized: "review.themeSubstitutionRules.newTitle")
                    : String(localized: "review.themeSubstitutionRules.editTitle")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "review.themeSubstitutionRules.saveButton")) {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        let trigger = draft.surfaceTextMustContain.trimmingCharacters(in: .whitespacesAndNewlines)
        let from = draft.fromCanonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let toCanon = draft.toCanonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !trigger.isEmpty && !from.isEmpty && !toCanon.isEmpty
    }

    private func save() {
        let id = draft.existingId ?? draft.id
        let rule = ThemeSubstitutionRule(
            id: id,
            isEnabled: draft.isEnabled,
            surfaceTextMustContain: draft.surfaceTextMustContain.trimmingCharacters(in: .whitespacesAndNewlines),
            fromCanonical: draft.fromCanonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            toCanonical: draft.toCanonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
        store.upsert(rule)
        dismiss()
    }
}
