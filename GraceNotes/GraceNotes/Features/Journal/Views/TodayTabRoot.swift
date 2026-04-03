import SwiftUI

/// Shell for the Today tab’s navigation. When Bloom mode is on, paper and leaves are layered in
/// ``GraceNotesApp`` above the whole ``TabView``—intentional for cross-tab cohesion behind system chrome.
struct TodayTabRoot: View {
    var body: some View {
        NavigationStack {
            JournalScreen()
        }
    }
}
