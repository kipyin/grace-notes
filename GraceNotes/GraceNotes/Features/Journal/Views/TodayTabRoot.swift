import SwiftUI

/// Shell for the Today tab’s navigation. Summer appearance (warm paper, leaves, light color scheme)
/// is scoped here so Past and Settings keep the system appearance.
struct TodayTabRoot: View {
    @AppStorage(JournalAppearanceStorageKeys.todayMode)
    private var journalTodayAppearanceRaw = JournalAppearanceMode.standard.rawValue

    private var isSummerToday: Bool {
        (JournalAppearanceMode(rawValue: journalTodayAppearanceRaw) ?? .standard) == .summer
    }

    var body: some View {
        NavigationStack {
            JournalScreen()
        }
        .preferredColorScheme(isSummerToday ? .light : nil)
    }
}
