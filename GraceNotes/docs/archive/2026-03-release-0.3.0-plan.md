# Release Plan 0.3.0

Items deferred from 0.2.0 (see [release-0.2.0-implementation-plan.md](release-0.2.0-implementation-plan.md)) plus long-term features from the original roadmap.

**0.2.0 delivers:** faded chips fix, de-christianify, chip delete, external summarizer API, Chinese (zh-Hans), calendar exploration doc.

---

## Features / Improvements

- [ ] **Reminders** — Optional daily notification to complete today's entry. UserNotifications, settings toggle + time picker, UserDefaults persistence. (See `.cursor/plans/next_step_for_app_86920bfa.plan.md`.)
- [ ] **Monthly calendar view** — Implement calendar view for History if exploration doc (0.2.0) recommends it. Grid of days, month navigation, completion indicator per day.
- [ ] **zh-Hant (Traditional Chinese)** — Add Traditional Chinese localization alongside zh-Hans.

---

## Long-Term Features

- [ ] **In-app sharing (accounts)** — Cloud accounts for sharing journal entries (beyond local share sheet).
- [ ] **YouVersion Bible verse auto-format** — Detect pasted text like `Acts 19:8 NIV https://bible.com/bible/111/act.19.8.NIV` and auto-format to `[Acts 19:8 NIV](https://bible.com/bible/111/act.19.8.NIV)`.
- [ ] **Markdown support** — Allow markdown in Notes and Reflections sections.
- [ ] **Home screen widget** — Widget showing today's entry summary (e.g., completion status or preview).
