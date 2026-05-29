import AppKit
import SwiftUI

struct RunningAppSidebarItemView: View {
    var app: RunningAppInfo
    @ObservedObject var appModel: AppModel
    var iconSize: CGFloat
    var edge: SidebarEdge

    @State private var isPreviewPresented = false
    @State private var previewTask: DispatchWorkItem?
    @State private var closeTask: DispatchWorkItem?
    @State private var isIconHovered = false
    @State private var isPreviewHovered = false
    @Environment(\.sidebarAppearance) private var appearance

    var body: some View {
        SidebarIconButton(
            title: app.localizedName,
            icon: AppActionService.icon(for: app),
            iconSize: iconSize,
            isRunning: true,
            isFrontmost: app.isActive,
            badgeText: appModel.badge(for: app)?.text
        ) {
            dismissWindowPreview()
            appModel.openRunningApp(app)
        }
        .onHover { hovering in
            guard appModel.preferencesStore.preferences.windowPreviewsEnabled else {
                return
            }

            isIconHovered = hovering
            if hovering {
                schedulePreviewOpen()
            } else {
                schedulePreviewClose()
            }
        }
        .popover(isPresented: previewBinding, arrowEdge: arrowEdge) {
            WindowPreviewView(
                app: app,
                appModel: appModel,
                onDismiss: {
                    dismissWindowPreview()
                },
                onHoverChanged: { hovering in
                    isPreviewHovered = hovering
                    if hovering {
                        closeTask?.cancel()
                    } else {
                        schedulePreviewClose()
                    }
                }
            )
            .frame(
                width: WindowPreviewView.preferredSize.width,
                height: WindowPreviewView.preferredSize.height
            )
            .environment(\.sidebarAppearance, appearance)
        }
        .onDrag {
            if let bundleURL = app.bundleURL {
                return DragDropService.itemProvider(forFileURL: bundleURL)
            }

            return NSItemProvider(object: app.localizedName as NSString)
        }
        .onDisappear {
            dismissWindowPreview()
        }
        .overlay {
            AppContextMenuBridge(
                menuProvider: {
                    AppContextMenuFactory.runningAppMenu(
                        app: app,
                        appModel: appModel
                    )
                },
                onMenuVisibilityChanged: { visible in
                    appModel.setSidebarInteractionSurface("menu-\(app.id)", visible: visible)
                }
            )
        }
    }

    private var arrowEdge: Edge {
        edge.popoverArrowEdge
    }

    private func schedulePreviewOpen() {
        closeTask?.cancel()
        previewTask?.cancel()

        guard !isPreviewPresented else {
            return
        }

        let task = DispatchWorkItem {
            guard isIconHovered,
                appModel.preferencesStore.preferences.windowPreviewsEnabled
            else {
                return
            }

            appModel.windowService.refresh()
            setPreviewPresented(true)
        }
        previewTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + WindowPreviewTiming.openDelay, execute: task)
    }

    private func schedulePreviewClose() {
        previewTask?.cancel()
        closeTask?.cancel()

        let task = DispatchWorkItem {
            if !isIconHovered && !isPreviewHovered {
                setPreviewPresented(false)
            }
        }
        closeTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + WindowPreviewTiming.closeDelay, execute: task)
    }

    private var previewBinding: Binding<Bool> {
        Binding(
            get: { isPreviewPresented },
            set: { setPreviewPresented($0) }
        )
    }

    private func setPreviewPresented(_ presented: Bool) {
        isPreviewPresented = presented
        appModel.setSidebarInteractionSurface("preview-\(app.id)", visible: presented)
    }

    private func dismissWindowPreview() {
        previewTask?.cancel()
        closeTask?.cancel()
        isIconHovered = false
        isPreviewHovered = false
        setPreviewPresented(false)
    }
}
