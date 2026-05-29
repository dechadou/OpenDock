import AppKit
import SwiftUI

struct AppContextMenuBridge: NSViewRepresentable {
    var menuProvider: () -> NSMenu
    var onMenuVisibilityChanged: (Bool) -> Void

    init(
        menuProvider: @escaping () -> NSMenu,
        onMenuVisibilityChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.menuProvider = menuProvider
        self.onMenuVisibilityChanged = onMenuVisibilityChanged
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> ContextMenuCaptureView {
        let view = ContextMenuCaptureView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ContextMenuCaptureView, context: Context) {
        context.coordinator.parent = self
        nsView.coordinator = context.coordinator
    }

    @MainActor
    final class Coordinator: NSObject, NSMenuDelegate {
        var parent: AppContextMenuBridge
        private var menuVisible = false

        init(parent: AppContextMenuBridge) {
            self.parent = parent
        }

        func showMenu(with event: NSEvent, in view: NSView) {
            let menu = parent.menuProvider()
            menu.delegate = self
            setMenuVisible(true)
            NSMenu.popUpContextMenu(menu, with: event, for: view)
            setMenuVisible(false)
        }

        func menuDidClose(_ menu: NSMenu) {
            setMenuVisible(false)
        }

        private func setMenuVisible(_ visible: Bool) {
            guard menuVisible != visible else {
                return
            }

            menuVisible = visible
            parent.onMenuVisibilityChanged(visible)
        }
    }
}

@MainActor
final class ContextMenuCaptureView: NSView {
    weak var coordinator: AppContextMenuBridge.Coordinator?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard NSApp.currentEvent?.type == .rightMouseDown else {
            return nil
        }

        return super.hitTest(point)
    }

    override func rightMouseDown(with event: NSEvent) {
        coordinator?.showMenu(with: event, in: self)
    }
}

@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, systemImage: String? = nil, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        if let systemImage {
            image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
            image?.isTemplate = true
        }
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}

enum AppContextMenuFactory {
    @MainActor
    static func runningAppMenu(
        app: RunningAppInfo,
        appModel: AppModel
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            ClosureMenuItem(
                title: AppContextMenuModel.bringToFrontTitle,
                systemImage: AppContextMenuModel.symbolName(forTitle: AppContextMenuModel.bringToFrontTitle)
            ) {
                appModel.openRunningApp(app)
            })
        menu.addItem(
            ClosureMenuItem(
                title: "Pin App",
                systemImage: AppContextMenuModel.symbolName(forTitle: "Pin App")
            ) {
                appModel.pinRunningApp(app)
            })

        addStackSubmenu(to: menu, app: app, appModel: appModel)
        addMoveToSubmenu(to: menu, app: app, appModel: appModel)

        menu.addItem(.separator())
        menu.addItem(
            ClosureMenuItem(title: "Quit", systemImage: AppContextMenuModel.symbolName(forTitle: "Quit")) {
                appModel.quitRunningApp(app)
            })
        menu.addItem(
            ClosureMenuItem(title: "Force Quit", systemImage: AppContextMenuModel.symbolName(forTitle: "Force Quit")) {
                appModel.quitRunningApp(app, force: true)
            })

