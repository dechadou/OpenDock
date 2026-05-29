import SwiftUI

struct VolumeWidgetDefinition: WidgetDefinition {
    let manifest = WidgetManifestLoader.requireBundledManifest(id: .volume)

    var usesCustomDockInteraction: Bool {
        true
    }

    @MainActor
    func makeDockView(context: WidgetContext) -> AnyView {
        AnyView(
            VolumeSidebarControl(
                iconSize: context.iconSize,
                edge: context.edge,
                appModel: context.appModel
            )
        )
    }

    @MainActor
    func makeContextMenu(context: WidgetContext) -> AnyView {
        AnyView(VolumeWidgetContextMenu(appModel: context.appModel))
    }

    @MainActor
    func performPrimaryAction(context: WidgetContext) {
        context.appModel.toggleOutputMute()
    }
}

private struct VolumeWidgetContextMenu: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Button {
            appModel.toggleOutputMute()
        } label: {
            Label(appModel.volumeState.isMuted ? "Unmute" : "Mute", systemImage: appModel.volumeState.isMuted ? "speaker.wave.2" : "speaker.slash")
        }
        .disabled(!appModel.volumeState.isMuteSettable)

        Button {
            appModel.refreshVolumeState()
        } label: {
            Label("Refresh Volume", systemImage: "arrow.clockwise")
        }
    }
}
