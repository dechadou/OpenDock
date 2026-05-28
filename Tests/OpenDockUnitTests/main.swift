import CoreGraphics
import Darwin
import Foundation
import OpenDockCore

struct TestFailure: Error, CustomStringConvertible {
    var description: String
}

@main
struct OpenDockUnitTestRunner {
    static func main() async {
        let tests: [(String, () async throws -> Void)] = [
            (
                "preferences persist",
                {
                    try await MainActor.run {
                        try testPreferencesPersist()
                    }
                }
            ),
            (
                "preferences decode dock setting default",
                {
                    try testPreferencesDecodeDockSettingDefault()
                }
            ),
            (
                "preferences decode bottom reveal delay default",
                {
                    try testPreferencesDecodeBottomRevealDelayDefault()
                }
            ),
            (
                "preferences decode media source app icon default",
                {
                    try testPreferencesDecodeMediaSourceAppIconDefault()
                }
            ),
            (
                "pinned items persist",
                {
                    try await MainActor.run {
                        try testPinnedItemsPersist()
                    }
                }
            ),
            (
                "pinned items deduplicate",
                {
                    try await MainActor.run {
                        try testPinnedItemsDeduplicate()
                    }
                }
            ),
            (
                "sidebar items migrate legacy pins",
                {
                    try await MainActor.run {
                        try testSidebarItemsMigrateLegacyPins()
                    }
                }
            ),
            (
                "sidebar items reorder",
                {
                    try await MainActor.run {
                        try testSidebarItemsReorder()
                    }
                }
            ),
            (
                "sidebar stacks move children",
                {
                    try await MainActor.run {
                        try testSidebarStacksMoveChildren()
                    }
                }
            ),
            (
                "sidebar stack drop restrictions",
                {
                    try await MainActor.run {
                        try testSidebarStackDropRestrictions()
                    }
                }
            ),
            (
                "application scanner reads bundles",
                {
                    try testApplicationScannerReadsBundles()
                }
            ),
            (
                "folder peek filters hidden files",
                {
                    try testFolderPeekFiltersHiddenFiles()
                }
            ),
            (
                "trash path points to user trash",
                {
                    try testTrashPath()
                }
            ),
            (
                "trash count prefers finder state",
                {
                    try testTrashCountResolution()
                }
            ),
            (
                "sidebar frame calculator",
                {
                    try testSidebarFrameCalculator()
                }
            ),
            (
                "sidebar dock layout fixed sections",
                {
                    try testSidebarDockLayout()
                }
            ),
            (
                "sidebar visibility policy",
                {
                    try testSidebarVisibilityPolicy()
                }
            ),
            (
                "login item launch agent plist",
                {
                    try testLoginItemLaunchAgentPlist()
                }
            ),
            (
                "dock autohide output parsing",
                {
                    try testDockAutohideOutputParsing()
                }
            ),
            (
                "dock snapshot v2 command plan",
                {
                    try testDockSnapshotV2CommandPlan()
                }
            ),
            (
                "legacy dock snapshot converts",
                {
                    try testLegacyDockSnapshotConverts()
                }
            ),
            (
                "panel preference diff",
                {
                    try testPanelPreferenceDiff()
                }
            ),
            (
                "panel reveal policy bottom edge",
                {
                    try testPanelRevealPolicyBottomEdge()
                }
            ),
            (
                "panel reveal policy visible hold",
                {
                    try testPanelRevealPolicyVisibleHold()
                }
            ),
            (
                "sidebar recursive app matching",
                {
                    try await MainActor.run {
                        try testSidebarRecursiveAppMatching()
                    }
                }
            ),
            (
                "dock badge parsing",
                {
                    try testDockBadgeParsing()
                }
            ),
            (
                "app context menu model",
                {
                    try testAppContextMenuModel()
                }
            ),
            (
                "window move geometry",
                {
                    try testWindowMoveGeometry()
                }
            ),
            (
                "screen coordinate conversion",
                {
                    try testScreenCoordinateConversion()
                }
            ),
            (
                "window preview grid layout",
                {
                    try testWindowPreviewGridLayout()
                }
            ),
        ]

        var failures: [String] = []

        for (name, test) in tests {
            do {
                try await test()
                print("PASS \(name)")
            } catch {
                failures.append("\(name): \(error)")
                print("FAIL \(name): \(error)")
            }
        }

        guard failures.isEmpty else {
            fputs("\n\(failures.count) test(s) failed\n", stderr)
            exit(1)
        }

        print("\nAll \(AppIdentity.displayName) unit tests passed")
    }

