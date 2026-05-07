## 2024-05-24 - Accessibility checks in Settings
**Learning:** Found several decorative 'chevron.right' icons in the Settings screen that are read out by VoiceOver as "chevron right" which isn't helpful, and instead they should be hidden using `.accessibilityHidden(true)`.
**Action:** Always add `.accessibilityHidden(true)` to decorative `Image(systemName:)` chevrons, especially when they are part of a `Button` or `NavigationLink` where the text label already explains the destination/action.
