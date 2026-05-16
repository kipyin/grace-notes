## 2024-05-25 - Decorative SF Symbols Accessibility
**Learning:** Decorative icons (like `chevron.right` next to text) are often read unnecessarily by VoiceOver, causing redundant and verbose announcements.
**Action:** Always append `.accessibilityHidden(true)` to purely decorative `Image(systemName:)` views that accompany text labels.
