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

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
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
        appModel: AppModel,
        previewWindows: @escaping () -> Void
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(
            ClosureMenuItem(title: "Activate") {
                appModel.openRunningApp(app)
            })
        menu.addItem(
            ClosureMenuItem(title: "Pin App") {
                appModel.pinRunningApp(app)
            })

        addStackSubmenu(to: menu, app: app, appModel: appModel)
        addMoveToSubmenu(to: menu, app: app, appModel: appModel)

        menu.addItem(
            ClosureMenuItem(title: "Preview Windows") {
                previewWindows()
            })

        if let bundleURL = app.bundleURL {
            menu.addItem(
                ClosureMenuItem(title: "Reveal in Finder") {
                    AppActionService.revealInFinder(bundleURL)
                })
        }

        menu.addItem(.separator())
        menu.addItem(
            ClosureMenuItem(title: "Quit") {
                appModel.quitRunningApp(app)
            })
        menu.addItem(
            ClosureMenuItem(title: "Force Quit") {
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
        menu.addItem(
            ClosureMenuItem(title: "Open") {
                appModel.handleSidebarItemClick(item)
            })

        if let runningApp {
            addMoveToSubmenu(to: menu, app: runningApp, appModel: appModel)
        }

        if let url = item.url, url.isFileURL {
            menu.addItem(
                ClosureMenuItem(title: "Reveal in Finder") {
                    AppActionService.revealInFinder(url)
                })
        }

        menu.addItem(.separator())
        menu.addItem(
            ClosureMenuItem(title: removeTitle) {
                appModel.removeSidebarItem(item)
            })

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
            ClosureMenuItem(title: "Open") {
                appModel.handleSidebarItemClick(child)
            })
        menu.addItem(
            ClosureMenuItem(title: "Move Out of Stack") {
                appModel.moveChildOutOfStack(childID: child.id, stackID: stackID)
            })

        if let runningApp {
            addMoveToSubmenu(to: menu, app: runningApp, appModel: appModel)
        }

        if let url = child.url, url.isFileURL {
            menu.addItem(
                ClosureMenuItem(title: "Reveal in Finder") {
                    AppActionService.revealInFinder(url)
                })
        }

        menu.addItem(.separator())
        menu.addItem(
            ClosureMenuItem(title: "Remove") {
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
            ClosureMenuItem(title: "Open") {
                appModel.openLaunchableApplication(application)
            })
        menu.addItem(
            ClosureMenuItem(title: "Pin App") {
                appModel.pinLaunchableApplication(application)
            })

        if let runningApp {
            addMoveToSubmenu(to: menu, app: runningApp, appModel: appModel)
        }

        menu.addItem(
            ClosureMenuItem(title: "Reveal in Finder") {
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
                ClosureMenuItem(title: stack.title) {
                    appModel.addRunningApp(app, toStack: stack.id)
                })
        }

        let item = NSMenuItem(title: "Add to Stack", action: nil, keyEquivalent: "")
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
                    ClosureMenuItem(title: title) {
                        appModel.moveRunningApp(app, to: display)
                    })
            }
        } else {
            submenu.addItem(
                ClosureMenuItem(title: "Enable Accessibility") {
                    PermissionService.requestAccessibilityPrompt()
                    PermissionService.openAccessibilitySettings()
                })
        }

        let item = NSMenuItem(title: "Move To", action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(item)
    }
}

public enum AppContextMenuModel {
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