        return menu
    }

    @MainActor
    static func pinnedApplicationMenu(
        item: SidebarItem,
        runningApp: RunningAppInfo?,
        appModel: AppModel,
        removeTitle: String = "Remove Pin"
    ) -> NSMenu {
        let menu = NSMenu()

        if let runningApp {
            menu.addItem(
                ClosureMenuItem(
                    title: AppContextMenuModel.bringToFrontTitle,
                    systemImage: AppContextMenuModel.symbolName(forTitle: AppContextMenuModel.bringToFrontTitle)
                ) {
                    appModel.openRunningApp(runningApp)
                })
            menu.addItem(
                ClosureMenuItem(title: removeTitle, systemImage: AppContextMenuModel.symbolName(forTitle: removeTitle)) {
                    appModel.removeSidebarItem(item)
                })
            addStackSubmenu(to: menu, app: runningApp, appModel: appModel)
            addMoveToSubmenu(to: menu, app: runningApp, appModel: appModel)

            menu.addItem(.separator())
            menu.addItem(
                ClosureMenuItem(title: "Quit", systemImage: AppContextMenuModel.symbolName(forTitle: "Quit")) {
                    appModel.quitRunningApp(runningApp)
                })
            menu.addItem(
                ClosureMenuItem(title: "Force Quit", systemImage: AppContextMenuModel.symbolName(forTitle: "Force Quit")) {
                    appModel.quitRunningApp(runningApp, force: true)
                })
        } else {
            menu.addItem(
                ClosureMenuItem(title: "Open", systemImage: AppContextMenuModel.symbolName(forTitle: "Open")) {
                    appModel.handleSidebarItemClick(item)
                })
            menu.addItem(.separator())
            menu.addItem(
                ClosureMenuItem(title: removeTitle, systemImage: AppContextMenuModel.symbolName(forTitle: removeTitle)) {
                    appModel.removeSidebarItem(item)
                })
        }

        addSpaceMenuItems(to: menu, item: item, appModel: appModel)

        return menu
    }

    @MainActor
    static func stackChildApplicationMenu(
        child: SidebarItem,
        stackID: SidebarItem.ID,
        runningApp: RunningAppInfo?,
        appModel: AppModel
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            ClosureMenuItem(title: "Open", systemImage: AppContextMenuModel.symbolName(forTitle: "Open")) {
                appModel.handleSidebarItemClick(child)
            })
        menu.addItem(
            ClosureMenuItem(
                title: "Move Out of Stack",
                systemImage: AppContextMenuModel.symbolName(forTitle: "Move Out of Stack")
            ) {
                appModel.moveChildOutOfStack(childID: child.id, stackID: stackID)
            })

        if let runningApp {
            addMoveToSubmenu(to: menu, app: runningApp, appModel: appModel)
        }

        menu.addItem(.separator())
        menu.addItem(
            ClosureMenuItem(title: "Remove", systemImage: AppContextMenuModel.symbolName(forTitle: "Remove")) {
                appModel.removeSidebarItem(child)
            })

        return menu
    }

    @MainActor
    static func launchableApplicationMenu(
        application: LaunchableApplication,
        runningApp: RunningAppInfo?,
        appModel: AppModel
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            ClosureMenuItem(title: "Open", systemImage: AppContextMenuModel.symbolName(forTitle: "Open")) {
                appModel.openLaunchableApplication(application)
            })
        menu.addItem(
            ClosureMenuItem(title: "Pin App", systemImage: AppContextMenuModel.symbolName(forTitle: "Pin App")) {
                appModel.pinLaunchableApplication(application)
            })

        if let runningApp {
            addMoveToSubmenu(to: menu, app: runningApp, appModel: appModel)
        }

        menu.addItem(
            ClosureMenuItem(
                title: "Reveal in Finder",
                systemImage: AppContextMenuModel.symbolName(forTitle: "Reveal in Finder")
            ) {
                AppActionService.revealInFinder(application.url)
            })

        return menu
    }

    @MainActor
    private static func addStackSubmenu(to menu: NSMenu, app: RunningAppInfo, appModel: AppModel) {
        guard !appModel.availableStacks.isEmpty else {
            return
        }

        let submenu = NSMenu()
        for stack in appModel.availableStacks {
            submenu.addItem(
                ClosureMenuItem(title: stack.title, systemImage: "square.stack.3d.up") {
                    appModel.addRunningApp(app, toStack: stack.id)
                })
        }

        let item = submenuItem(title: "Add to Stack", systemImage: AppContextMenuModel.symbolName(forTitle: "Add to Stack"))
        item.submenu = submenu
        menu.addItem(item)
    }

    @MainActor
    private static func addMoveToSubmenu(to menu: NSMenu, app: RunningAppInfo, appModel: AppModel) {
        guard appModel.activeDisplays.count > 1 else {
            return
        }

        let submenu = NSMenu()
        let displays = appModel.activeDisplays
        let titles = AppContextMenuModel.moveToItemTitles(
            displayNames: displays.map(\.name),
            accessibilityTrusted: PermissionService.isAccessibilityTrusted
        )

        if PermissionService.isAccessibilityTrusted {
            for (display, title) in zip(displays, titles) {
                submenu.addItem(
                    ClosureMenuItem(title: title, systemImage: "display") {
                        appModel.moveRunningApp(app, to: display)
                    })
            }
        } else {
            submenu.addItem(
                ClosureMenuItem(
                    title: "Enable Accessibility",
                    systemImage: AppContextMenuModel.symbolName(forTitle: "Enable Accessibility")
                ) {
                    PermissionService.requestAccessibilityPrompt()
                    PermissionService.openAccessibilitySettings()
                })
        }

        let item = submenuItem(title: "Move To", systemImage: AppContextMenuModel.symbolName(forTitle: "Move To"))
        item.submenu = submenu
        menu.addItem(item)
    }

    @MainActor
    private static func addSpaceMenuItems(to menu: NSMenu, item: SidebarItem, appModel: AppModel) {
        menu.addItem(.separator())
        menu.addItem(
            ClosureMenuItem(
                title: "Add Space Before",
                systemImage: AppContextMenuModel.symbolName(forTitle: "Add Space Before")
            ) {
                appModel.addSpace(before: item.id)
            })
        menu.addItem(
            ClosureMenuItem(
                title: "Add Space After",
                systemImage: AppContextMenuModel.symbolName(forTitle: "Add Space After")
            ) {
                appModel.addSpace(after: item.id)
            })
    }

    @MainActor
    private static func submenuItem(title: String, systemImage: String?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        if let systemImage {
            item.image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title)
            item.image?.isTemplate = true
        }
        return item
    }
}

