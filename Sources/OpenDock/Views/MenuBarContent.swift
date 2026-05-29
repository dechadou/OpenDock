import AppKit
import SwiftUI

public struct MenuBarContent: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow

    public init(appModel: AppModel) {
        self.appModel = appModel
    }

    public var body: some View {
        Button {
            appModel.toggleSidebar()
        } label: {
            Label(appModel.isSidebarVisible ? "Hide Dock" : "Show Dock", systemImage: "dock.rectangle")
        }
        .keyboardShortcut("s", modifiers: [.command, .option])

        Button {
            appModel.openLauncher()
        } label: {
            Label("Open Launcher", systemImage: "magnifyingglass")
        }
        .keyboardShortcut(.space, modifiers: [.command, .option])

        Button {
            appModel.openWindowSwitcher()
        } label: {
            Label("Open Windows", systemImage: "rectangle.on.rectangle")
        }
        .disabled(!appModel.preferencesStore.preferences.windowSwitcherEnabled)

        Divider()

        Button {
            appModel.createStack()
        } label: {
            Label("New Stack", systemImage: "square.stack.3d.up")
        }
        .disabled(!appModel.preferencesStore.preferences.stacksEnabled)

        Menu {
            Button {
                appModel.pinFrontmostApplication()
            } label: {
                Label("Frontmost App", systemImage: "pin")
            }

            Button {
                appModel.chooseApplicationToPin()
            } label: {
                Label("Application...", systemImage: "app.dashed")
            }

            Button {
                appModel.chooseFileOrFolderPins()
            } label: {
                Label("File or Folder...", systemImage: "folder.badge.plus")
            }

            Button {
                appModel.promptForURLPin()
            } label: {
                Label("URL...", systemImage: "link")
            }
        } label: {
            Label("Pin", systemImage: "plus.circle")
        }

        Divider()

        Button {
            appModel.applicationScanner.reload()
            appModel.runningAppService.refresh()
        } label: {
            Label("Refresh Applications", systemImage: "arrow.clockwise")
        }

        Divider()

        Button {
            openSettings()
            appModel.bringSettingsWindowToFront()
            DispatchQueue.main.async {
                appModel.bringSettingsWindowToFront()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                appModel.bringSettingsWindowToFront()
            }
        } label: {
            Label("Settings", systemImage: "gearshape")
        }

        Button {
            openWindow(id: "about")
            NSApp.activate(ignoringOtherApps: true)
        } label: {
            Label("About OpenDock", systemImage: "info.circle")
        }

        Button {
            NSWorkspace.shared.open(AppIdentity.githubProfileURL)
        } label: {
            Label("GitHub Profile", systemImage: "person.crop.circle")
        }

        Button {
            NSWorkspace.shared.open(AppIdentity.githubRepositoryURL)
        } label: {
            Label("Open Repository", systemImage: "curlybraces")
        }

        Divider()

        Button {
            NSApp.terminate(nil)
        } label: {
            Label("Quit \(AppIdentity.displayName)", systemImage: "power")
        }
        .keyboardShortcut("q")
    }
}
