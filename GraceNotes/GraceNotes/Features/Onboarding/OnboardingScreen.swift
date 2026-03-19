import SwiftUI

struct OnboardingScreen: View {
    let onGetStarted: () -> Void
    @State private var selectedPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: String(localized: "Start with one line"),
            message: String(
                localized: "Capture one gratitude and move on with your day. A meaningful check-in can take under two minutes."
            )
        ),
        OnboardingPage(
            title: String(localized: "Use prompts when your mind is blank"),
            message: String(
                localized: """
                Gentle sections for gratitude, needs, and people-in-mind help you begin without overthinking.
                """
            )
        ),
        OnboardingPage(
            title: String(localized: "Revisit when you are ready"),
            message: String(
                localized: """
                Your Review tab helps you spot themes later. Today, focus on one honest moment and call it complete.
                """
            )
        )
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "Welcome to Grace Notes"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 24)

            HStack(spacing: 12) {
                Text("Step \(selectedPage + 1) of \(pages.count)")
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.textMuted)

                Spacer()

                Button(String(localized: "Skip for now"), action: onGetStarted)
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.accentText)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            TabView(selection: $selectedPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageCard(page: page)
                        .padding(.horizontal, 20)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(action: handlePrimaryAction) {
                Text(selectedPage == pages.count - 1
                    ? String(localized: "Get Started")
                    : String(localized: "Continue"))
                    .font(AppTheme.warmPaperBody.weight(.semibold))
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(WarmPaperPressStyle())
            .padding(.horizontal, 20)

            .padding(.bottom, 24)
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func handlePrimaryAction() {
        if selectedPage < pages.count - 1 {
            withAnimation(.easeInOut) {
                selectedPage += 1
            }
            return
        }
        onGetStarted()
    }
}

private struct OnboardingPageCard: View {
    let page: OnboardingPage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(page.title)
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            Text(page.message)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct OnboardingPage {
    let title: String
    let message: String
}
