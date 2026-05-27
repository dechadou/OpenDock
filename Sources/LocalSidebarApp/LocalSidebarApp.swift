import AppKit
import LocalSidebarCore
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
struct LocalSidebarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("LocalSidebar", systemImage: "sidebar.left") {
            MenuBarContent(appModel: appDelegate.appModel)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(appModel: appDelegate.appModel)
                .frame(width: 420)
        }
    }
}
