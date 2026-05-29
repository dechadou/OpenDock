import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SidebarPanelView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var preferencesStore: PreferencesStore
    @ObservedObject private var sidebarItemStore: SidebarItemStore
    @ObservedObject private var runningAppService: RunningAppService

    init(appModel: AppModel) {
        self.appModel = appModel
        self._preferencesStore = ObservedObject(initialValue: appModel.preferencesStore)
        self._sidebarItemStore = ObservedObject(initialValue: appModel.sidebarItemStore)
        self._runningAppService = ObservedObject(initialValue: appModel.runningAppService)
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if preferences.edge.isVertical {
                    dockSurface {
                        verticalContent
                            .frame(height: constrainedDockLength(availableLength: geometry.size.height))
                    }
                } else {
                    let dockLength = constrainedDockLength(availableLength: geometry.size.width)
                    dockSurface {
                        horizontalContent(availableLength: dockLength)
                            .frame(width: dockLength)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .popover(isPresented: $appModel.isLauncherPresented, arrowEdge: launcherArrowEdge) {
            LauncherView(appModel: appModel)
                .frame(width: 430, height: 520)
                .environment(\.sidebarAppearance, preferences.appearance)
        }
        .popover(isPresented: $appModel.isWindowSwitcherPresented, arrowEdge: launcherArrowEdge) {
            WindowSwitcherView(appModel: appModel)
                .frame(width: 620, height: 520)
                .environment(\.sidebarAppearance, preferences.appearance)
        }
    }

    private var preferences: SidebarPreferences {
        preferencesStore.preferences
    }

    private var iconSize: CGFloat {
        CGFloat(preferences.iconSize)
    }

    private var visibleItems: [SidebarItem] {
        sidebarItemStore.items.filter { appModel.shouldDisplay($0) }
    }

    private var layoutSections: SidebarDockLayout.Sections {
        SidebarDockLayout.sections(from: visibleItems)
    }

    private var estimatedDockLength: CGFloat {
        SidebarDockLayout.estimatedLength(
            itemCount: standardLengthItemCount,
            dividerCount: dividerCount,
            iconSize: iconSize,
            spacing: spacing,
            mediaControlCount: mediaControlCount,
            mediaUsesInlineLength: !preferences.edge.isVertical
        )
    }

    private var standardLengthItemCount: Int {
        layoutSections.stacks.count
            + layoutSections.pinnedItems.count
            + appModel.visibleRunningApps.count
            + finalControlsCount
            - mediaControlCount
    }

    private var mediaControlCount: Int {
        layoutSections.finalSystemItems.contains { $0.systemKind == .media } ? 1 : 0
    }

    private var finalControlsCount: Int {
        layoutSections.finalSystemItems.count
    }

    private var hasFinalControls: Bool {
        finalControlsCount > 0
    }

    private var scrollableHorizontalContentExists: Bool {
        layoutSections.hasUserItems || !appModel.visibleRunningApps.isEmpty
    }

    private var spacing: CGFloat {
        CGFloat(preferences.spacing)
    }

    private var itemSide: CGFloat {
        iconSize + 12
    }

    private var finalControlsLength: CGFloat {
        let itemLengths = layoutSections.finalSystemItems.reduce(CGFloat(0)) { partial, item in
            partial + (item.systemKind == .media ? SidebarDockLayout.mediaControlLength(iconSize: iconSize) : itemSide)
        }
        let itemCount = finalControlsCount
        let spacingLength = CGFloat(max(0, itemCount - 1)) * spacing
        return itemLengths + spacingLength
    }

    private var scrollableHorizontalContentLength: CGFloat {
        let itemCount =
            layoutSections.stacks.count
            + layoutSections.pinnedItems.count
            + appModel.visibleRunningApps.count
        let dividerCount = layoutSections.hasUserItems && !appModel.visibleRunningApps.isEmpty ? 1 : 0

        return SidebarDockLayout.estimatedLength(
            itemCount: itemCount,
            dividerCount: dividerCount,
            iconSize: iconSize,
            spacing: spacing,
            contentPadding: 0
        )
    }

    private var dividerCount: Int {
        var count = 0
        if layoutSections.hasUserItems && !appModel.visibleRunningApps.isEmpty {
            count += 1
        }
        if hasFinalControls && (layoutSections.hasUserItems || !appModel.visibleRunningApps.isEmpty) {
            count += 1
        }
        return count
    }

    private var dropTypes: [UTType] {
        [.fileURL, .text]
    }

    private var verticalContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: spacing) {
                stackItems
                pinnedItems
                runningSeparatorIfNeeded
                runningApps
                finalControlsSeparatorIfNeeded
                finalControls
            }
            .padding(10)
        }
    }

    private func horizontalContent(availableLength: CGFloat) -> some View {
        let contentPadding: CGFloat = 10
        let contentLength = max(1, availableLength - (contentPadding * 2))
        let fixedDividerLength = SidebarDockLayout.sectionDividerLength(spacing: spacing)
        let canShowFixedDivider = hasFinalControls && scrollableHorizontalContentExists
        let fixedLength = hasFinalControls ? finalControlsLength : 0
        let fixedDividerReserve = canShowFixedDivider ? fixedDividerLength : 0
        let maxScrollableLength = max(0, contentLength - fixedLength - fixedDividerReserve)
        let scrollableLength = min(scrollableHorizontalContentLength, maxScrollableLength)
        let showsScrollableContent = scrollableHorizontalContentExists && scrollableLength > 0
        let showsFixedDivider = canShowFixedDivider && showsScrollableContent

        return HStack(spacing: spacing) {
            if showsScrollableContent {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        stackItems
                        pinnedItems
                        runningSeparatorIfNeeded
                        runningApps
                    }
                }
                .frame(width: scrollableLength)
                .clipped()
                .mask(Rectangle())
                .zIndex(0)
            }

            if showsFixedDivider {
                sectionDivider
                    .zIndex(1)
            }

            ForEach(layoutSections.finalSystemItems) { item in
                SidebarItemView(
                    item: item,
                    appModel: appModel,
                    iconSize: iconSize,
                    edge: preferences.edge
                )
                .layoutPriority(1)
                .zIndex(2)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .frame(width: contentLength, alignment: .leading)
        .padding(contentPadding)
    }

    private func constrainedDockLength(availableLength: CGFloat) -> CGFloat {
        min(max(1, availableLength - 8), estimatedDockLength)
    }

    private func dockSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return GlassEffectContainer(spacing: spacing) {
            content()
                .background(preferences.appearance.dockSurface.color, in: shape)
                .glassEffect(
                    .regular.interactive(),
                    in: shape
                )
        }
        .padding(4)
        .contextMenu {
            dockContextMenu
        }
        .onDrop(of: dropTypes, isTargeted: nil) { providers in
            appModel.handlePinnedItemDrop(providers, before: nil)
        }
        .environment(\.sidebarAppearance, preferences.appearance)
    }

    @ViewBuilder
    private var dockContextMenu: some View {
        if preferences.stacksEnabled {
            Button("New Stack") {
                appModel.createStack()
            }
        }
    }

    @ViewBuilder
    private var stackItems: some View {
        ForEach(layoutSections.stacks) { item in
            SidebarItemView(
                item: item,
                appModel: appModel,
                iconSize: iconSize,
                edge: preferences.edge
            )
            .onDrag {
                DragDropService.itemProvider(for: item)
            }
        }
    }

    @ViewBuilder
    private var pinnedItems: some View {
        ForEach(layoutSections.pinnedItems) { item in
            SidebarItemView(
                item: item,
                appModel: appModel,
                iconSize: iconSize,
                edge: preferences.edge
            )
            .onDrag {
                DragDropService.itemProvider(for: item)
            }
            .onDrop(of: dropTypes, isTargeted: nil) { providers in
                appModel.handlePinnedItemDrop(providers, before: item.id)
            }
        }
    }

    @ViewBuilder
    private var runningApps: some View {
        ForEach(appModel.visibleRunningApps) { app in
            RunningAppSidebarItemView(
                app: app,
                appModel: appModel,
                iconSize: iconSize,
                edge: preferences.edge
            )
        }
    }

    @ViewBuilder
    private var runningSeparatorIfNeeded: some View {
        if layoutSections.hasUserItems && !appModel.visibleRunningApps.isEmpty {
            sectionDivider
        }
    }

    @ViewBuilder
    private var finalControlsSeparatorIfNeeded: some View {
        if hasFinalControls && (layoutSections.hasUserItems || !appModel.visibleRunningApps.isEmpty) {
            sectionDivider
        }
    }

    @ViewBuilder
    private var finalControls: some View {
        if hasFinalControls {
            if preferences.edge.isVertical {
                VStack(spacing: spacing) {
                    ForEach(layoutSections.finalSystemItems) { item in
                        SidebarItemView(
                            item: item,
                            appModel: appModel,
                            iconSize: iconSize,
                            edge: preferences.edge
                        )
                    }
                }
            } else {
                HStack(spacing: spacing) {
                    ForEach(layoutSections.finalSystemItems) { item in
                        SidebarItemView(
                            item: item,
                            appModel: appModel,
                            iconSize: iconSize,
                            edge: preferences.edge
                        )
                    }
                }
            }
        }
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(preferences.appearance.separator.color)
            .frame(
                width: preferences.edge.isVertical ? nil : 1,
                height: preferences.edge.isVertical ? 1 : CGFloat(preferences.panelThickness - 28)
            )
    }

    private var launcherArrowEdge: Edge {
        preferences.edge.popoverArrowEdge
    }
}
