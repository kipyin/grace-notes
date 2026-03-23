import SwiftUI

extension PostSeedJourneyView {
    var pageIndicatorRow: some View {
        HStack(spacing: 6) {
            ForEach(0 ... lastPageIndex, id: \.self) { index in
                Circle()
                    .fill(index == pageIndex ? AppTheme.accent : AppTheme.textMuted.opacity(0.35))
                    .frame(width: index == pageIndex ? 8 : 6, height: index == pageIndex ? 8 : 6)
                    .overlay(
                        Circle()
                            .stroke(
                                index == pageIndex ? AppTheme.accentText.opacity(0.35) : AppTheme.journalInputBorder,
                                lineWidth: 1
                            )
                    )
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: String(localized: "PostSeedJourney.pageIndicator"),
                locale: .current,
                pageIndex + 1,
                lastPageIndex + 1
            )
        )
    }

    var bottomChrome: some View {
        Group {
            if pageIndex >= lastPageIndex {
                Button(action: finishJourney) {
                    Text(String(localized: "Done"))
                        .font(AppTheme.warmPaperBody.weight(.semibold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.spacingRegular)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
                }
                .buttonStyle(WarmPaperPressStyle())
            } else {
                HStack(alignment: .center, spacing: AppTheme.spacingRegular) {
                    Button(String(localized: "Skip")) {
                        finishJourney()
                    }
                    .font(AppTheme.warmPaperBody.weight(.medium))
                    .foregroundStyle(AppTheme.textMuted)

                    Spacer(minLength: 0)

                    Button(
                        action: { pageIndex = min(pageIndex + 1, lastPageIndex) },
                        label: {
                            Text(String(localized: "Next"))
                                .font(AppTheme.warmPaperBody.weight(.semibold))
                                .foregroundStyle(AppTheme.onAccent)
                                .padding(.horizontal, AppTheme.spacingWide)
                                .padding(.vertical, AppTheme.spacingRegular)
                                .background(AppTheme.accent)
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
                Image(systemName: "leaf.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)

                Text(String(localized: "PostSeedJourney.congrats.headline"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .scaleEffect(congratsAnimatedIn ? 1 : 0.97, anchor: .leading)
            .opacity(congratsAnimatedIn ? 1 : (accessibilityReduceMotion ? 1 : 0.88))
            .onAppear {
                runCongratsIntroIfNeeded()
            }

            Text(
                String(
                    localized: "PostSeedJourney.congrats.body"
                )
            )
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.textMuted)
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
            Text(String(localized: "Your path"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            Text(
                String(
                    localized: "PostSeedJourney.path.intro"
                )
            )
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)

            PostSeedJourneyPathStrip(highlightedLevel: .seed)
        }
    }

    var insightsPage: some View {
        journeyPage {
            Text(String(localized: "Depth and insights"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            Text(
                String(
                    localized: "PostSeedJourney.insights.intro"
                )
            )
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)

            PostSeedJourneyInsightsPreview()
        }
    }

    var remindersPage: some View {
        journeyPage {
            Text(String(localized: "Gentle reminders"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            Text(String(localized: "PostSeedJourney.reminders.intro"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textMuted)
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

            Text(String(localized: "PostSeedJourney.footer.settingsNote"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var aiPage: some View {
        journeyPage {
            Text(String(localized: "AI support"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            Text(String(localized: "PostSeedJourney.ai.intro"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            journeySettingsCard {
                aiConnectionControlRow
            }

            Text(String(localized: "PostSeedJourney.footer.settingsNote"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var iCloudPage: some View {
        journeyPage {
            Text(String(localized: "Keep entries with you"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)

            Text(String(localized: "PostSeedJourney.icloud.intro"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            PostSeedJourneyICloudCard(
                isICloudSyncEnabled: $isICloudSyncEnabled,
                iCloudAccountState: iCloudAccountState,
                persistenceRuntimeSnapshot: persistenceRuntimeSnapshot,
                openSystemSettings: openSystemSettings
            )

            Text(String(localized: "PostSeedJourney.footer.settingsNote"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.textMuted)
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