    @MainActor
    private static func testPreferencesPersist() throws {
        let suiteName = "OpenDockTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw TestFailure(description: "failed to create user defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)

        let store = PreferencesStore(defaults: defaults, key: "preferences")
        try expect(store.preferences == .defaults, "expected default preferences")

        store.update { preferences in
            preferences.edge = .right
            preferences.iconSize = 42
            preferences.autoHide = false
        }

        let reloaded = PreferencesStore(defaults: defaults, key: "preferences")
        try expect(reloaded.preferences.edge == .right, "expected persisted edge")
        try expect(reloaded.preferences.iconSize == 42, "expected persisted icon size")
        try expect(!reloaded.preferences.autoHide, "expected persisted auto-hide")

        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func testPreferencesDecodeDockSettingDefault() throws {
        let data = #"{"edge":"right"}"#.data(using: .utf8)!
        let preferences = try JSONDecoder().decode(SidebarPreferences.self, from: data)

        try expect(preferences.edge == .right, "expected decoded edge")
        try expect(!preferences.hideSystemDock, "expected hideSystemDock to default to false")
    }

    private static func testPreferencesDecodeBottomRevealDelayDefault() throws {
        let data = #"{"edge":"bottom"}"#.data(using: .utf8)!
        let preferences = try JSONDecoder().decode(SidebarPreferences.self, from: data)

        try expect(preferences.edge == .bottom, "expected decoded bottom edge")
        try expect(
            preferences.bottomRevealDelayMilliseconds == 30,
            "expected bottom reveal delay to default to 30 ms"
        )
    }

    private static func testPreferencesDecodeMediaSourceAppIconDefault() throws {
        let data = #"{"edge":"left"}"#.data(using: .utf8)!
        let preferences = try JSONDecoder().decode(SidebarPreferences.self, from: data)

        try expect(preferences.hideMediaSourceAppIcon, "expected media source icon hiding to default to true")
    }

    @MainActor
    private static func testPinnedItemsPersist() throws {
        let fileURL = try makeTemporaryDirectory().appendingPathComponent("PinnedItems.json")
        let store = PinnedItemStore(fileURL: fileURL)
        let appURL = URL(fileURLWithPath: "/Applications/Finder.app")

        let item = store.add(
            kind: .application,
            title: "Finder",
            url: appURL,
            bundleIdentifier: "com.apple.finder"
        )

        try expect(store.items.count == 1, "expected one pinned item")
        try expect(store.items.first?.id == item.id, "expected returned item id")

        let reloaded = PinnedItemStore(fileURL: fileURL)
        try expect(reloaded.items.count == 1, "expected one reloaded item")
        try expect(reloaded.items.first?.title == "Finder", "expected reloaded title")
        try expect(reloaded.items.first?.bundleIdentifier == "com.apple.finder", "expected reloaded bundle id")
        try expect(reloaded.items.first?.url == appURL, "expected reloaded URL")
    }

    @MainActor
    private static func testPinnedItemsDeduplicate() throws {
        let fileURL = try makeTemporaryDirectory().appendingPathComponent("PinnedItems.json")
        let store = PinnedItemStore(fileURL: fileURL)

        store.add(
            kind: .application,
            title: "One",
            url: URL(fileURLWithPath: "/Applications/One.app"),
            bundleIdentifier: "dev.test.duplicate"
        )
        store.add(
            kind: .application,
            title: "Two",
            url: URL(fileURLWithPath: "/Applications/Two.app"),
            bundleIdentifier: "dev.test.duplicate"
        )

        try expect(store.items.count == 1, "expected duplicate bundle id to be ignored")
        try expect(store.items.first?.title == "One", "expected first duplicate to win")
    }

