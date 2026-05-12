## 2024-05-23 - Decorative Chevrons in SwiftUI

**Learning:** When using SF Symbols like `chevron.right`, `chevron.up`, or `chevron.down` purely as visual decorators for interaction hints (e.g. next to "Show More" text, or indicating a navigation link in a custom row), VoiceOver can get unnecessarily noisy if they aren't explicitly hidden. SwiftUI doesn't automatically know they are just decorative.
**Action:** Always add `.accessibilityHidden(true)` to `Image(systemName:)` when the symbol acts only as a visual cue and its state/action is already conveyed by the parent element's text or accessibility traits.
