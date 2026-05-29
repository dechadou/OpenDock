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
        Button {
            appModel.openWindowSwitcher()
        } label: {
            Label("Open Window Switcher", systemImage: "rectangle.on.rectangle")
        }

        if !PermissionService.isAccessibilityTrusted {
            Button {
                PermissionService.requestAccessibilityPrompt()
                PermissionService.openAccessibilitySettings()
            } label: {
                Label("Enable Accessibility", systemImage: "lock.shield")
            }
        }

        if !PermissionService.isScreenRecordingTrusted {
            Button {
                PermissionService.openScreenRecordingSettings()
            } label: {
                Label("Enable Screen Recording", systemImage: "record.circle")
            }
        }
    }
}