    private static func testApplicationScannerReadsBundles() throws {
        let root = try makeTemporaryDirectory()
        let contents = root.appendingPathComponent("Fake.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)

        let plist: [String: String] = [
            "CFBundleName": "Fake Tool",
            "CFBundleIdentifier": "dev.test.fake-tool",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))

        let applications = ApplicationScanner.scan(directories: [root])

        try expect(applications.count == 1, "expected one scanned app")
        try expect(applications.first?.name == "Fake Tool", "expected bundle name")
        try expect(applications.first?.bundleIdentifier == "dev.test.fake-tool", "expected bundle id")
        try expect(applications.first?.url.lastPathComponent == "Fake.app", "expected app URL")
    }

    @MainActor
    private static func testSidebarItemsMigrateLegacyPins() throws {
        let directory = try makeTemporaryDirectory()
        let sidebarURL = directory.appendingPathComponent("SidebarItems.json")
        let legacyURL = directory.appendingPathComponent("PinnedItems.json")
        let legacy = [
            PinnedItem(
                kind: .application,
                title: "Finder",
                url: URL(fileURLWithPath: "/Applications/Finder.app"),
                bundleIdentifier: "com.apple.finder"
            )
        ]
        let data = try JSONEncoder().encode(legacy)
        try data.write(to: legacyURL)

        let store = SidebarItemStore(fileURL: sidebarURL, legacyPinnedItemsURL: legacyURL)

        try expect(store.items.contains { $0.title == "Finder" && $0.kind == .application }, "expected legacy app pin")
        try expect(store.items.contains { $0.systemKind == .windowSwitcher }, "expected window switcher widget")
        try expect(store.items.contains { $0.systemKind == .trash }, "expected trash widget")
        try expect(FileManager.default.fileExists(atPath: sidebarURL.path), "expected migrated sidebar file")
    }

    @MainActor
    private static func testSidebarItemsReorder() throws {
        let fileURL = try makeTemporaryDirectory().appendingPathComponent("SidebarItems.json")
        let store = SidebarItemStore(fileURL: fileURL, legacyPinnedItemsURL: fileURL.deletingLastPathComponent().appendingPathComponent("missing.json"))
        store.clear()

        let first = store.add(kind: .url, title: "First", url: URL(string: "https://first.test"))
        let second = store.add(kind: .url, title: "Second", url: URL(string: "https://second.test"))

        store.moveMainItem(id: second.id, before: first.id)

        try expect(store.items.map(\.title) == ["Second", "First"], "expected reordered items")

        let stack = store.createStack(title: "Work")
        let trash = store.add(SidebarItem.system(.trash))
        store.movePinnedItem(id: first.id, before: second.id)
        store.movePinnedItem(id: stack.id, before: second.id)
        store.movePinnedItem(id: trash.id, before: second.id)

        let sections = SidebarDockLayout.sections(from: store.items)
        try expect(sections.stacks.map(\.title) == ["Work"], "expected stack section to stay separate")
        try expect(sections.pinnedItems.map(\.title) == ["First", "Second"], "expected only pinned items to reorder")
    }

    @MainActor
    private static func testSidebarStacksMoveChildren() throws {
        let fileURL = try makeTemporaryDirectory().appendingPathComponent("SidebarItems.json")
        let store = SidebarItemStore(fileURL: fileURL, legacyPinnedItemsURL: fileURL.deletingLastPathComponent().appendingPathComponent("missing.json"))
        store.clear()

        let stack = store.createStack(title: "Work")
        let item = store.add(kind: .url, title: "Docs", url: URL(string: "https://docs.test"))

        store.moveMainItemIntoStack(itemID: item.id, stackID: stack.id)

        let updatedStack = try unwrap(store.item(id: stack.id), "expected stack")
        try expect(updatedStack.children.map(\.title) == ["Docs"], "expected child inside stack")
        try expect(!store.items.contains { $0.id == item.id }, "expected child removed from main items")

        store.moveChildOutOfStack(childID: item.id, stackID: stack.id)

        try expect(store.items.contains { $0.id == item.id }, "expected child moved out")
    }

