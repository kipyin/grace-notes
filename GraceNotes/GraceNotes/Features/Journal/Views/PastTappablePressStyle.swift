import SwiftUI
import UIKit

/// Scale, opacity, and haptic feedback for tappable controls on Past and related drilldowns / theme flows.
struct PastTappablePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.86 : 1.0)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.16), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { wasPressed, isPressed in
                guard isPressed, !wasPressed, !reduceMotion else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
    }
}

// MARK: - Toolbar Done (review / journal sheets)

enum PastToolbarDoneAppearance {
    /// Past drilldowns, theme details, and browse on ``AppTheme/reviewBackground``.
    case review
    /// Journal presented from Past (e.g. day sheet) on ``JournalScreen`` chrome.
    case journal
}

/// Visual symbol for toolbar dismiss controls; accessibility keeps the localized “Done” label.
enum PastToolbarDoneSymbol: String {
    case checkmark
    case xmark
}

/// ``Done`` in navigation bars for Past-related sheets: Warm Paper + semantic tint; light press fade and haptic.
struct PastToolbarDoneButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1.0)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.14), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { wasPressed, isPressed in
                guard isPressed, !wasPressed, !reduceMotion else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
    }
}

struct PastToolbarDoneButton: View {
    let action: () -> Void
    var appearance: PastToolbarDoneAppearance = .review
    var symbol: PastToolbarDoneSymbol = .checkmark
    var accessibilityIdentifier: String?

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol.rawValue)
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(foreground)
        }
        .buttonStyle(PastToolbarDoneButtonStyle())
        .accessibilityLabel(String(localized: "Done"))
        .optionalToolbarDoneAccessibilityIdentifier(accessibilityIdentifier)
    }

    private var foreground: Color {
        switch appearance {
        case .review:
            AppTheme.reviewAccent
        case .journal:
            AppTheme.journalTextPrimary
        }
    }
}

private extension View {
    @ViewBuilder
    func optionalToolbarDoneAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}
