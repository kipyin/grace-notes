import UIKit

/// Applies Outfit to system UI chrome. Editorial copy stays on `AppTheme.warmPaper*` via explicit `.font` modifiers.
enum AppInterfaceAppearance {
    static func configure() {
        configureNavigationBar()
        configureTabBar()
        configureBarButtonItem()
    }

    private static func scaledOutfitFont(name: String, baseSize: CGFloat, textStyle: UIFont.TextStyle) -> UIFont {
        guard let font = UIFont(name: name, size: baseSize) else {
            return UIFont.preferredFont(forTextStyle: textStyle)
        }
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font)
    }

    private static func configureNavigationBar() {
        let largeTitleFont = scaledOutfitFont(name: "Outfit-SemiBold", baseSize: 34, textStyle: .largeTitle)
        let inlineTitleFont = scaledOutfitFont(name: "Outfit-SemiBold", baseSize: 17, textStyle: .headline)

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        standard.largeTitleTextAttributes = [.font: largeTitleFont]
        standard.titleTextAttributes = [.font: inlineTitleFont]

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.largeTitleTextAttributes = [.font: largeTitleFont]
        scrollEdge.titleTextAttributes = [.font: inlineTitleFont]

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = standard
        navigationBar.scrollEdgeAppearance = scrollEdge
        navigationBar.compactAppearance = standard
        navigationBar.compactScrollEdgeAppearance = scrollEdge
    }

    private static func configureTabBar() {
        let tabFont = scaledOutfitFont(name: "Outfit-Regular", baseSize: 10, textStyle: .caption2)

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titleTextAttributes = [.font: tabFont]
        itemAppearance.selected.titleTextAttributes = [.font: tabFont]

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        tabAppearance.stackedLayoutAppearance = itemAppearance
        tabAppearance.inlineLayoutAppearance = itemAppearance
        tabAppearance.compactInlineLayoutAppearance = itemAppearance

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabAppearance
        tabBar.scrollEdgeAppearance = tabAppearance
    }

    private static func configureBarButtonItem() {
        let font = scaledOutfitFont(name: "Outfit-Regular", baseSize: 17, textStyle: .body)
        let barButton = UIBarButtonItem.appearance()
        barButton.setTitleTextAttributes([.font: font], for: .normal)
        barButton.setTitleTextAttributes([.font: font], for: .highlighted)
    }
}
