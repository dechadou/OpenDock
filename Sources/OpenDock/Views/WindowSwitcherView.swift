import AppKit
import SwiftUI

struct WindowSwitcherView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var windowService: WindowService
    @State private var selection: WindowInfo.ID?
    @Environment(\.sidebarAppearance) private var appearance

    init(appModel: AppModel) {
        self.appModel = appModel
        self._windowService = ObservedObject(initialValue: appModel.windowService)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            permissionBanner
            content
        }
        .foregroundStyle(appearance.primaryText.color)
        .background(appearance.popoverSurface.color)
        .onAppear {
            windowService.refresh()
            selection = windowService.windows.first?.id
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.on.rectangle")
                .foregroundStyle(appearance.secondaryText.color)

            Text("Windows")
                .font(.headline)

            Spacer()

            Button {
                windowService.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if !PermissionService.isAccessibilityTrusted || !PermissionService.isScreenRecordingTrusted {
            VStack(alignment: .leading, spacing: 8) {
                Text("Permissions improve window control and previews.")
                    .font(.caption)
                    .foregroundStyle(appearance.secondaryText.color)

                HStack {
                    if !PermissionService.isAccessibilityTrusted {
                        Button("Accessibility") {
                            PermissionService.requestAccessibilityPrompt()
                            PermissionService.openAccessibilitySettings()
                        }
                    }

                    if !PermissionService.isScreenRecordingTrusted {
                        Button("Screen Recording") {
                            PermissionService.openScreenRecordingSettings()
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            Divider()
        }
    }

    @ViewBuilder
    private var content: some View {
        if windowService.windows.isEmpty {
            ContentUnavailableView("No Windows", systemImage: "rectangle.on.rectangle")
        } else {
            List(windowService.windows, selection: $selection) { window in
                Button {
                    windowService.activate(window)
                    appModel.isWindowSwitcherPresented = false
                } label: {
                    WindowRow(window: window, windowService: windowService)
                }
                .buttonStyle(.plain)
                .tag(window.id)
                .contextMenu {
                    Button(AppContextMenuModel.bringToFrontTitle) {
                        windowService.activate(window)
                    }
                    Button("Close Window") {
                        windowService.close(window)
                    }
                }
            }
            .listStyle(.plain)
            .onKeyPress(.return) {
                activateSelectedWindow()
            }
        }
    }

    private func activateSelectedWindow() -> KeyPress.Result {
        guard let selection,
            let window = windowService.windows.first(where: { $0.id == selection })
        else {
            return .ignored
        }

        windowService.activate(window)
        appModel.isWindowSwitcherPresented = false
        return .handled
    }
}

private struct WindowRow: View {
    var window: WindowInfo
    @ObservedObject var windowService: WindowService
    @Environment(\.sidebarAppearance) private var appearance

    var body: some View {
        HStack(spacing: 12) {
            if let image = windowService.thumbnail(for: window) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 82, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(appearance.widgetBackground.color)
                    .frame(width: 82, height: 52)
                    .overlay(
                        Image(systemName: "macwindow")
                            .foregroundStyle(appearance.secondaryText.color)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(window.displayTitle)
                    .font(.callout)
                    .lineLimit(1)

                Text(window.ownerName)
                    .font(.caption)
                    .foregroundStyle(appearance.secondaryText.color)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.vertical, 5)
    }
}
