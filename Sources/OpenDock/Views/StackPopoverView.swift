import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct StackPopoverView: View {
    var stack: SidebarItem
    @ObservedObject var appModel: AppModel
    var iconSize: CGFloat

    @ObservedObject private var sidebarItemStore: SidebarItemStore

    init(stack: SidebarItem, appModel: AppModel, iconSize: CGFloat) {
        self.stack = stack
        self.appModel = appModel
        self.iconSize = iconSize
        self._sidebarItemStore = ObservedObject(initialValue: appModel.sidebarItemStore)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(currentStack.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text("\(currentStack.children.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(12)

            Divider()

            if currentStack.children.isEmpty {
                ContentUnavailableView("Drop apps or files here", systemImage: "square.stack.3d.up")
                    .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
                        appModel.handleDropIntoStack(providers, stackID: currentStack.id)
                    }
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 12)], spacing: 12) {
                        ForEach(currentStack.children) { child in
                            Button {
                                appModel.handleSidebarItemClick(child)
                            } label: {
                                VStack(spacing: 6) {
                                    SidebarIconButtonLabel(
                                        icon: AppActionService.icon(for: child),
                                        iconSize: iconSize,
                                        isRunning: appModel.runningApp(for: child) != nil,
                                        isFrontmost: appModel.runningApp(for: child)?.isActive == true,
                                        badgeText: appModel.badge(for: child)?.text
                                    )

                                    Text(child.title)
                                        .font(.caption2)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .frame(height: 28, alignment: .top)
                                }
                                .frame(width: 68)
                            }
                            .buttonStyle(.plain)
                            .onDrag {
                                DragDropService.itemProvider(for: child)
                            }
                            .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
                                appModel.handleDropIntoStackChildList(providers, stackID: currentStack.id, before: child.id)
                            }
                            .conditionalContextMenu(child.kind != .application) {
                                childContextMenu(child)
                            }
                            .overlay {
                                if child.kind == .application {
                                    AppContextMenuBridge(
                                        menuProvider: {
                                            AppContextMenuFactory.stackChildApplicationMenu(
                                                child: child,
                                                stackID: currentStack.id,
                                                runningApp: appModel.runningApp(for: child),
                                                appModel: appModel
                                            )
                                        },
                                        onMenuVisibilityChanged: { visible in
                                            appModel.setSidebarInteractionSurface("stack-menu-\(child.id)", visible: visible)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
                    appModel.handleDropIntoStack(providers, stackID: currentStack.id)
                }
            }

            Divider()

            Text("Drag running apps, pinned items, files, or folders into this stack.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    private var currentStack: SidebarItem {
        sidebarItemStore.item(id: stack.id) ?? stack
    }

    @ViewBuilder
    private func childContextMenu(_ child: SidebarItem) -> some View {
        Button("Open") {
            appModel.handleSidebarItemClick(child)
        }

        Button("Move Out of Stack") {
            appModel.moveChildOutOfStack(childID: child.id, stackID: currentStack.id)
        }

        if let url = child.url, url.isFileURL {
            Button("Reveal in Finder") {
                AppActionService.revealInFinder(url)
            }
        }

        Divider()

        Button("Remove") {
            appModel.removeSidebarItem(child)
        }
    }
}
