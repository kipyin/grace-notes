import SwiftUI

extension JournalOnboardingSectionState {
    var showsGuidedChrome: Bool {
        self != .standard
    }

    var isLocked: Bool {
        if case .locked = self {
            return true
        }
        return false
    }

    var guidanceNote: String? {
        if case .locked(let reason) = self {
            return reason
        }
        return nil
    }

    var titleColor: Color {
        switch self {
        case .standard, .available:
            return AppTheme.journalTextPrimary
        case .active:
            return AppTheme.accentText
        case .locked:
            return AppTheme.journalTextMuted
        }
    }

    var containerBackground: Color {
        switch self {
        case .standard:
            return .clear
        case .active:
            return AppTheme.journalPaper.opacity(0.9)
        case .available:
            return AppTheme.journalPaper.opacity(0.58)
        case .locked:
            return AppTheme.journalPaper.opacity(0.42)
        }
    }

    var containerBorder: Color {
        switch self {
        case .standard:
            return .clear
        case .active:
            return AppTheme.journalInputBorder
        case .available:
            return AppTheme.journalBorder
        case .locked:
            return AppTheme.journalBorder.opacity(0.72)
        }
    }

    func contentOpacity(isTransitioning: Bool = false) -> Double {
        switch self {
        case .standard:
            return isTransitioning ? 0.78 : 1
        case .active:
            return isTransitioning ? 0.82 : 1
        case .available:
            return isTransitioning ? 0.76 : 0.94
        case .locked:
            return isTransitioning ? 0.64 : 0.7
        }
    }
}

struct JournalOnboardingSectionModifier: ViewModifier {
    let state: JournalOnboardingSectionState
    let isTransitioning: Bool

    func body(content: Content) -> some View {
        content
            .padding(state.showsGuidedChrome ? AppTheme.spacingRegular : 0)
            .background {
                if state.showsGuidedChrome {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .fill(state.containerBackground)
                }
            }
            .overlay {
                if state.showsGuidedChrome {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(state.containerBorder, lineWidth: 1)
                }
            }
            .opacity(state.contentOpacity(isTransitioning: isTransitioning))
    }
}

extension View {
    func journalOnboardingSectionStyle(
        _ state: JournalOnboardingSectionState,
        isTransitioning: Bool = false
    ) -> some View {
        modifier(JournalOnboardingSectionModifier(state: state, isTransitioning: isTransitioning))
    }
}