    @MainActor
    private static func testSidebarStackDropRestrictions() throws {
        let fileURL = try makeTemporaryDirectory().appendingPathComponent("SidebarItems.json")
        let store = SidebarItemStore(fileURL: fileURL, legacyPinnedItemsURL: fileURL.deletingLastPathComponent().appendingPathComponent("missing.json"))
        store.clear()

        let workStack = store.createStack(title: "Work")
        let nestedStack = store.createStack(title: "Nested")
        let trash = store.add(SidebarItem.system(.trash))

        store.moveMainItemIntoStack(itemID: nestedStack.id, stackID: workStack.id)
        store.moveMainItemIntoStack(itemID: trash.id, stackID: workStack.id)
        store.addItem(SidebarItem(kind: .system, title: "Windows", systemKind: .windowSwitcher), toStack: workStack.id)
        store.addItem(SidebarItem(kind: .stack, title: "Ad hoc", children: []), toStack: workStack.id)

        let updatedStack = try unwrap(store.item(id: workStack.id), "expected stack")
        try expect(updatedStack.children.isEmpty, "expected stack and system items to be rejected as stack children")
        try expect(store.items.contains { $0.id == nestedStack.id }, "expected nested stack to remain a main item")
        try expect(store.items.contains { $0.id == trash.id }, "expected system item to remain a main item")
    }

    private static func testFolderPeekFiltersHiddenFiles() throws {
        let directory = try makeTemporaryDirectory()
        try "visible".write(to: directory.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)
        try "hidden".write(to: directory.appendingPathComponent(".hidden.txt"), atomically: true, encoding: .utf8)

        let entries = FolderPeekService.entries(in: directory)

        try expect(entries.map(\.title) == ["visible.txt"], "expected hidden files filtered")
    }

    private static func testTrashPath() throws {
        try expect(TrashService.trashURL.lastPathComponent == ".Trash", "expected user Trash path")
    }

    private static func testTrashCountResolution() throws {
        try expect(
            TrashService.resolveVisibleItemCount(finderItemCount: 4, fallbackItemCount: 1) == 4,
            "expected Finder count to win"
        )
        try expect(
            TrashService.resolveVisibleItemCount(finderItemCount: nil, fallbackItemCount: 2) == 2,
            "expected filesystem fallback count"
        )
        try expect(
            TrashService.resolveVisibleItemCount(finderItemCount: -1, fallbackItemCount: 2) == 0,
            "expected negative counts clamped"
        )
    }

    private static func testSidebarFrameCalculator() throws {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        try expect(
            SidebarFrameCalculator.frame(screenFrame: screen, edge: .left, thickness: 72, inset: 8)
                == CGRect(x: 8, y: 8, width: 72, height: 884),
            "expected left frame"
        )
        try expect(
            SidebarFrameCalculator.frame(screenFrame: screen, edge: .right, thickness: 72, inset: 8)
                == CGRect(x: 1360, y: 8, width: 72, height: 884),
            "expected right frame"
        )
        try expect(
            SidebarFrameCalculator.frame(screenFrame: screen, edge: .top, thickness: 72, inset: 8)
                == CGRect(x: 8, y: 820, width: 1424, height: 72),
            "expected top frame"
        )
        try expect(
            SidebarFrameCalculator.frame(screenFrame: screen, edge: .bottom, thickness: 72, inset: 8)
                == CGRect(x: 8, y: 8, width: 1424, height: 72),
            "expected bottom frame"
        )
    }

