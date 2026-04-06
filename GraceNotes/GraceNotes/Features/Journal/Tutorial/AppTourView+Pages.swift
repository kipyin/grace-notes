import SwiftUI

extension AppTourView {
    var pageIndicatorRow: some View {
        HStack(spacing: 6) {
            ForEach(firstPageIndex ... lastPageIndex, id: \.self) { index in
                Circle()
                    .fill(index == pageIndex ? AppTheme.reviewAccent : AppTheme.settingsTextMuted.opacity(0.35))
                    .frame(width: index == pageIndex ? 8 : 6, height: index == pageIndex ? 8 : 6)
                    .overlay(
                        Circle()
                            .stroke(
                                index == pageIndex ? AppTheme.reviewAccent.opacity(0.45) : AppTheme.border.opacity(0.5),
                                lineWidth: 1
                            )
                    )
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: String(localized: "tutorial.appTour.pageIndicator"),
                locale: .current,
                pageIndex - firstPageIndex + 1,
                lastPageIndex - firstPageIndex + 1
            )
        )
    }

    var bottomChrome: some View {
        Group {
            if pageIndex >= lastPageIndex {
                Button(action: finishJourney) {
                    Text(String(localized: "common.done"))
                        .font(AppTheme.warmPaperBody.weight(.semibold))
                        .foregroundStyle(AppTheme.reminderPrimaryActionForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.spacingRegular)
                        .background(AppTheme.reminderPrimaryActionBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                }
                .buttonStyle(WarmPaperPressStyle())
            } else {
                HStack(alignment: .center, spacing: AppTheme.spacingRegular) {
                    Button(String(localized: "common.skip")) {
                        finishJourney()
                    }
                    .font(AppTheme.warmPaperBody.weight(.medium))
                    .foregroundStyle(AppTheme.settingsTextMuted)

                    Spacer(minLength: 0)

                    Button(
                        action: { pageIndex = min(pageIndex + 1, lastPageIndex) },
                        label: {
                            Text(String(localized: "common.next"))
                                .font(AppTheme.warmPaperBody.weight(.semibold))
                                .foregroundStyle(AppTheme.reminderPrimaryActionForeground)
                                .padding(.horizontal, AppTheme.spacingWide)
                                .padding(.vertical, AppTheme.spacingRegular)
                                .background(AppTheme.reminderPrimaryActionBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                        }
                    )
                    .buttonStyle(WarmPaperPressStyle())
                }
            }
        }
    }

    func finishJourney() {
        onFinish()
    }

    // MARK: - Pages

    var congratulationsPage: some View {
        journeyPage {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacingRegular) {
                Text(String(localized: "tutorial.appTour.congrats.headline"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .scaleEffect(congratsAnimatedIn ? 1 : 0.97, anchor: .leading)
            .opacity(congratsAnimatedIn ? 1 : (accessibilityReduceMotion ? 1 : 0.88))
            .onAppear {
                runCongratsIntroIfNeeded()
            }

            Text(
                String(
                    localized: "tutorial.appTour.congrats.body"
                )
            )
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.settingsTextMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    func runCongratsIntroIfNeeded() {
        guard !congratsAnimatedIn else { return }
        if accessibilityReduceMotion {
            congratsAnimatedIn = true
            return
        }
        withAnimation(.easeOut(duration: 0.25)) {
            congratsAnimatedIn = true
        }
    }

    var pathPage: some View {
        journeyPage {
            Text(String(localized: "tutorial.path.sectionTitle"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.settingsTextPrimary)

            Text(
                String(
                    localized: "tutorial.appTour.path.intro"
                )
            )
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.settingsTextMuted)
            .fixedSize(horizontal: false, vertical: true)

            AppTourPathStrip(highlightedLevel: .sprout)
        }
    }

    var insightsPage: some View {
        journeyPage {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                Text(String(localized: "tutorial.insights.sectionTitle"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.settingsTextPrimary)

                Text(
                    String(
                        localized: "tutorial.appTour.insights.intro"
                    )
                )
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            }

            AppTourInsightsPreview()
                .padding(.top, AppTheme.spacingWide)

            Text(String(localized: "tutorial.appTour.sampleInsights.filler"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppTheme.spacingTight)
        }
    }

    var remindersPage: some View {
        journeyPage {
            Text(String(localized: "tutorial.reminders.sectionTitle"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.settingsTextPrimary)

            Text(String(localized: "tutorial.appTour.reminders.intro"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextMuted)
                .fixedSize(horizontal: false, vertical: true)

            journeySettingsCard {
                VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
                    reminderTimeControlRow

                    if reminderState.isReminderEnabled && isReminderPickerExpanded {
                        reminderTimePicker
                    }
                    if reminderState.isPermissionDenied {
                        reminderPermissionDeniedGuidance
                    } else if reminderState.liveStatus == .unavailable {
                        reminderUnavailableGuidance
                    }
                }
            }

            Text(String(localized: "tutorial.appTour.footer.settingsNote"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var iCloudPage: some View {
        journeyPage {
            Text(String(localized: "tutorial.icloud.headline"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.settingsTextPrimary)

            Text(String(localized: "tutorial.appTour.icloud.intro"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextMuted)
                .fixedSize(horizontal: false, vertical: true)

            AppTourICloudCard(
                isICloudSyncEnabled: $isICloudSyncEnabled,
                iCloudAccountState: iCloudAccountState,
                persistenceRuntimeSnapshot: persistenceRuntimeSnapshot,
                openSystemSettings: openSystemSettings
            )

            Text(String(localized: "tutorial.appTour.footer.settingsNote"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func journeyPage(@ViewBuilder content: () -> some View) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.spacingSection) {
                Spacer(minLength: AppTheme.spacingWide)
                content()
                Spacer(minLength: AppTheme.spacingWide)
            }
            .padding(.horizontal, AppTheme.spacingWide)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    func journeySettingsCard(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(AppTheme.spacingWide)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.settingsPaper)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.journalInputBorder, lineWidth: 1)
            )
    }
}
