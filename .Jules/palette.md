## 2024-05-18 - Decorative SF Symbols and VoiceOver Redundancy
**Learning:** Decorative icons (like chevrons for expansion or drill-downs) should be explicitly hidden from screen readers. Even inside a `Button` or an `accessibilityElement(children: .combine)` or `.ignore` structure, VoiceOver can sometimes latch onto the underlying icon's system name or description if not explicitly hidden, creating unnecessary noise.
**Action:** Always add `.accessibilityHidden(true)` to `Image(systemName:)` elements that are purely decorative or redundant to the main action's text.
