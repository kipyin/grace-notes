import SwiftUI

struct OnboardingScreen: View {
    let onGetStarted: () -> Void
    @State private var selectedPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "A calm daily rhythm",
            message: "Grace Notes helps you reflect with gentle structure: gratitude, needs, and people in mind."
        ),
        OnboardingPage(
            title: "Review that gives insight",
            message: "Your Review tab turns past entries into recurring themes, resurfacing ideas, "
                + "and continuity prompts."
        ),
        OnboardingPage(
            title: "Progress over perfection",
            message: "Low-energy days still count. Start small and build toward fuller reflection sessions over time."
        )
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Grace Notes")
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.top, 24)

            TabView(selection: $selectedPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageCard(page: page)
                        .padding(.horizontal, 20)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(action: handlePrimaryAction) {
                Text(selectedPage == pages.count - 1 ? "Get Started" : "Continue")
                    .font(AppTheme.warmPaperBody.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
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
