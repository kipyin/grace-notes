# Monthly Calendar View — Exploration

**Status:** Exploration only. No implementation in 0.2.0.  
**Recommendation:** Defer implementation to 0.3.0; implement only if this analysis supports it.

---

## Current State

**HistoryScreen** shows past entries as a list grouped by month (e.g., "March 2026", "February 2026"). Each row displays the date (abbreviated) and a checkmark if the entry is complete. Tapping a row navigates to the journal for that date.

This is simple, linear, and easy to navigate. It does not surface patterns at a glance (streaks, gaps, density).

---

## Pros of a Monthly Calendar View


| Benefit                          | Description                                                                                                                                                                         |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Faster visual scanning**       | A grid of days lets users spot which dates have entries without scrolling. "Did I write last Tuesday?" becomes a quick visual lookup instead of list-scanning.                      |
| **Familiar metaphor**            | Calendar grids are ubiquitous. Users understand month-based navigation and day selection without learning a new pattern.                                                            |
| **Streak and gap visualization** | Gaps (missing days) and streaks (consecutive filled days) become obvious. This supports the journal's reflective intent and can motivate consistency without explicit gamification. |
| **Natural month navigation**     | Swiping or tapping arrows to move between months maps to how users think about time ("last month", "this month"). Less cognitive load than a long list with section headers.        |
| **Spatial memory**               | Some users remember "around the middle of March" better than scanning a list. Grid position reinforces temporal context.                                                            |


---

## Cons of a Monthly Calendar View


| Concern                                    | Description                                                                                                                                                                                                                                                                                                     |
| ------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **More complex layout**                    | A 7×6 (or similar) grid with correct day-of-week alignment, variable month lengths, and leading/trailing padding requires careful SwiftUI layout. More code than the current list.                                                                                                                              |
| **Ambiguous empty vs. no-entry semantics** | An empty cell can mean: (a) no entry for that day, (b) a future day in the month, or (c) a day before the user started journaling. Without clear distinction, users may misread "no entry" as "future" or vice versa. Requires explicit conventions (e.g., gray future days, different styling for past-empty). |
| **Potential accessibility issues**         | VoiceOver on a grid of 35+ cells can be tedious. List order is predictable; grid order (row-by-row? column-by-column?) and cell labels (date + status) need careful design. Reduced-motion and color-blind users need sufficient non-color cues (icons, patterns) for entry vs. no-entry.                       |
| **Higher implementation effort**           | New view, queries for a date range, month-boundary logic, tap-to-navigate, optional streak/gap highlighting. Non-trivial compared to the existing list.                                                                                                                                                         |
| **Small touch targets**                    | On iPhone, each cell may be small. Tap targets should meet accessibility guidelines (44pt minimum). May need zoom or day-detail view for dense months.                                                                                                                                                          |


---

## Implementation Considerations

If implemented in 0.3.0:

1. **Data:** `JournalRepository` already supports `fetchEntry(for date:)`. A `fetchEntries(from:to:)` or month-based query would be needed for batch loading.
2. **UI:** Use `LazyVGrid` or manual `HStack`/`VStack` with 7 columns. First row: day-of-week headers. Subsequent rows: date cells. Style cells by state (has entry, complete, no entry, future).
3. **Navigation:** Tap cell → `NavigationLink` to `JournalScreen(entryDate:)` (same as current History row tap).
4. **Accessibility:** Ensure each cell has a clear `accessibilityLabel` (e.g., "March 5, has entry, complete") and logical `accessibilityHint`. Consider a "List view" toggle for users who prefer the simpler list.

---

## Recommendation

**Defer implementation to 0.3.0.** The current list-based history is sufficient for 0.2.0. A calendar view adds meaningful value (streaks, gaps, scanning) but introduces layout, semantics, and accessibility complexity that deserves focused design work. Ship 0.2.0 with the list, gather feedback, and reassess for 0.3.0. If users request "see my streaks" or "calendar view," this analysis provides the groundwork.

Implement the monthly calendar **only if**:

- User feedback or product goals clearly call for streak/gap visibility, or
- The 0.3.0 scope allows dedicated design and accessibility review for the grid.

