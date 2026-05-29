import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SidebarItemView: View {
    var item: SidebarItem
    @ObservedObject var appModel: AppModel
    var iconSize: CGFloat
    var edge: SidebarEdge

    @State private var isStackPresented = false
    @State private var isFolderPresented = false
    @State private var isCalendarPresented = false
    @State private var isPreviewPresented = false
    @State private var previewTask: DispatchWorkItem?
    @State private var closeTask: DispatchWorkItem?
    @State private var isIconHovered = false
    @State private var isPreviewHovered = false
    @Environment(\.sidebarAppearance) private var appearance

    var body: some View {
        interactiveContent
            .help(item.title)
            .onHover { hovering in
                handlePreviewHover(hovering)
            }
            .conditionalContextMenu(item.kind != .application) {
                contextMenu
            }
            .overlay {
                if item.kind == .application {
                    AppContextMenuBridge(
                        menuProvider: {
                            AppContextMenuFactory.pinnedApplicationMenu(
                                item: item,
                                runningApp: appModel.runningApp(for: item),
                                appModel: appModel
                            )
                        },
                        onMenuVisibilityChanged: { visible in
                            appModel.setSidebarInteractionSurface("menu-\(item.id)", visible: visible)
                        }
                    )
                }
            }
            .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
                guard item.kind == .stack else {
                    return false
                }

                return appModel.handleDropIntoStack(providers, stackID: item.id)
            }
            .popover(isPresented: stackBinding, arrowEdge: arrowEdge) {
                StackPopoverView(stack: item, appModel: appModel, iconSize: iconSize)
                    .frame(width: 360, height: 320)
                    .environment(\.sidebarAppearance, appearance)
            }
            .popover(isPresented: folderBinding, arrowEdge: arrowEdge) {
                if let url = item.url {
                    FolderPeekView(folderURL: url, appModel: appModel)
                        .frame(width: 360, height: 420)
                        .environment(\.sidebarAppearance, appearance)
                }
            }
            .popover(isPresented: calendarBinding, arrowEdge: arrowEdge) {
                CalendarPopoverView()
                    .frame(width: 320, height: 300)
                    .environment(\.sidebarAppearance, appearance)
            }
            .popover(isPresented: previewBinding, arrowEdge: arrowEdge) {
                if let runningApp = itemRunningApp {
                    WindowPreviewView(
                        app: runningApp,
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
            }
            .onDisappear {
                setStackPresented(false)
                setFolderPresented(false)
                setCalendarPresented(false)
                dismissWindowPreview()
            }
    }

    @ViewBuilder
    private var interactiveContent: some View {
        if item.kind == .system, item.systemKind == .media {
            MediaSidebarPill(iconSize: iconSize, edge: edge, appModel: appModel)
        } else {
            Button {
                handleClick()
            } label: {
                itemLabel
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var itemLabel: some View {
        if item.kind == .system, item.systemKind == .dateTime {
            DateTimeSidebarIcon(iconSize: iconSize)
        } else if item.kind == .system, item.systemKind == .trash {
            TrashSidebarIcon(iconSize: iconSize)
        } else if item.kind == .stack {
            StackSidebarIcon(stack: item, iconSize: iconSize)
        } else {
            SidebarIconButtonLabel(
                icon: AppActionService.icon(for: item),
                iconSize: iconSize,
                isRunning: itemRunningApp != nil,
                isFrontmost: itemRunningApp?.isActive == true,
                badgeText: appModel.badge(for: item)?.text
            )
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        switch item.kind {
        case .stack:
            Button("Open Stack") {
                setStackPresented(true)
            }
            Divider()
            Button("Remove Stack") {
                appModel.removeSidebarItem(item)
            }
        case .folder:
            Button("Peek Folder") {
                setFolderPresented(true)
            }
            if let url = item.url {
                Button("Open in Finder") {
                    NSWorkspace.shared.open(url)
                }
            }
            Divider()
            Button("Remove Pin") {
                appModel.removeSidebarItem(item)
            }
        case .system:
            systemContextMenu
        default:
            Button("Open") {
                appModel.handleSidebarItemClick(item)
            }
            Divider()
            Button("Remove Pin") {
                appModel.removeSidebarItem(item)
            }
        }
    }

    @ViewBuilder
    private var systemContextMenu: some View {
        switch item.systemKind {
        case .windowSwitcher:
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
        case .trash:
            Button("Open Trash") {
                TrashService.openTrash()
            }
            Button("Empty Trash") {
                appModel.emptyTrashWithConfirmation()
            }
        case .dateTime:
            Button("Open Calendar") {
                setCalendarPresented(true)
            }
        case .media:
            Button("Open \(appModel.mediaPlaybackInfo?.appName ?? "Media App")") {
                appModel.openCurrentMediaApplication()
            }
            Divider()
            Button("Previous") {
                appModel.sendMediaCommand(.previous)
            }
            Button("Play/Pause") {
                appModel.sendMediaCommand(.playPause)
            }
            Button("Next") {
                appModel.sendMediaCommand(.next)
            }
        case nil:
            EmptyView()
        }
    }

    private var itemRunningApp: RunningAppInfo? {
        appModel.runningApp(for: item)
    }

    private var arrowEdge: Edge {
        edge.popoverArrowEdge
    }

    private var previewSurfaceID: String {
        "preview-\(item.id)"
    }

    private func handleClick() {
        if item.kind == .application {
            dismissWindowPreview()
        }

        switch item.kind {
        case .stack:
            setStackPresented(true)
        case .folder:
            if appModel.preferencesStore.preferences.folderPeekEnabled {
                setFolderPresented(true)
            } else {
                appModel.handleSidebarItemClick(item)
            }
        case .system where item.systemKind == .dateTime:
            setCalendarPresented(true)
        default:
            appModel.handleSidebarItemClick(item)
        }
    }

    private func handlePreviewHover(_ hovering: Bool) {
        guard item.kind == .application else {
            return
        }

        guard appModel.preferencesStore.preferences.windowPreviewsEnabled,
            itemRunningApp != nil
        else {
            if !hovering {
                setPreviewPresented(false)
            }
            return
        }

        isIconHovered = hovering
        if hovering {
            schedulePreviewOpen()
        } else {
            schedulePreviewClose()
        }
    }

    private func schedulePreviewOpen() {
        closeTask?.cancel()
        previewTask?.cancel()

        guard !isPreviewPresented else {
            return
        }

        let task = DispatchWorkItem {
            guard isIconHovered,
                appModel.preferencesStore.preferences.windowPreviewsEnabled,
                itemRunningApp != nil
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

    private var stackBinding: Binding<Bool> {
        Binding(
            get: { isStackPresented },
            set: { setStackPresented($0) }
        )
    }

    private var folderBinding: Binding<Bool> {
        Binding(
            get: { isFolderPresented },
            set: { setFolderPresented($0) }
        )
    }

    private var calendarBinding: Binding<Bool> {
        Binding(
            get: { isCalendarPresented },
            set: { setCalendarPresented($0) }
        )
    }

    private var previewBinding: Binding<Bool> {
        Binding(
            get: { isPreviewPresented },
            set: { setPreviewPresented($0) }
        )
    }

    private func setStackPresented(_ presented: Bool) {
        isStackPresented = presented
        appModel.setSidebarInteractionSurface("stack-\(item.id)", visible: presented)
    }

    private func setFolderPresented(_ presented: Bool) {
        isFolderPresented = presented
        appModel.setSidebarInteractionSurface("folder-\(item.id)", visible: presented)
    }

    private func setCalendarPresented(_ presented: Bool) {
        isCalendarPresented = presented
        appModel.setSidebarInteractionSurface("calendar-\(item.id)", visible: presented)
    }

    private func setPreviewPresented(_ presented: Bool) {
        guard !presented || itemRunningApp != nil else {
            return
        }

        isPreviewPresented = presented
        appModel.setSidebarInteractionSurface(previewSurfaceID, visible: presented)
    }

    private func dismissWindowPreview() {
        previewTask?.cancel()
        closeTask?.cancel()
        isIconHovered = false
        isPreviewHovered = false
        setPreviewPresented(false)
    }
}

struct SidebarIconButtonLabel: View {
    var icon: NSImage
    var iconSize: CGFloat
    var isRunning: Bool = false
    var isFrontmost: Bool = false
    var badgeText: String?
    @Environment(\.sidebarAppearance) private var appearance

    var body: some View {
        ZStack {
            if isFrontmost {
                RoundedRectangle(cornerRadius: highlightCornerRadius, style: .continuous)
                    .fill(appearance.activeIconFill.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: highlightCornerRadius, style: .continuous)
                            .stroke(appearance.activeIconBorder.color, lineWidth: 1.4)
                    )
                    .shadow(color: appearance.activeIconGlow.color, radius: 4)
                    .frame(width: highlightSize, height: highlightSize)
            }

            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
        }
        .frame(width: iconSize + 12, height: iconSize + 12)
        .overlay(alignment: .bottom) {
            if isRunning && !isFrontmost {
                Capsule()
                    .fill(appearance.runningIndicator.color)
                    .frame(width: runningDotWidth, height: runningDotHeight)
                    .offset(y: -1)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let badgeText {
                AppBadgeView(text: badgeText, iconSize: iconSize)
                    .offset(x: 4, y: -2)
            }
        }
        .contentShape(Rectangle())
    }

    private var highlightSize: CGFloat {
        iconSize + 10
    }

    private var highlightCornerRadius: CGFloat {
        max(8, iconSize * 0.24)
    }

    private var runningDotWidth: CGFloat {
        max(8, iconSize * 0.22)
    }

    private var runningDotHeight: CGFloat {
        max(3, iconSize * 0.07)
    }
}

private struct StackSidebarIcon: View {
    var stack: SidebarItem
    var iconSize: CGFloat
    @Environment(\.sidebarAppearance) private var appearance

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(appearance.widgetBackground.color)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(appearance.widgetBorder.color, lineWidth: 1))
                .frame(width: iconSize + 6, height: iconSize + 6)

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(iconSize / 2.7), spacing: 2), count: 2), spacing: 2) {
                ForEach(stack.children.prefix(4)) { child in
                    Image(nsImage: AppActionService.icon(for: child))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .frame(width: iconSize, height: iconSize)

            if stack.children.isEmpty {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: iconSize * 0.58))
                    .foregroundStyle(appearance.secondaryText.color)
            }
        }
        .frame(width: iconSize + 12, height: iconSize + 12)
        .contentShape(Rectangle())
    }
}

private struct TrashSidebarIcon: View {
    var iconSize: CGFloat
    @State private var isEmpty = TrashService.fastVisibleItemCount() == 0
    @State private var itemCount = TrashService.fastVisibleItemCount()
    @Environment(\.sidebarAppearance) private var appearance

    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: isEmpty ? "trash" : "trash.fill")
                .font(.system(size: iconSize * 0.72, weight: .regular))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(appearance.primaryText.color)
                .frame(width: iconSize + 12, height: iconSize + 12)
                .contentShape(Rectangle())

            if !isEmpty {
                Circle()
                    .fill(appearance.badgeBackground.color)
                    .frame(width: max(10, iconSize * 0.28), height: max(10, iconSize * 0.28))
                    .overlay(
                        Text(itemCount > 9 ? "9+" : "\(itemCount)")
                            .font(.system(size: max(6, iconSize * 0.13), weight: .bold))
                            .foregroundStyle(appearance.badgeText.color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    )
                    .offset(x: 2, y: -2)
            }
        }
        .onAppear {
            refresh()
        }
        .onReceive(timer) { _ in
            refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: TrashService.didChangeNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        itemCount = TrashService.fastVisibleItemCount()
        isEmpty = itemCount == 0
    }
}
