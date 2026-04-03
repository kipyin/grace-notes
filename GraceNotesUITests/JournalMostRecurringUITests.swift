import XCTest

final class JournalMostRecurringUITests: XCTestCase {
    @MainActor
    private func launchAppWithWideReviewSeed() -> XCUIApplication {
        let app = XCUIApplication()
        app.configureGraceNotesUITestLaunch(resetUITestStore: true, wideReviewRhythm: true)
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Gratitudes"].waitForExistence(timeout: 5),
            "Expected UI test launch to bypass onboarding and open Today screen."
        )
        return app
    }

    private func mainMostRecurringRows(in app: XCUIApplication) -> XCUIElementQuery {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "MostRecurringThemeRow.")
        return app.buttons.matching(predicate)
    }

    private func browseTrendingRows(in app: XCUIApplication) -> XCUIElementQuery {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "TrendingThemeBrowseRow.")
        return app.descendants(matching: .any).matching(predicate)
    }

    private func mainTrendingRows(in app: XCUIApplication) -> XCUIElementQuery {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "TrendingThemeRow.")
        return app.buttons.matching(predicate)
    }

    private func browseMostRecurringRows(in app: XCUIApplication) -> XCUIElementQuery {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "MostRecurringThemeBrowseRow.")
        return app.descendants(matching: .any).matching(predicate)
    }

    private func mostRecurringBrowseSection(_ category: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", "MostRecurringBrowseSection.\(category)"))
            .firstMatch
    }

    @MainActor
    private func openPastReviewPanels(_ app: XCUIApplication) {
        app.tabBars.buttons["Past"].tap()
        let mostRecurringTitle = app.staticTexts["Most recurring"]
        if mostRecurringTitle.waitForExistence(timeout: 8) {
            return
        }
        for _ in 0..<16 {
            app.swipeUp()
            if mostRecurringTitle.waitForExistence(timeout: 1.5) {
                return
            }
        }
        XCTAssertTrue(
            mostRecurringTitle.waitForExistence(timeout: 10),
            "Expected Most recurring panel in Past tab."
        )
    }

    /// With separate list rows for summary, recurring, and trending, the Trending title may need a small scroll.
    @MainActor
    private func scrollPastReviewUntilTrendingVisible(_ app: XCUIApplication) {
        let trendingTitle = app.staticTexts["Trending"]
        if trendingTitle.waitForExistence(timeout: 2) {
            return
        }
        for _ in 0..<8 {
            app.swipeUp()
            if trendingTitle.waitForExistence(timeout: 1) {
                return
            }
        }
        XCTAssertTrue(
            trendingTitle.waitForExistence(timeout: 10),
            "Expected Trending panel in Past tab."
        )
    }

    @MainActor
    private func openTrendingBrowseSheet(_ app: XCUIApplication) -> Bool {
        let browseRows = browseTrendingRows(in: app)
        let done = app.buttons["TrendingBrowseSheetDone"]
        let tapElementCenter: (XCUIElement) -> Void = { element in
            let frame = element.frame
            guard !frame.isEmpty else {
                element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                return
            }
            let appOrigin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
            appOrigin.withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        }

        for attempt in 0..<4 {
            let linkQuery = app.buttons.matching(identifier: "BrowseAllTrendingThemesLink")
            guard linkQuery.firstMatch.waitForExistence(timeout: 8) else { return false }

            var scrollAttempts = 0
            while !linkQuery.allElementsBoundByIndex.contains(where: \.isHittable) && scrollAttempts < 12 {
                app.swipeUp()
                scrollAttempts += 1
            }

            var linkToTap = linkQuery.allElementsBoundByIndex.first(where: \.isHittable) ?? linkQuery.firstMatch
            // Avoid tapping too close to floating chrome near the bottom edge on compact simulators.
            if linkToTap.frame.maxY > (app.frame.maxY - 120) {
                app.swipeUp()
                let refreshed = app.buttons.matching(identifier: "BrowseAllTrendingThemesLink")
                linkToTap = refreshed.allElementsBoundByIndex.first(where: \.isHittable) ?? refreshed.firstMatch
            }

            tapElementCenter(linkToTap)
            if done.waitForExistence(timeout: 2) || browseRows.firstMatch.waitForExistence(timeout: 2) {
                return true
            }

            // Fallback to element-dispatched tap in case coordinate tap hit list chrome.
            if linkToTap.exists, linkToTap.isHittable {
                linkToTap.tap()
            }

            if done.waitForExistence(timeout: attempt == 0 ? 10 : 6)
                || browseRows.firstMatch.waitForExistence(timeout: 4) {
                return true
            }
        }
        return false
    }
}

