import SwiftUI

struct DateTimeWidgetDefinition: WidgetDefinition {
    let manifest = WidgetManifestLoader.requireBundledManifest(id: .dateTime)

    @MainActor
    func makeDockView(context: WidgetContext) -> AnyView {
        AnyView(DateTimeSidebarIcon(iconSize: context.iconSize))
    }

    @MainActor
    func makeContextMenu(context: WidgetContext) -> AnyView {
        AnyView(
            Button("Open Calendar") {
                context.presentCalendar()
            }
        )
    }

    @MainActor
    func performPrimaryAction(context: WidgetContext) {
        context.presentCalendar()
    }
}
