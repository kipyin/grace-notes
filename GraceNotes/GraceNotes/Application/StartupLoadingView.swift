import SwiftUI

struct StartupLoadingView: View {
    enum State {
        case loading(message: String, isReassurance: Bool)
        case retryableFailure(message: String)
    }

    let state: State
    let isRetrying: Bool
    let onRetry: () -> Void

    init(
        state: State,
        isRetrying: Bool,
        onRetry: @escaping () -> Void
    ) {
        self.state = state
        self.isRetrying = isRetrying
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .progressViewStyle(.circular)
                .opacity(isFailure ? 0 : 1)
                .accessibilityHidden(isFailure)

            Text(primaryMessage)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("StartupMessage")

            if case .loading(_, let isReassurance) = state, isReassurance {
                Text("Thanks for hanging in with us.")
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .accessibilityIdentifier("StartupReassuranceMessage")
            }

            if case .retryableFailure = state {
                Button {
                    onRetry()
                } label: {
                    if isRetrying {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Retry")
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 24)
                .disabled(isRetrying)
                .accessibilityIdentifier("StartupRetryButton")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
    }

    private var primaryMessage: String {
        switch state {
        case .loading(let message, _):
            return message
        case .retryableFailure(let message):
            return message
        }
    }

    private var isFailure: Bool {
        if case .retryableFailure = state {
            return true
        }
        return false
    }
}