    private static func testSidebarDockLayout() throws {
        let app = SidebarItem(
            kind: .application,
            title: "Finder",
            url: URL(fileURLWithPath: "/Applications/Finder.app"),
            bundleIdentifier: "com.apple.finder"
        )
        let stack = SidebarItem(kind: .stack, title: "Work", children: [])
        let windowSwitcher = SidebarItem.system(.windowSwitcher)
        let calendar = SidebarItem.system(.dateTime)
        let trash = SidebarItem.system(.trash)
        let media = SidebarItem.system(.media)
        let items = [trash, app, media, stack, calendar, windowSwitcher]
        let sections = SidebarDockLayout.sections(from: items)

        try expect(
            sections.stacks.map(\.title) == ["Work"],
            "expected stacks to be first section"
        )
        try expect(
            sections.pinnedItems.map(\.title) == ["Finder"],
            "expected pinned items to be second section"
        )
        try expect(
            sections.finalSystemItems.compactMap(\.systemKind) == [.windowSwitcher, .dateTime, .media, .trash],
            "expected fixed final widget order"
        )
        try expect(
            SidebarDockLayout.trashItem(from: items)?.systemKind == .trash,
            "expected Trash to be extracted"
        )
        try expect(
            SidebarDockLayout.estimatedLength(itemCount: 3, dividerCount: 1, iconSize: 34, spacing: 8) > 0,
            "expected positive dock length"
        )
        try expect(
            SidebarDockLayout.estimatedLength(itemCount: 3, dividerCount: 1, iconSize: 34, spacing: 8)
                == CGFloat(3 * 46 + 1 + 3 * 8 + 20),
            "expected dock length to account for dividers as real layout elements"
        )
        try expect(
            SidebarDockLayout.estimatedLength(
                itemCount: 1,
                dividerCount: 0,
                iconSize: 34,
                spacing: 8,
                mediaControlCount: 1,
                mediaUsesInlineLength: true
            )
                > SidebarDockLayout.estimatedLength(itemCount: 2, dividerCount: 0, iconSize: 34, spacing: 8),
            "expected horizontal inline media to consume extra length"
        )
    }

    private static func testSidebarVisibilityPolicy() throws {
        let windowSwitcher = SidebarItem.system(.windowSwitcher)
        var preferences = SidebarPreferences.defaults

        preferences.windowSwitcherEnabled = true
        try expect(
            SidebarVisibilityPolicy.shouldDisplay(windowSwitcher, preferences: preferences),
            "expected window switcher to display when enabled"
        )

        preferences.windowSwitcherEnabled = false
        try expect(
            !SidebarVisibilityPolicy.shouldDisplay(windowSwitcher, preferences: preferences),
            "expected window switcher to hide when disabled"
        )

        var widgetPreferences = SidebarPreferences.defaults
        widgetPreferences.trashWidgetEnabled = false
        widgetPreferences.dateTimeWidgetEnabled = false
        widgetPreferences.mediaControlsEnabled = false

        try expect(
            !SidebarVisibilityPolicy.shouldDisplay(SidebarItem.system(.trash), preferences: widgetPreferences),
            "expected trash to hide when disabled"
        )
        try expect(
            !SidebarVisibilityPolicy.shouldDisplay(SidebarItem.system(.dateTime), preferences: widgetPreferences),
            "expected calendar to hide when disabled"
        )
        try expect(
            !SidebarVisibilityPolicy.shouldDisplay(SidebarItem.system(.media), preferences: widgetPreferences),
            "expected media to hide when disabled"
        )

        let stack = SidebarItem(kind: .stack, title: "Work", children: [])
        preferences.stacksEnabled = false
        try expect(
            !SidebarVisibilityPolicy.shouldDisplay(stack, preferences: preferences),
            "expected stacks to hide when disabled"
        )
    }

