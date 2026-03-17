#!/usr/bin/env fish

# Run this from the repo root, where you see:
#   GraceNotes/
#   GraceNotes.xcodeproj/
#   GraceNotesTests/
#   GraceNotesUITests/

echo "Organizing GraceNotes repo..."

# 1. Create .github/workflows if not present
mkdir -p .github/workflows

# Minimal placeholder CI file (you can replace later)
if not test -f .github/workflows/ios-ci.yml
    begin
        echo "name: iOS CI"
        echo
        echo "on:"
        echo "  pull_request:"
        echo "  push:"
        echo "    branches: [ main ]"
        echo
        echo "jobs:"
        echo "  build-and-test:"
        echo "    runs-on: macos-latest"
        echo "    steps:"
        echo "      - uses: actions/checkout@v4"
        echo "      - name: Xcode version"
        echo "        run: xcodebuild -version"
        echo "      - name: Build and test"
        echo "        run: |"
        echo "          xcodebuild \\"
        echo "            -project GraceNotes/GraceNotes.xcodeproj \\"
        echo "            -scheme GraceNotes \\"
        echo "            -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \\"
        echo "            test"
    end > .github/workflows/ios-ci.yml
    echo "Created .github/workflows/ios-ci.yml"
end

# 2. Create Scripts and Tools directories
mkdir -p Scripts Tools

# 3. Ensure main app folder exists
mkdir -p GraceNotes

# 4. Move Xcode project into app folder (if not already there)
if test -d "GraceNotes.xcodeproj"
    echo "Moving GraceNotes.xcodeproj into GraceNotes/"
    mv GraceNotes.xcodeproj GraceNotes/
end

# 5. Create app source structure
set APP_SRC "GraceNotes/GraceNotes"

mkdir -p \
    "$APP_SRC/Application" \
    "$APP_SRC/Features/Journal/Views" \
    "$APP_SRC/Features/Journal/ViewModels" \
    "$APP_SRC/DesignSystem" \
    "$APP_SRC/Data/Models" \
    "$APP_SRC/Data/Persistence/SwiftData" \
    "$APP_SRC/Services" \
    "$APP_SRC/Utilities" \
    "$APP_SRC/Resources"

