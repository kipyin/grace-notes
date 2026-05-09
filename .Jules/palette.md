## 2025-05-09 - Hide decorative SF Symbols from VoiceOver
**Learning:** Decorative system images (like chevrons and plus icons next to text labels) create VoiceOver noise and redundancy if not explicitly hidden in SwiftUI.
**Action:** Always add `.accessibilityHidden(true)` to `Image(systemName:)` when it is purely decorative or accompanied by a text label that conveys the same meaning.