    private static func testLoginItemLaunchAgentPlist() throws {
        let appURL = URL(fileURLWithPath: "/Applications/\(AppIdentity.appBundleName)", isDirectory: true)
        let definition = LoginItemService.loginAgentDefinition(appBundleURL: appURL)
        let data = try definition.plistData()
        var format = PropertyListSerialization.PropertyListFormat.xml
        let plist = try unwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: &format) as? [String: Any],
            "expected plist dictionary"
        )

        try expect(plist["Label"] as? String == LoginItemService.label, "expected login item label")
        try expect(plist["RunAtLoad"] as? Bool == true, "expected run at load")
        try expect(plist["KeepAlive"] as? Bool == false, "expected no keep alive")

        let arguments = try unwrap(plist["ProgramArguments"] as? [String], "expected program arguments")
        try expect(arguments == ["/usr/bin/open", "-n", appURL.path], "expected open app arguments")
    }

    private static func testDockAutohideOutputParsing() throws {
        try expect(
            DockVisibilitySnapshot.parseDefaultsOutput("1\n", terminationStatus: 0) == .enabled,
            "expected 1 to mean enabled"
        )
        try expect(
            DockVisibilitySnapshot.parseDefaultsOutput("false\n", terminationStatus: 0) == .disabled,
            "expected false to mean disabled"
        )
        try expect(
            DockVisibilitySnapshot.parseDefaultsOutput("", terminationStatus: 1) == .missing,
            "expected failed defaults read to mean missing"
        )
    }

    private static func testDockSnapshotV2CommandPlan() throws {
        let snapshot = DockVisibilitySnapshotV2(
            autohide: .bool(false),
            autohideDelay: .number(0.25),
            autohideTimeModifier: .missing,
            createdByProcessID: 123
        )

        let restoreCommands = DockVisibilitySnapshotV2.restoreCommands(for: snapshot)

        try expect(
            restoreCommands == [
                DockPreferenceCommand(
                    executablePath: "/usr/bin/defaults",
                    arguments: ["write", "com.apple.dock", "autohide", "-bool", "false"]
                ),
                DockPreferenceCommand(
                    executablePath: "/usr/bin/defaults",
                    arguments: ["write", "com.apple.dock", "autohide-delay", "-float", "0.25"]
                ),
                DockPreferenceCommand(
                    executablePath: "/usr/bin/defaults",
                    arguments: ["delete", "com.apple.dock", "autohide-time-modifier"]
                ),
                DockPreferenceCommand(executablePath: "/usr/bin/killall", arguments: ["Dock"]),
            ],
            "expected restore command plan"
        )

        try expect(
            DockVisibilitySnapshotV2.hideCommands.contains(
                DockPreferenceCommand(
                    executablePath: "/usr/bin/defaults",
                    arguments: ["write", "com.apple.dock", "autohide-delay", "-float", "1000"]
                )
            ),
            "expected strict Tahoe Dock delay command"
        )
    }

    private static func testLegacyDockSnapshotConverts() throws {
        let legacy = DockVisibilitySnapshot(
            originalAutohideState: .disabled,
            createdByProcessID: 456
        )
        let snapshot = DockVisibilitySnapshotV2(legacy: legacy)

        try expect(snapshot.autohide == .bool(false), "expected disabled legacy autohide")
        try expect(snapshot.autohideDelay == .missing, "expected missing legacy delay")
        try expect(snapshot.autohideTimeModifier == .missing, "expected missing legacy time modifier")
    }

    private static func testPanelPreferenceDiff() throws {
        let defaults = SidebarPreferences.defaults
        var iconSized = defaults
        iconSized.iconSize = 48

        let iconDiff = PanelPreferenceDiff(oldValue: defaults, newValue: iconSized)
        try expect(iconDiff.requiresFrameUpdate, "expected icon size to update frame")
        try expect(!iconDiff.requiresRebuild, "expected icon size to avoid rebuild")

        var displayScoped = defaults
        displayScoped.showOnAllDisplays = false
        try expect(
            PanelPreferenceDiff(oldValue: defaults, newValue: displayScoped).requiresRebuild,
            "expected display scope to rebuild panels"
        )

        var dockOnly = defaults
        dockOnly.hideSystemDock = true
        let dockDiff = PanelPreferenceDiff(oldValue: defaults, newValue: dockOnly)
        try expect(!dockDiff.requiresRebuild, "expected dock setting to avoid rebuild")
        try expect(!dockDiff.requiresFrameUpdate, "expected dock setting to avoid frame update")

        var delayedReveal = defaults
        delayedReveal.bottomRevealDelayMilliseconds = 80
        let delayDiff = PanelPreferenceDiff(oldValue: defaults, newValue: delayedReveal)
        try expect(delayDiff.requiresVisibilityUpdate, "expected bottom reveal delay to update visibility behavior")
        try expect(!delayDiff.requiresRebuild, "expected bottom reveal delay to avoid rebuild")
        try expect(!delayDiff.requiresFrameUpdate, "expected bottom reveal delay to avoid frame update")
    }

    private static func testPanelRevealPolicyBottomEdge() throws {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

        try expect(
            !PanelRevealPolicy.shouldRevealHidden(
                edge: .bottom,
                screenFrame: screen,
                mouseLocation: CGPoint(x: 720, y: 1)
            ),
            "expected bottom reveal to reject mouse above exact edge"
        )

        try expect(
            PanelRevealPolicy.shouldRevealHidden(
                edge: .bottom,
                screenFrame: screen,
                mouseLocation: CGPoint(x: 720, y: 0)
            ),
            "expected bottom reveal at exact screen minY"
        )

        try expect(
            !PanelRevealPolicy.shouldRevealHidden(
                edge: .bottom,
                screenFrame: screen,
                mouseLocation: CGPoint(x: 720, y: -1)
            ),
            "expected bottom reveal to reject mouse outside the screen"
        )
    }

    private static func testPanelRevealPolicyVisibleHold() throws {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let panel = CGRect(x: 8, y: 8, width: 1424, height: 72)

        try expect(
            PanelRevealPolicy.shouldHoldVisible(
                panelFrame: panel,
                screenFrame: screen,
                mouseLocation: CGPoint(x: 48, y: 20)
            ),
            "expected visible panel to hold while mouse is inside panel"
        )

        try expect(
            !PanelRevealPolicy.shouldHoldVisible(
                panelFrame: panel,
                screenFrame: screen,
                mouseLocation: CGPoint(x: 48, y: 120)
            ),
            "expected visible hold to stop outside interaction margin"
        )
    }

    @MainActor
    private static func testSidebarRecursiveAppMatching() throws {
        let fileURL = try makeTemporaryDirectory().appendingPathComponent("SidebarItems.json")
        let store = SidebarItemStore(fileURL: fileURL, legacyPinnedItemsURL: fileURL.deletingLastPathComponent().appendingPathComponent("missing.json"))
        store.clear()

        let stack = store.createStack(title: "Work")
        let app = SidebarItem(
            kind: .application,
            title: "Mail",
            url: URL(fileURLWithPath: "/Applications/Mail.app"),
            bundleIdentifier: "com.apple.mail"
        )
        store.addItem(app, toStack: stack.id)

        try expect(
            store.containsApplication(bundleIdentifier: "com.apple.mail", url: nil),
            "expected app child to match by bundle id"
        )
        try expect(
            store.containsApplication(bundleIdentifier: nil, url: URL(fileURLWithPath: "/Applications/Mail.app")),
            "expected app child to match by url"
        )
        try expect(
            !store.containsApplication(bundleIdentifier: "com.apple.Safari", url: nil),
            "expected unrelated app not to match"
        )
    }

    private static func testDockBadgeParsing() throws {
        try expect(
            DockBadgeParser.extractBadgeText(from: ["Mail", "3"], appName: "Mail") == "3",
            "expected pure numeric status label"
        )
        try expect(
            DockBadgeParser.extractBadgeText(from: ["WhatsApp", "1"], appName: "WhatsApp") == "1",
            "expected dock status label to become badge text"
        )
        try expect(
            DockBadgeParser.extractBadgeText(
                for: "\u{200E}WhatsApp",
                from: [
                    ["WhatsApp", "1"],
                    ["System Settings", "1"],
                ]
            ) == "1",
            "expected hidden unicode app name marker to match dock title"
        )
        try expect(
            DockBadgeParser.extractBadgeText(from: ["WhatsApp, 1 notification"], appName: "\u{200E}WhatsApp") == "1",
            "expected notification context to match hidden unicode app name marker"
        )
        try expect(
            DockBadgeParser.extractBadgeText(from: ["Slack, 12 notifications"], appName: "Slack") == "12",
            "expected notification label"
        )
        try expect(
            DockBadgeParser.extractBadgeText(from: ["Calendar"], appName: "Calendar") == nil,
            "expected no badge for plain app title"
        )
        try expect(
            DockBadgeParser.extractBadgeText(
                for: "Arc",
                from: [
                    ["WhatsApp", "1"],
                    ["Arc"],
                ]
            ) == nil,
            "expected other app badge groups not to leak"
        )
    }

    private static func testAppContextMenuModel() throws {
        try expect(
            AppContextMenuModel.moveToItemTitles(displayNames: ["Built-in", "Studio"], accessibilityTrusted: true) == ["Built-in", "Studio"],
            "expected display move entries"
        )
        try expect(
            AppContextMenuModel.moveToItemTitles(displayNames: ["Built-in", "Studio"], accessibilityTrusted: false) == ["Enable Accessibility"],
            "expected accessibility fallback"
        )
        try expect(
            AppContextMenuModel.moveToItemTitles(displayNames: ["Built-in"], accessibilityTrusted: true).isEmpty,
            "expected no move menu for one display"
        )
    }

    private static func testWindowMoveGeometry() throws {
        let frames = [
            CGRect(x: 100, y: 100, width: 400, height: 300),
            CGRect(x: 550, y: 120, width: 200, height: 200),
        ]
        let destination = CGRect(x: 1440, y: 0, width: 1200, height: 800)

        let relocated = WindowMoveGeometry.relocatedFrames(frames, to: destination)

        try expect(
            relocated == [
                CGRect(x: 1440, y: 0, width: 400, height: 300),
                CGRect(x: 1890, y: 20, width: 200, height: 200),
            ],
            "expected windows to preserve relative layout"
        )

        let clamped = WindowMoveGeometry.relocatedFrames(
            [CGRect(x: 0, y: 0, width: 500, height: 200)],
            to: CGRect(x: 100, y: 50, width: 300, height: 300)
        )

        try expect(
            clamped == [CGRect(x: 100, y: 50, width: 500, height: 200)],
            "expected oversized window origin to clamp into destination"
        )
    }

    private static func testScreenCoordinateConversion() throws {
        let primaryHeight: CGFloat = 1080

        // A rect at the Cocoa origin (bottom-left of the primary display) maps to
        // the bottom of the primary display in Quartz (top-left) coordinates.
        let bottomLeft = ScreenCoordinateConverter.quartzFrame(
            fromCocoa: CGRect(x: 0, y: 0, width: 1440, height: 900),
            primaryDisplayHeight: primaryHeight
        )
        try expect(
            bottomLeft == CGRect(x: 0, y: 180, width: 1440, height: 900),
            "expected Cocoa bottom-left rect to flip into Quartz top-left"
        )

        // A display stacked above the primary has a positive Cocoa Y but a negative
        // Quartz Y, since Quartz grows downward from the primary's top-left.
        let secondaryAbove = ScreenCoordinateConverter.quartzFrame(
            fromCocoa: CGRect(x: 0, y: 1080, width: 1920, height: 1080),
            primaryDisplayHeight: primaryHeight
        )
        try expect(
            secondaryAbove == CGRect(x: 0, y: -1080, width: 1920, height: 1080),
            "expected a display above the primary to map to negative Quartz Y"
        )

        // X offset and size are preserved across the conversion.
        let offsetRight = ScreenCoordinateConverter.quartzFrame(
            fromCocoa: CGRect(x: 1440, y: 0, width: 1280, height: 800),
            primaryDisplayHeight: primaryHeight
        )
        try expect(
            offsetRight == CGRect(x: 1440, y: 280, width: 1280, height: 800),
            "expected X and size to be preserved"
        )
    }

    private static func testWindowPreviewGridLayout() throws {
        let wideSize = CGSize(width: 760, height: 420)

        try expect(
            WindowPreviewGridLayout.metrics(itemCount: 0, availableSize: wideSize)
                == WindowPreviewGridMetrics(displayedItemCount: 0, columns: 0, rows: 0),
            "expected empty preview layout for zero windows"
        )

        try expect(
            WindowPreviewGridLayout.metrics(itemCount: 1, availableSize: wideSize)
                == WindowPreviewGridMetrics(displayedItemCount: 1, columns: 1, rows: 1),
            "expected one window to fill the preview"
        )

        try expect(
            WindowPreviewGridLayout.metrics(itemCount: 2, availableSize: wideSize)
                == WindowPreviewGridMetrics(displayedItemCount: 2, columns: 2, rows: 1),
            "expected two windows to share the preview evenly"
        )

        try expect(
            WindowPreviewGridLayout.metrics(itemCount: 12, availableSize: wideSize)
                == WindowPreviewGridMetrics(displayedItemCount: 10, columns: 4, rows: 3),
            "expected preview layout to cap at ten windows"
        )
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw TestFailure(description: message)
        }
    }

    private static func unwrap<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else {
            throw TestFailure(description: message)
        }

        return value
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenDockTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
