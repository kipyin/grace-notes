## 2024-05-10 - Adding accessibility elements to declarative UI
**Learning:** Decorative icons in SwiftUI (using `Image(systemName: "chevron.right")`) are sometimes read aloud by VoiceOver, causing unhelpful announcements for VoiceOver users when the information is purely decorative or redundant to the semantic label of the parent element.
**Action:** When inspecting buttons or list items with visual chevrons/icons, proactively apply `.accessibilityHidden(true)` to decorative `Image(systemName: ...)` elements so the VoiceOver experience is clearer.
