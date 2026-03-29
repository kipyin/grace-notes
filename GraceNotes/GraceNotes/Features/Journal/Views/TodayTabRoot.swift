import SwiftUI

/// Shell for the Today tab: in Summer mode, paper and leaves are the root inside `NavigationStack`
/// so they stay visible (a stack drawn *behind* `NavigationStack` is covered by its default material).
struct TodayTabRoot: View {
    var body: some View {
        NavigationStack {
            JournalScreen()
        }
    }
}