# 6. Move existing top-level Swift files into Application/ as a starting point
set has_swift (ls GraceNotes/*.swift 2> /dev/null)
if test (count $has_swift) -gt 0
    echo "Moving top-level Swift files into Application/"
    mv GraceNotes/*.swift "$APP_SRC/Application/"
end

# 7. Create placeholder Swift files if they don't exist yet

# GraceNotesApp.swift
if not test -f "$APP_SRC/Application/GraceNotesApp.swift"
    begin
        echo "import SwiftUI"
        echo
        echo "@main"
        echo "struct GraceNotesApp: App {"
        echo "    var body: some Scene {"
        echo "        WindowGroup {"
        echo "            JournalScreen()"
        echo "        }"
        echo "    }"
        echo "}"
    end > "$APP_SRC/Application/GraceNotesApp.swift"
    echo "Created $APP_SRC/Application/GraceNotesApp.swift"
end

# JournalScreen.swift
if not test -f "$APP_SRC/Features/Journal/Views/JournalScreen.swift"
    begin
        echo "import SwiftUI"
        echo
        echo "struct JournalScreen: View {"
        echo "    @StateObject private var viewModel = JournalViewModel()"
        echo
        echo "    var body: some View {"
        echo "        NavigationStack {"
        echo "            Text(\"Grace Notes\")"
        echo "                .navigationTitle(\"Today\")"
        echo "        }"
        echo "    }"
        echo "}"
        echo
        echo "// Preview"
        echo "// struct JournalScreen_Previews: PreviewProvider {"
        echo "//     static var previews: some View {"
        echo "//         JournalScreen()"
        echo "//     }"
        echo "// }"
    end > "$APP_SRC/Features/Journal/Views/JournalScreen.swift"
    echo "Created $APP_SRC/Features/Journal/Views/JournalScreen.swift"
end

# JournalViewModel.swift
if not test -f "$APP_SRC/Features/Journal/ViewModels/JournalViewModel.swift"
    begin
        echo "import Foundation"
        echo
        echo "final class JournalViewModel: ObservableObject {"
        echo "    // TODO: Add properties and logic for today's 5x5 entry"
        echo "}"
    end > "$APP_SRC/Features/Journal/ViewModels/JournalViewModel.swift"
    echo "Created $APP_SRC/Features/Journal/ViewModels/JournalViewModel.swift"
end

# Theme.swift
if not test -f "$APP_SRC/DesignSystem/Theme.swift"
    begin
        echo "import SwiftUI"
        echo
        echo "enum AppTheme {"
        echo "    static let primaryColor = Color.accentColor"
        echo "}"
    end > "$APP_SRC/DesignSystem/Theme.swift"
    echo "Created $APP_SRC/DesignSystem/Theme.swift"
end

# JournalEntry.swift
if not test -f "$APP_SRC/Data/Models/JournalEntry.swift"
    begin
        echo "import Foundation"
        echo
        echo "struct JournalEntry: Identifiable {"
        echo "    let id: UUID"
        echo "    let date: Date"
        echo "    // TODO: Add properties for 5 gratitudes, 5 needs, 5 friends, etc."
        echo "}"
    end > "$APP_SRC/Data/Models/JournalEntry.swift"
    echo "Created $APP_SRC/Data/Models/JournalEntry.swift"
end

# PersistenceController.swift
if not test -f "$APP_SRC/Data/Persistence/SwiftData/PersistenceController.swift"
    begin
        echo "import Foundation"
        echo "import SwiftData"
        echo
        echo "@MainActor"
        echo "final class PersistenceController {"
        echo "    static let shared = PersistenceController()"
        echo
        echo "    let container: ModelContainer"
        echo
        echo "    private init(inMemory: Bool = false) {"
        echo "        let schema = Schema([])"
        echo "        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)"
        echo "        do {"
        echo "            container = try ModelContainer(for: schema, configurations: configuration)"
        echo "        } catch {"
        echo "            fatalError(\"Failed to create SwiftData container: \\(error)\")"
        echo "        }"
        echo "    }"
        echo "}"
    end > "$APP_SRC/Data/Persistence/SwiftData/PersistenceController.swift"
    echo "Created $APP_SRC/Data/Persistence/SwiftData/PersistenceController.swift"
end

# 8. Organize tests: mirror by feature
mkdir -p GraceNotesTests/Features/Journal
mkdir -p GraceNotesUITests

# Basic placeholder unit test
if not test -f "GraceNotesTests/Features/Journal/JournalViewModelTests.swift"
    begin
        echo "import XCTest"
        echo "@testable import GraceNotes"
        echo
        echo "final class JournalViewModelTests: XCTestCase {"
        echo "    func test_initialState_isValid() {"
        echo "        let vm = JournalViewModel()"
        echo "        // TODO: Add real assertions once state is defined"
        echo "        XCTAssertNotNil(vm)"
        echo "    }"
        echo "}"
    end > "GraceNotesTests/Features/Journal/JournalViewModelTests.swift"
    echo "Created GraceNotesTests/Features/Journal/JournalViewModelTests.swift"
end

# Basic placeholder UI test
if not test -f "GraceNotesUITests/JournalUITests.swift"
    begin
        echo "import XCTest"
        echo
        echo "final class JournalUITests: XCTestCase {"
        echo "    func test_example() {"
        echo "        let app = XCUIApplication()"
        echo "        app.launch()"
        echo "        // TODO: Add basic UI assertions"
        echo "    }"
        echo "}"
    end > "GraceNotesUITests/JournalUITests.swift"
    echo "Created GraceNotesUITests/JournalUITests.swift"
end

echo "Done. Next steps:"
echo "1) open GraceNotes/GraceNotes.xcodeproj"
echo "2) In Xcode, fix any missing file references and add new files to the targets."
echo "3) Run the app and tests to confirm everything builds."
