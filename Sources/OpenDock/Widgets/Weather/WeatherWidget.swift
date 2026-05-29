import SwiftUI

struct WeatherWidgetDefinition: WidgetDefinition {
    let manifest = WidgetManifestLoader.requireBundledManifest(id: .weather)

    @MainActor
    func makeDockView(context: WidgetContext) -> AnyView {
        AnyView(
            WeatherSidebarIcon(
                iconSize: context.iconSize,
                appModel: context.appModel
            )
        )
    }

    @MainActor
    func makeContextMenu(context: WidgetContext) -> AnyView {
        AnyView(WeatherWidgetContextMenu(appModel: context.appModel))
    }

    @MainActor
    func performPrimaryAction(context: WidgetContext) {
        context.appModel.refreshWeather()
    }
}

private struct WeatherWidgetContextMenu: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Button {
            appModel.refreshWeather()
        } label: {
            Label("Refresh Weather", systemImage: "arrow.clockwise")
        }
    }
}
