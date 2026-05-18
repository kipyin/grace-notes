## 2026-05-18 - Redundant SF Symbols in Buttons and Links
**Learning:** Screen readers announce visual decorators (like chevron.right or chevron.down) unnecessarily when they are grouped next to descriptive text in buttons, navigation links, or list rows. This creates repetitive or confusing audio experiences.
**Action:** Ensure decorative `Image(systemName:)` views used alongside text are explicitly marked with `.accessibilityHidden(true)`.
