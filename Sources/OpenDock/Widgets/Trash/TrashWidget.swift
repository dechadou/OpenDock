import SwiftUI

struct TrashWidgetDefinition: WidgetDefinition {
    let manifest = WidgetManifestLoader.requireBundledManifest(id: .trash)

    @MainActor
    func makeDockView(context: WidgetContext) -> AnyView {
        AnyView(TrashSidebarIcon(iconSize: context.iconSize))
    }

    @MainActor
    func makeContextMenu(context: WidgetContext) -> AnyView {
        AnyView(TrashWidgetContextMenu(appModel: context.appModel))
    }

    @MainActor
    func performPrimaryAction(context _: WidgetContext) {
        TrashService.openTrash()
    }
}

private struct TrashWidgetContextMenu: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Button {
            TrashService.openTrash()
        } label: {
            Label("Open Trash", systemImage: "trash")
        }

        Button {
            appModel.emptyTrashWithConfirmation()
        } label: {
            Label("Empty Trash", systemImage: "trash.slash")
        }
    }
}
