## 2024-05-18 - Decorative SF Symbols Accessibility
**Learning:** Decorative SF Symbols (like chevrons for navigation) need `.accessibilityHidden(true)` so VoiceOver ignores them as redundant visual decorators.
**Action:** Always add `.accessibilityHidden(true)` to `Image(systemName:)` when it provides visual flair but no structural/interactive meaning beyond what the parent button already describes.
