import SwiftUI

struct MediaWidgetDefinition: WidgetDefinition {
    let manifest = WidgetManifestLoader.requireBundledManifest(id: .media)

    var usesCustomDockInteraction: Bool {
        true
    }

    @MainActor
    func makeDockView(context: WidgetContext) -> AnyView {
        AnyView(
            MediaSidebarPill(
                iconSize: context.iconSize,
                edge: context.edge,
                appModel: context.appModel
            )
        )
    }

    @MainActor
    func makeContextMenu(context: WidgetContext) -> AnyView {
        AnyView(MediaWidgetContextMenu(appModel: context.appModel))
    }

    @MainActor
    func performPrimaryAction(context: WidgetContext) {
        context.appModel.openCurrentMediaApplication()
    }
}

private struct MediaWidgetContextMenu: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Button {
            appModel.openCurrentMediaApplication()
        } label: {
            Label("Open \(appModel.mediaPlaybackInfo?.appName ?? "Media App")", systemImage: "arrow.up.forward.app")
        }

        Divider()

        Button {
            appModel.sendMediaCommand(.previous)
        } label: {
            Label("Previous", systemImage: "backward.fill")
        }

        Button {
            appModel.sendMediaCommand(.playPause)
        } label: {
            Label("Play/Pause", systemImage: "playpause.fill")
        }

        Button {
            appModel.sendMediaCommand(.next)
        } label: {
            Label("Next", systemImage: "forward.fill")
        }
    }
}