public enum AppContextMenuModel {
    public static let bringToFrontTitle = "Bring to Front"
    public static let previewWindowsTitle = "Preview Windows"
    public static let revealInFinderTitle = "Reveal in Finder"

    public static func runningAppMenuTitles(hasStacks: Bool, hasMoveTo: Bool) -> [String] {
        var titles = [bringToFrontTitle, "Pin App"]

        if hasStacks {
            titles.append("Add to Stack")
        }

        if hasMoveTo {
            titles.append("Move To")
        }

        titles.append(contentsOf: ["Quit", "Force Quit"])
        return titles
    }

    public static func pinnedApplicationMenuTitles(
        isRunning: Bool,
        hasStacks: Bool,
        hasMoveTo: Bool,
        removeTitle: String = "Remove Pin"
    ) -> [String] {
        guard isRunning else {
            return ["Open", removeTitle]
        }

        var titles = [bringToFrontTitle, removeTitle]

        if hasStacks {
            titles.append("Add to Stack")
        }

        if hasMoveTo {
            titles.append("Move To")
        }

        titles.append(contentsOf: ["Quit", "Force Quit"])
        return titles
    }

    public static func moveToItemTitles(
        displayNames: [String],
        accessibilityTrusted: Bool
    ) -> [String] {
        guard displayNames.count > 1 else {
            return []
        }

        guard accessibilityTrusted else {
            return ["Enable Accessibility"]
        }

        return displayNames
    }

    public static func symbolName(forTitle title: String) -> String? {
        switch title {
        case bringToFrontTitle, "Open":
            return "arrow.up.forward.app"
        case "Pin App":
            return "pin"
        case "Remove Pin":
            return "pin.slash"
        case "Add to Stack":
            return "square.stack.3d.up"
        case "Move To":
            return "display.2"
        case "Quit":
            return "power"
        case "Force Quit":
            return "xmark.octagon"
        case "Reveal in Finder", "Open in Finder":
            return "finder"
        case "Move Out of Stack":
            return "arrow.up.left.square"
        case "Remove", "Remove Stack", "Remove Space":
            return "trash"
        case "Enable Accessibility":
            return "lock.shield"
        case "Add Space Before":
            return "arrow.left.to.line"
        case "Add Space After":
            return "arrow.right.to.line"
        default:
            return nil
        }
    }
}

extension View {
    @ViewBuilder
    func conditionalContextMenu<Content: View>(
        _ enabled: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if enabled {
            contextMenu(menuItems: content)
        } else {
            self
        }
    }
}
