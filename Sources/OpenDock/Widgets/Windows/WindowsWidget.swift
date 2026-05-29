import AppKit
import SwiftUI

struct WindowsWidgetDefinition: WidgetDefinition {
    let manifest = WidgetManifestLoader.requireBundledManifest(id: .windows)

    @MainActor
    func makeDockView(context: WidgetContext) -> AnyView {
        AnyView(
            SidebarIconButtonLabel(
                icon: .openDockSymbol(manifest.systemImage),
                iconSize: context.iconSize
            )
        )
    }

    @MainActor
    func makeContextMenu(context: WidgetContext) -> AnyView {
        AnyView(WindowsWidgetContextMenu(appModel: context.appModel))
    }

    @MainActor
    func performPrimaryAction(context: WidgetContext) {
        context.appModel.openWindowSwitcher()
    }
}

private struct WindowsWidgetContextMenu: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Button("Open Window Switcher") {
            appModel.openWindowSwitcher()
        }

        if !PermissionService.isAccessibilityTrusted {
            Button("Enable Accessibility") {
                PermissionService.requestAccessibilityPrompt()
                PermissionService.openAccessibilitySettings()
            }
        }

        if !PermissionService.isScreenRecordingTrusted {
            Button("Enable Screen Recording") {
                PermissionService.openScreenRecordingSettings()
            }
        }
    }
}
