import AppKit
import OpenDockCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appModel = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appModel.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appModel.stop()
    }
}

@main
@MainActor
struct OpenDockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(AppIdentity.displayName, systemImage: "sidebar.left") {
            MenuBarContent(appModel: appDelegate.appModel)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(appModel: appDelegate.appModel)
                .frame(width: 940, height: 680)
        }

        Window("About OpenDock", id: "about") {
            AboutView()
        }
    }
}