extension JournalMostRecurringUITests {
    // swiftlint:disable function_body_length
    @MainActor
    func test_reviewScreen_browseAndDrilldown_showMatchingSurfaceContent() {
        let app = launchAppWithWideReviewSeed()
        openPastReviewPanels(app)

        let rows = mainMostRecurringRows(in: app)
        XCTAssertGreaterThan(rows.count, 0, "Expected at least one Most Recurring row.")
        let firstRow = rows.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 8), "Expected first Most Recurring row.")
        XCTAssertTrue(firstRow.isHittable, "Expected first Most Recurring row to be tappable.")
        firstRow.tap()
        let themeDetailsNav = app.navigationBars["Theme details"]
        XCTAssertTrue(
            themeDetailsNav.waitForExistence(timeout: 8),
            "Expected drilldown destination from the main recurring section."
        )
        XCTAssertTrue(
            app.staticTexts["Matching writing surfaces"].waitForExistence(timeout: 5),
            "Expected per-surface evidence section in drilldown."
        )
        let drilldownDone = themeDetailsNav.buttons["Done"]
        XCTAssertTrue(drilldownDone.waitForExistence(timeout: 6), "Expected Done on theme drilldown.")
        drilldownDone.tap()
        let drilldownDismissDeadline = Date().addingTimeInterval(20)
        while Date() < drilldownDismissDeadline, themeDetailsNav.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }
        XCTAssertFalse(
            themeDetailsNav.exists,
            "Theme drilldown should dismiss before opening Trending browse (avoids sheet stacking on iOS 18)."
        )

        scrollPastReviewUntilTrendingVisible(app)
        var openedTrendingViaBrowse = false
        if app.buttons["BrowseAllTrendingThemesLink"].waitForExistence(timeout: 4) {
            XCTAssertTrue(
                openTrendingBrowseSheet(app),
                "Expected dedicated trending browse sheet (toolbar Done)."
            )
            let browseRows = browseTrendingRows(in: app)
            XCTAssertTrue(
                browseRows.firstMatch.waitForExistence(timeout: 8),
                "Expected browse screen to show trending themes."
            )
            let firstBrowseRow = browseRows.element(boundBy: 0)
            firstBrowseRow.tap()
            openedTrendingViaBrowse = true
        }

        if !openedTrendingViaBrowse {
            let trendingRows = mainTrendingRows(in: app)
            XCTAssertGreaterThan(
                trendingRows.count,
                0,
                "Expected at least one Trending row when browse link is hidden."
            )
            let firstTrendRow = trendingRows.element(boundBy: 0)
            XCTAssertTrue(firstTrendRow.waitForExistence(timeout: 8))
            var scrollAttempts = 0
            while !firstTrendRow.isHittable && scrollAttempts < 12 {
                app.swipeUp()
                scrollAttempts += 1
            }
            firstTrendRow.tap()
        }

        XCTAssertTrue(
            app.navigationBars["Theme details"].waitForExistence(timeout: 8),
            "Expected drilldown destination from trending browse or main Trending row."
        )
        XCTAssertTrue(
            app.staticTexts["Matching writing surfaces"].waitForExistence(timeout: 5),
            "Expected per-surface evidence section in drilldown."
        )
    }
    // swiftlint:enable function_body_length

    @MainActor
    func test_reviewScreen_mostRecurringAndTrending_cappedAtThreeOnMainPastCard() {
        let app = launchAppWithWideReviewSeed()
        openPastReviewPanels(app)
        scrollPastReviewUntilTrendingVisible(app)

        let recurringVisible = mainMostRecurringRows(in: app).count
        let trendingVisible = mainTrendingRows(in: app).count
        XCTAssertGreaterThan(recurringVisible, 0, "Seed should produce at least one recurring theme.")
        XCTAssertGreaterThan(trendingVisible, 0, "Seed should produce at least one trending theme.")
        XCTAssertLessThanOrEqual(recurringVisible, 3, "Main Past card should show at most three recurring rows.")
        XCTAssertLessThanOrEqual(trendingVisible, 3, "Main Past card should show at most three trending rows.")
    }

    @MainActor
    func test_reviewScreen_browseRecurringThemes_opensBrowseList() throws {
        let app = launchAppWithWideReviewSeed()
        openPastReviewPanels(app)

        let browseButton = app.buttons["BrowseAllRecurringThemesLink"]
        guard browseButton.waitForExistence(timeout: 12) else {
            throw XCTSkip("Wide review seed did not yield enough recurring themes to show browse link.")
        }
        var scrollAttempts = 0
        while !browseButton.isHittable && scrollAttempts < 12 {
            app.swipeUp()
            scrollAttempts += 1
        }
        browseButton.tap()

        let browseRows = browseMostRecurringRows(in: app)
        XCTAssertTrue(
            browseRows.element(boundBy: 0).waitForExistence(timeout: 12),
            "Browse screen should expose at least one recurring theme row."
        )
    }

    /// Each “Browse all” control must present its own sheet (recurring vs trending), not the wrong destination.
    @MainActor
    func test_reviewScreen_browseAllRecurringThenTrending_openDistinctScreens() throws {
        let app = launchAppWithWideReviewSeed()
        openPastReviewPanels(app)

        let recurringLink = app.buttons["BrowseAllRecurringThemesLink"]
        guard recurringLink.waitForExistence(timeout: 12) else {
            throw XCTSkip("Wide review seed did not yield enough recurring themes to show recurring browse link.")
        }
        var scrollAttempts = 0
        while !recurringLink.isHittable && scrollAttempts < 12 {
            app.swipeUp()
            scrollAttempts += 1
        }
        recurringLink.tap()
        XCTAssertTrue(
            app.buttons["MostRecurringBrowseSheetDone"].waitForExistence(timeout: 10),
            "Recurring browse should show the recurring browse sheet Done control."
        )

        let recurringDone = app.buttons["MostRecurringBrowseSheetDone"]
        XCTAssertTrue(recurringDone.waitForExistence(timeout: 6), "Expected Done on the recurring browse sheet.")
        recurringDone.tap()
        XCTAssertTrue(recurringLink.waitForExistence(timeout: 8), "Expected to return to the Past review card.")

        scrollPastReviewUntilTrendingVisible(app)
        let trendingLink = app.buttons["BrowseAllTrendingThemesLink"]
        guard trendingLink.waitForExistence(timeout: 12) else {
            throw XCTSkip("Trending browse link is hidden when the Past tab shows at most three trending rows.")
        }
        scrollAttempts = 0
        while !trendingLink.isHittable && scrollAttempts < 12 {
            app.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(
            openTrendingBrowseSheet(app),
            "Trending browse should show the Trending browse sheet Done control."
        )
    }

    @MainActor
    func test_reviewScreen_mostRecurringBrowse_sectionsBySurfaceKind() throws {
        let app = launchAppWithWideReviewSeed()
        openPastReviewPanels(app)

        let browseButton = app.buttons["BrowseAllRecurringThemesLink"]
        guard browseButton.waitForExistence(timeout: 12) else {
            throw XCTSkip("Wide review seed did not yield enough recurring themes to show browse link.")
        }
        var scrollAttempts = 0
        while !browseButton.isHittable && scrollAttempts < 12 {
            app.swipeUp()
            scrollAttempts += 1
        }
        browseButton.tap()

        XCTAssertTrue(app.buttons["MostRecurringBrowseSheetDone"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            mostRecurringBrowseSection("gratitudes", in: app).waitForExistence(timeout: 10),
            "Browse list should section gratitudes."
        )

        let needsHeader = mostRecurringBrowseSection("needs", in: app)
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline, !needsHeader.exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            needsHeader.waitForExistence(timeout: 2),
            "Browse list should section needs (scroll if the list is long)."
        )
    }

    @MainActor
    func test_reviewScreen_trendingBrowse_showsNewUpOrDownSection() throws {
        let app = launchAppWithWideReviewSeed()
        openPastReviewPanels(app)
        scrollPastReviewUntilTrendingVisible(app)

        let trendingLink = app.buttons["BrowseAllTrendingThemesLink"]
        guard trendingLink.waitForExistence(timeout: 12) else {
            throw XCTSkip("Trending browse link is hidden when the Past tab shows at most three trending rows.")
        }
        let browseRows = browseTrendingRows(in: app)
        XCTAssertTrue(
            openTrendingBrowseSheet(app),
            "Trending browse sheet should present (first open can be slower on iOS 18 SE)."
        )
        let newHeader = app.staticTexts["New"]
        let upHeader = app.staticTexts["Up"]
        let downHeader = app.staticTexts["Down"]
        let deadline = Date().addingTimeInterval(8)
        var sawBucketHeader = false
        while Date() < deadline, !sawBucketHeader {
            if newHeader.exists || upHeader.exists || downHeader.exists {
                sawBucketHeader = true
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(
            sawBucketHeader,
            "Trending browse should group rows under at least one of New, Up, or Down."
        )
        XCTAssertTrue(
            browseRows.firstMatch.waitForExistence(timeout: 8),
            "Expected trending browse rows to appear after the sheet opens."
        )
        XCTAssertGreaterThan(browseRows.count, 0, "Expected at least one trending browse row.")
    }

    /// Default seed is one prior-day entry; Trending floors are not met, so the card shows fallback copy.
    @MainActor
    func test_reviewScreen_trendingEmptyFallback_showsGuidanceCopy() {
        let app = XCUIApplication()
        app.configureGraceNotesUITestLaunch(resetUITestStore: true, wideReviewRhythm: false)
        app.launch()
        XCTAssertTrue(
            app.staticTexts["Gratitudes"].waitForExistence(timeout: 5),
            "Expected UI test launch to bypass onboarding and open Today screen."
        )
        app.tabBars.buttons["Past"].tap()

        let trendingTitle = app.staticTexts["Trending"]
        for _ in 0..<20 {
            if trendingTitle.waitForExistence(timeout: 2) {
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(trendingTitle.waitForExistence(timeout: 10), "Expected Trending section on Past review.")

        let fallback = app.staticTexts["Keep writing to see trends for this calendar week."]
        let emptyId = app.descendants(matching: .any)["ReviewTrendingEmptyState"]
        for _ in 0..<12 {
            if fallback.waitForExistence(timeout: 1) || emptyId.waitForExistence(timeout: 1) {
                break
            }
            app.swipeUp()
        }
        XCTAssertTrue(
            fallback.exists || emptyId.exists,
            "Expected empty Trending fallback when no themes pass the trend policy."
        )
    }

    @MainActor
    func test_reviewScreen_mostRecurringAndTrending_areSeparateTopLevelSections() {
        let app = launchAppWithWideReviewSeed()
        openPastReviewPanels(app)
        scrollPastReviewUntilTrendingVisible(app)

        XCTAssertTrue(mainMostRecurringRows(in: app).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["Trending"].exists)
    }
}
