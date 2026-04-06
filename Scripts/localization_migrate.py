#!/usr/bin/env python3
"""
One-off helper to rename Localizable.xcstrings keys and update Swift sources.
Run from repo root: python3 Scripts/localization_migrate.py
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "GraceNotes/GraceNotes/Localizable.xcstrings"
SWIFT_ROOTS = [ROOT / "GraceNotes", ROOT / "GraceNotesTests"]

# Longer prefixes first
PREFIX_TO_SEMANTIC = [
    ("DataPrivacy.", "settings.dataPrivacy."),
    ("PastStatisticsInterval.", "settings.pastStatisticsInterval."),
    ("PastDrilldown.", "past.drilldown."),
    ("PastSearch.", "past.search."),
    ("ThemeDrilldown.", "review.themeDrilldown."),
    ("AppTour.", "tutorial.appTour."),
    ("Settings.", "settings."),
    ("Review.", "review."),
]

# Keys that are already English sentences or format strings — map explicitly
PLAIN_TO_SEMANTIC: dict[str, str] = {}

# Populated below — split for readability


def semantic_from_prefixed(old: str) -> str | None:
    for prefix, replacement in PREFIX_TO_SEMANTIC:
        if old.startswith(prefix):
            return replacement + old[len(prefix) :]
    return None


def load_plain_map() -> dict[str, str]:
    m = dict(PLAIN_TO_SEMANTIC)
    # Merge inline blocks
    for block in _PLAIN_BLOCKS:
        m.update(block)
    return m


# --- Plain-string semantic keys (199 entries) ---

_PLAIN_BLOCKS: list[dict[str, str]] = []


def _add_block(d: dict[str, str]) -> None:
    _PLAIN_BLOCKS.append(d)


_add_block(
    {
        # Format / template strings
        "%1$@ item %2$d of %3$d": "accessibility.list.itemPosition",
        "%1$@ progress. %2$d complete, %3$d in progress, %4$d open.": "journal.section.progressSummary",
        "%1$@, %2$@, %3$lld": "journal.share.lineCountsThree",
        "%1$@, %2$@, %3$lld, %4$lld": "journal.share.lineCountsFour",
        "%1$@, %2$d": "journal.share.twoColumnRow",
        "%1$@. Gratitudes %2$d, Needs %3$d, People in Mind %4$d.": "journal.share.sectionCountsSentence",
        "%1$lld → %2$lld": "review.history.weekComparisonArrow",
        "%@ editor": "accessibility.multilineEditorLabel",
        "%@ input": "accessibility.sectionInputLabel",
        "%@ section is updating.": "accessibility.sectionUpdating",
        "%@ text": "accessibility.sectionTextLabel",
        "%d of %d": "journal.completion.countOfTotal",
        "%lld. %@": "sharing.numberedLine",
        # Short UI
        "A next step": "review.prompts.nextStep",
        "Add another gratitude": "journal.actions.addAnotherGratitude",
        "Add another need": "journal.actions.addAnotherNeed",
        "Add another person": "journal.actions.addAnotherPerson",
        "Add gratitude": "journal.actions.addGratitude",
        "Add need": "journal.actions.addNeed",
        "Add person": "journal.actions.addPerson",
        "Add one line in each section to move into Sprout.": "journal.guidance.moveToSprout",
        "Add one more line in any section. Small steps are easier to keep. Tap the status above anytime if you want a reminder.": "journal.guidance.addOneMoreLineAnySection",
        "All sections are at three lines. Reach five lines in each section to enter Bloom.": "journal.guidance.allSectionsThreeTowardBloom",
        "All sections reached five lines. Today's entry is complete.": "journal.guidance.allSectionsCompleteToday",
        "Allow notifications in Settings to confirm a reminder time.": "notifications.reminder.confirmTimeInSettings",
        "Allow notifications in Settings to enable daily reminders.": "notifications.reminder.enableInSettings",
        "Almost ready. Bringing your Grace Notes space online...": "startup.status.almostReady",
        "At least one section has three lines. Reach three in all sections to enter Leaf.": "journal.guidance.towardLeaf",
        "Balanced": "journal.growthStage.balanced",
        "Begin today's entry": "onboarding.beginToday",
        "Bloom": "journal.growthStage.bloom",
        "Both %1$@ and %2$@ showed up more than once in your week.": "review.insights.bothThemesMultiple",
        "Browse all recurring themes": "review.actions.browseRecurringThemes",
        "Browse all trending themes": "review.actions.browseTrendingThemes",
        "Cancel": "common.cancel",
        "Check if notification permissions have changed.": "notifications.reminder.checkPermissionsHint",
        "Choose a reminder time.": "notifications.reminder.chooseTimeHint",
        "Count": "review.labels.count",
        "Current week %1$lld, previous week %2$lld.": "review.insights.weekComparisonCurrentPrevious",
        "Daily reminder": "notifications.reminder.dailyLabel",
        "Daily reminders": "tutorial.reminders.sectionTitle",
        "Data & Privacy": "settings.dataPrivacy.navTitle",
        "Delete": "common.delete",
        "Depth and insights": "tutorial.insights.sectionTitle",
        "Dismiss": "common.dismiss",
        "Dismisses this tip.": "journal.tutorial.dismissTipHint",
        "Done": "common.done",
        "Double-tap to edit this sentence.": "accessibility.doubleTapEditSentence",
        "Double-tap to edit this sentence. Use Show more to preview the full text.": "accessibility.doubleTapEditSentenceShowMore",
        "Down": "common.direction.down",
        "Editing this sentence. Press Done to save, or tap outside the text field.": "accessibility.editingSentence",
        "Empty": "journal.growthStage.empty",
        "Expands or collapses the sentence preview": "accessibility.expandCollapsePreview",
        "Exporting…": "data.exporting.progress",
        "First time with one line in each section. Nice work.": "journal.guidance.firstTimeOneLineEach",
        "Full": "journal.growthStage.full",
        "Got it": "journal.tutorial.gotIt",
        "Grace Notes": "app.name",
        "Gratitudes": "journal.section.gratitudesTitle",
        "Growing": "journal.growthStage.growing",
        "Growth stages": "review.labels.growthStages",
        "If you'd like, you can turn on a daily reminder in Settings.": "tutorial.reminders.optionalSettingsNote",
        "Importing…": "data.importing.progress",
        "Keep Grace Notes with you": "tutorial.icloud.headlineAlt",
        "Keep entries with you": "tutorial.icloud.headline",
        "Keep going": "journal.onboarding.keepGoingTitle",
        "Keep going in each section toward Leaf.": "journal.guidance.towardLeafShort",
        "Keep the rhythm close": "review.labels.keepRhythm",
        "Keep writing to see trends for this calendar week.": "review.insights.keepWritingForTrends",
        "Loading weekly insights.": "review.insights.loading",
        "Matching writing surfaces": "review.labels.matchingSurfaces",
        "Monday": "calendar.weekday.monday",
        "Most recurring": "review.labels.mostRecurring",
        "Needs": "journal.section.needsTitle",
        "Needs will open after your first gratitude.": "journal.onboarding.needsLockedReason",
        "New": "common.new",
        "Next": "common.next",
        "No entries yet": "past.empty.noEntries",
        "No journaling days to show here yet. After you write, they will appear in this strip.": "past.empty.journalingDaysStrip",
        "No writing on %@": "review.insights.noWritingOnDate",
        "Not now": "common.notNow",
        "Now add one need for today.": "journal.onboarding.addOneNeedMessage",
        "OK": "common.ok",
        "Observation": "review.labels.observation",
        "Off": "common.off",
        "Off (Denied)": "notifications.reminder.offDenied",
        "One more step": "journal.onboarding.oneMoreStepTitle",
        "Open Settings": "settings.openSettings",
        "Open iOS Settings for notification permissions.": "notifications.reminder.openIOSSettingsHint",
        "Opens Today and starts the guided first entry.": "onboarding.beginEntryAccessibilityHint",
        "Opens a text field so you can add another item.": "accessibility.addAnotherItemHint",
        "Opens iOS Settings where you can sign in to iCloud or review restrictions.": "settings.dataPrivacy.openIOSSettingsICloudHint",
        "Opens the journal entry for that day.": "past.accessibility.openEntryThatDay",
        "Opens this day to start or continue writing.": "past.accessibility.openDayToWrite",
        "Past": "shell.tab.past",
        "People in Mind": "journal.section.peopleTitle",
        "People in Mind will open after your first gratitude.": "journal.onboarding.peopleLockedAfterGratitude",
        "People in Mind will open after your first need.": "journal.onboarding.peopleLockedAfterNeed",
        "Please try again.": "common.tryAgainGeneric",
        "Preparing a calm place for your first reflection...": "startup.status.preparingCalm",
        "Reading Notes": "journal.section.readingNotesTitle",
        "Reading Notes open after Gratitudes, Needs, and People are full.": "journal.onboarding.readingNotesLockedReason",
        "Reading notes": "journal.section.readingNotesShort",
        "Reflection rhythm": "review.labels.reflectionRhythm",
        "Reflections": "journal.section.reflectionsTitle",
        "Reflections open after Gratitudes, Needs, and People are full.": "journal.onboarding.reflectionsLockedReason",
        "Refresh": "common.refresh",
        "Reminder couldn't be scheduled. Check notification permissions and try again.": "notifications.reminder.scheduleFailed",
        "Reminder time": "notifications.reminder.timeLabel",
        "Reminder time couldn't be saved. Try again in a moment.": "notifications.reminder.saveFailed",
        "Reminders": "settings.reminders.sectionTitle",
        "Retry": "common.retry",
        "Retry scheduling your daily reminder.": "notifications.reminder.retrySchedulingHint",
        "Review growth stage accessibility Balanced": "accessibility.reviewGrowthStage.balanced",
        "Review growth stage accessibility Empty": "accessibility.reviewGrowthStage.empty",
        "Review growth stage accessibility Full": "accessibility.reviewGrowthStage.full",
        "Review growth stage accessibility Growing": "accessibility.reviewGrowthStage.growing",
        "Review growth stage accessibility Started": "accessibility.reviewGrowthStage.started",
        "Review history growth column empty hint": "accessibility.reviewHistory.growthColumnEmpty",
        "Review history growth column hint": "accessibility.reviewHistory.growthColumn",
        "Review history growth drilldown calendar empty description": "review.history.growthCalendarEmptyDescription",
        "Review history growth drilldown calendar empty title": "review.history.growthCalendarEmptyTitle",
        "Review history journaling days drilldown caption": "review.history.journalingDaysCaption",
        "Review history journaling days drilldown empty description": "review.history.journalingDaysEmptyDescription",
        "Review history journaling days drilldown empty title": "review.history.journalingDaysEmptyTitle",
        "Review history rhythm chrome title a11y hint": "accessibility.reviewHistory.rhythmChromeTitle",
        "Review history section strip segment empty hint": "accessibility.reviewHistory.sectionStripEmpty",
        "Review history section strip segment hint": "accessibility.reviewHistory.sectionStrip",
        "Review section drilldown empty format": "review.sectionDrilldown.emptyFormat",
        "Review section drilldown empty title": "review.sectionDrilldown.emptyTitle",
        "Save to Photos": "sharing.saveToPhotos",
        "Saved to Photos": "sharing.savedToPhotos",
        "Search journal": "past.search.placeholder",
        "Section Distribution": "review.labels.sectionDistribution",
        "Settings": "shell.tab.settings",
        "Share": "common.share",
        "Show less": "common.showLess",
        "Show more": "common.showMore",
        "Shows what this status means for today.": "accessibility.journalStatusMeaningHint",
        "Skip": "common.skip",
        "Stable": "review.labels.stable",
        "Start with one gratitude, and the rest will follow.": "onboarding.tagline",
        "Start with one gratitude.": "journal.onboarding.startWithGratitude",
        "Start with one reflection today to build your weekly review.": "review.insights.starterReflection",
        "Start with today.": "review.insights.startWithToday",
        "Start writing this week to unlock review insights.": "review.insights.unlockPrompt",
        "Started": "journal.growthStage.started",
        "Still getting things ready...": "startup.status.stillWorking",
        "Summary": "review.labels.summary",
        "Sunday": "calendar.weekday.sunday",
        "Take a moment to complete today's entry.": "notifications.reminder.bodyCompleteEntry",
        "Thanks for your patience. We are almost there.": "startup.status.thanksPatience",
        "That thread around %@ showed up across more than one day this week.": "review.insights.threadAcrossDays",
        "Theme details": "review.labels.themeDetails",
        "Today": "shell.tab.today",
        "Trending": "review.labels.trending",
        "Try again": "common.tryAgain",
        "Unable to export data": "data.export.errorTitle",
        "Unable to export your Grace Notes data right now.": "data.export.errorDetail",
        "Unable to load today's entry.": "journal.error.loadToday",
        "Unable to save your entry.": "journal.error.saveEntry",
        "Unable to share": "sharing.error.unable",
        "Unable to update reminder": "notifications.reminder.updateFailedTitle",
        "Unavailable. Check notification permissions and try again.": "notifications.reminder.unavailablePermissions",
        "Up": "common.direction.up",
        "Updated insights appear when ready.": "review.insights.updatedWhenReady",
        "Updating…": "common.updating",
        "We are setting up your private Grace Notes space...": "startup.status.settingUp",
        "We couldn't create a share image right now. Please try again.": "sharing.error.createImage",
        "We couldn't finish setting up your Grace Notes space. Please try again.": "startup.error.setupFailed",
        "Welcome to Grace Notes": "onboarding.welcome.title",
        "What do you need today?": "journal.prompts.whatNeedToday",
        "What feels most important to carry into next week?": "review.prompts.carryIntoNextWeek",
        "What helped you stay this steady so you can carry it into next week?": "review.prompts.steadyCarry",
        "What would make tomorrow's check-in easy to start?": "review.prompts.easyCheckInTomorrow",
        "What's one thing you're glad happened, even if small?": "review.prompts.gladHappened",
        "What's one thing you're grateful for?": "journal.prompts.gratefulFor",
        "When you're finished, press Return or Enter on your keyboard.": "journal.onboarding.keyboardFinishHint",
        "When you're ready, a few lines can still hold a lot.": "journal.guidance.fewLinesHoldALot",
        "Who are you thinking of today?": "journal.prompts.whoThinking",
        "Who is on your mind today?": "journal.onboarding.whoOnMind",
        "Write one gratitude line to plant your first seed. Tap the status above anytime if you want a reminder.": "journal.tutorial.firstGratitudeSeed",
        "Write your %@ here.": "journal.editor.placeholderSection",
        "You can turn on iCloud sync in Settings whenever you're ready.": "tutorial.icloud.wheneverReady",
        "You have started. Reach three lines in each section to enter Twig.": "journal.guidance.enterTwig",
        "You kept a steady daily rhythm and completed all 15 each day this week.": "review.insights.steadyRhythm15",
        "You reached %1$@ on %2$@.": "review.insights.reachedStageOnDate",
        "You reached Bloom today. All five lines are filled in each section.": "journal.guidance.reachedBloomToday",
        "You reached Leaf today.": "journal.guidance.reachedLeafToday",
        "You reached Sprout today.": "journal.guidance.reachedSproutToday",
        "You wrote on %@": "review.insights.wroteOnDate",
        "You're ready to keep filling the rows. Reach five in each section when it feels right.": "journal.onboarding.balancedContinueMessage",
        "You've begun. Keep going until each section has three.": "journal.onboarding.startedContinueMessage",
        "Your first Bloom day. Each section has five lines. Add reading notes or reflections when you want.": "journal.guidance.firstBloomDay",
        "Your first Leaf day. Each section has at least three lines. Keep going toward Bloom.": "journal.guidance.firstLeafDay",
        "Your path": "tutorial.path.sectionTitle",
        "day": "common.timeUnit.day",
        "days": "common.timeUnit.days",
        "iCloud sync": "settings.dataPrivacy.iCloudSyncToggle",
    }
)


def build_full_map() -> dict[str, str]:
    plain = load_plain_map()
    full: dict[str, str] = {}

    def map_one(old: str) -> str:
        sem = semantic_from_prefixed(old)
        if sem is not None:
            return sem
        if old in plain:
            return plain[old]
        raise KeyError(f"No semantic mapping for key: {old!r}")

    # Keys referenced in Swift
    pat = re.compile(r'String\(localized:\s*"((?:[^"\\]|\\.)*)"')
    pat2 = re.compile(r'localized:\s*"((?:[^"\\]|\\.)*)"')
    referenced: set[str] = set()
    for root in SWIFT_ROOTS:
        for p in root.rglob("*.swift"):
            t = p.read_text(encoding="utf-8")
            for pattern in (pat, pat2):
                for m in pattern.finditer(t):
                    s = m.group(1)
                    s = bytes(s, "utf-8").decode("unicode_escape") if "\\" in s else s
                    referenced.add(s)

    for old in sorted(referenced):
        full[old] = map_one(old)
    return full


def rewrite_swift_files(mapping: dict[str, str]) -> None:
    def escape_swift_string(s: str) -> str:
        return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

    for root in SWIFT_ROOTS:
        for p in root.rglob("*.swift"):
            text = p.read_text(encoding="utf-8")
            orig = text

            def repl_string_localized(m: re.Match[str]) -> str:
                inner = m.group(1)
                raw = inner
                unescaped = (
                    bytes(inner, "utf-8").decode("unicode_escape") if "\\" in inner else inner
                )
                new_key = mapping.get(unescaped, unescaped)
                if new_key == unescaped:
                    return m.group(0)
                return f'String(localized: "{escape_swift_string(new_key)}")'

            def repl_localized_label(m: re.Match[str]) -> str:
                inner = m.group(1)
                unescaped = (
                    bytes(inner, "utf-8").decode("unicode_escape") if "\\" in inner else inner
                )
                new_key = mapping.get(unescaped, unescaped)
                if new_key == unescaped:
                    return m.group(0)
                return f'localized: "{escape_swift_string(new_key)}"'

            text = re.sub(
                r'String\(localized:\s*"((?:[^"\\]|\\.)*)"\)',
                repl_string_localized,
                text,
            )
            text = re.sub(
                r"(?<![\w])localized:\s*\"((?:[^\"\\]|\\.)*)\"",
                repl_localized_label,
                text,
            )
            if text != orig:
                p.write_text(text, encoding="utf-8")


def rewrite_catalog(mapping: dict[str, str]) -> tuple[dict, list[str], list[str]]:
    data = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    strings = data["strings"]
    new_strings: dict = {}
    renamed_from: list[str] = []
    deleted: list[str] = []

    for old_key, entry in strings.items():
        new_key = mapping.get(old_key)
        if new_key is None:
            continue
        if new_key in new_strings and new_strings[new_key] != entry:
            raise ValueError(f"Collision rewriting catalog: {new_key!r}")
        new_strings[new_key] = entry
        if old_key != new_key:
            renamed_from.append(f"{old_key} -> {new_key}")

    return {"sourceLanguage": data["sourceLanguage"], "strings": new_strings}, renamed_from, deleted


def main() -> None:
    mapping = build_full_map()
    # Verify plain map covers all non-prefixed referenced keys
    pat = re.compile(r'String\(localized:\s*"((?:[^"\\]|\\.)*)"')
    pat2 = re.compile(r'localized:\s*"((?:[^"\\]|\\.)*)"')
    referenced: set[str] = set()
    for root in SWIFT_ROOTS:
        for p in root.rglob("*.swift"):
            t = p.read_text(encoding="utf-8")
            for pattern in (pat, pat2):
                for m in pattern.finditer(t):
                    s = m.group(1)
                    s = bytes(s, "utf-8").decode("unicode_escape") if "\\" in s else s
                    referenced.add(s)

    missing_plain = []
    for k in referenced:
        if semantic_from_prefixed(k) is None and k not in PLAIN_TO_SEMANTIC:
            # allow empty dict check — actually PLAIN is in _PLAIN_BLOCKS
            pass

    full_plain = load_plain_map()
    for k in referenced:
        if semantic_from_prefixed(k) is None and k not in full_plain:
            missing_plain.append(k)
    if missing_plain:
        raise SystemExit("Missing mappings:\n" + "\n".join(sorted(missing_plain)))

    new_catalog, renamed, _ = rewrite_catalog(mapping)
    CATALOG_PATH.write_text(json.dumps(new_catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    rewrite_swift_files(mapping)
    print(f"Catalog keys: {len(new_catalog['strings'])}")
    print(f"Renamed entries: {len(renamed)}")
    print("Done.")


if __name__ == "__main__":
    main()
