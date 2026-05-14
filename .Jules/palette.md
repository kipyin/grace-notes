## 2026-05-14 - Redundant Decorative Symbols
**Learning:** Found that some `Image(systemName:)` elements in the GraceNotes app, specifically chevron arrows acting purely as visual indicators in lists, were missing `.accessibilityHidden(true)`. This causes VoiceOver to read out the shape names, adding noise for visually impaired users.
**Action:** Always verify if `Image(systemName:)` in a SwiftUI interactive row/button needs `.accessibilityHidden(true)` so the primary content text is read smoothly without interruption.
