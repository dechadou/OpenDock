import AppKit
import SwiftUI

public struct MenuBarContent: View {
    @ObservedObject var appModel: AppModel

    public init(appModel: AppModel) {
        self.appModel = appModel
    }

    public var body: some View {
        Button(appModel.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
            appModel.toggleSidebar()
        }
        .keyboardShortcut("s", modifiers: [.command, .option])

        Button("Open Launcher") {
            appModel.openLauncher()
        }
        .keyboardShortcut(.space, modifiers: [.command, .option])

        Button("Open Windows") {
            appModel.openWindowSwitcher()
        }
        .disabled(!appModel.preferencesStore.preferences.windowSwitcherEnabled)

        Divider()

        Button("New Stack") {
            appModel.createStack()
        }

        Button("Pin Frontmost App") {
            appModel.pinFrontmostApplication()
        }

        Button("Pin Application...") {
            appModel.chooseApplicationToPin()
        }

        Button("Pin File or Folder...") {
            appModel.chooseFileOrFolderPins()
        }

        Button("Pin URL...") {
            appModel.promptForURLPin()
        }

        Divider()

        Button("Refresh Applications") {
            appModel.applicationScanner.reload()
            appModel.runningAppService.refresh()
        }

        SettingsLink {
            Text("Settings")
        }

        Divider()

        Button("Quit LocalSidebar") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
