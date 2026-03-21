# 17 — Reminders flow

## What you will learn

You will learn:
- why reminders use model + scheduler split
- where permission flow is handled
- where UI-facing reminder state comes from

Reminders are controlled by a view model + scheduler service split.

This split keeps permission/schedule details out of screen code.

## Reminder UI state model

File: `../../GraceNotes/GraceNotes/Features/Settings/ReminderSettingsFlowModel.swift`  
Type: `ReminderSettingsFlowModel`

This model owns:

- live reminder status
- selected reminder time
- enable/disable actions
- transient error text

It also throttles time-change rescheduling to avoid noisy repeated writes.

Real snippets:

```swift
@Published private(set) var liveStatus: ReminderLiveStatus = .off
```

```swift
try await Task.sleep(nanoseconds: 400_000_000)
```

How to read these snippets:
- first line exposes state to UI while protecting write access
- second line debounces rapid time picker updates

Key methods:

- `refreshStatus()`
- `enableReminders()`
- `disableReminders()`
- `saveEnabledReminderTime()`
- `handleSelectedTimeChanged()`

## Reminder scheduler service

File: `../../GraceNotes/GraceNotes/Services/Reminders/ReminderScheduler.swift`  
Type: `ReminderScheduler`

This service talks to `UNUserNotificationCenter`.

It handles:

- permission state checks
- authorization request (when allowed)
- schedule daily repeating notification
- remove pending reminder request

It returns typed outcomes (`ReminderSyncResult`) that UI model maps to user-facing state.

Real snippets:

```swift
func enableDailyReminder(at time: Date) async -> ReminderSyncResult {
```

```swift
let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents, repeats: true)
```

```swift
notificationCenter.removePendingNotificationRequests(
    withIdentifiers: [ReminderSettings.notificationIdentifier]
)
```

How to read these snippets:
- function signature shows async typed result
- trigger line shows daily repeating reminder scheduling
- remove call shows explicit disable/cleanup path

## Reminder settings constants

File: `../../GraceNotes/GraceNotes/Services/Reminders/ReminderSettings.swift`

Contains:

- key names
- default time
- notification identifier
- helper to get hour/minute components

## Status model used in code

Enums in `ReminderScheduler.swift`:

- `ReminderLiveStatus`
- `ReminderSyncResult`

Examples:

- `.enabled`
- `.off`
- `.denied`
- `.unavailable`

These explicit states make Settings copy clearer and easier to test.

## Where reminders appear in UI

In `SettingsScreen`:

- reminder toggle
- time picker
- denied-state “Open Settings” guidance

File: `../../GraceNotes/GraceNotes/Features/Settings/SettingsScreen.swift`

Look at:
- `reminderToggleBinding`
- `reminderTimePicker`
- denied/unavailable guidance blocks

## Common confusion

- “Why is reminder toggle off after I changed time?”  
  If permission is denied/unavailable, model can move state off and show guidance.

- “Does refresh ask permission pop-up?”  
  No. `refreshStatus()` is passive; explicit enable flow handles prompts.

- “Why both model and scheduler exist?”  
  Model coordinates UI behavior; scheduler wraps OS notifications.

## If you know Python

This is similar to:

- one stateful UI model class
- one service that wraps OS notification API

The UI model calls the service and maps result into user-facing state.

## Read next

[18-onboarding.md](./18-onboarding.md)

## Quick check

1. Which snippet shows state published to Settings UI?
2. Which snippet shows daily schedule trigger creation?
3. Which snippet removes pending reminder request?
