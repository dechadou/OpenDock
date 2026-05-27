import AppKit
import SwiftUI

struct WindowPreviewView: View {
    static let preferredSize = CGSize(width: 720, height: 460)

    var app: RunningAppInfo
    @ObservedObject var appModel: AppModel
    @ObservedObject private var windowService: WindowService
    private var onHoverChanged: (Bool) -> Void

    init(
        app: RunningAppInfo,
        appModel: AppModel,
        onHoverChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.app = app
        self.appModel = appModel
        self.onHoverChanged = onHoverChanged
        self._windowService = ObservedObject(initialValue: appModel.windowService)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(app.localizedName)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                if appModel.preferencesStore.preferences.windowSwitcherEnabled {
                    Button {
                        appModel.openWindowSwitcher()
                    } label: {
                        Image(systemName: "rectangle.on.rectangle")
                    }
                    .buttonStyle(.borderless)
                    .help("Open Window Switcher")
                }
            }
            .padding(12)

            Divider()

            if previewWindows.isEmpty {
                ContentUnavailableView("No Visible Windows", systemImage: "macwindow")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                WindowPreviewGrid(
                    windows: previewWindows,
                    windowService: windowService
                )
                .padding(12)
            }
        }
        .onAppear {
            windowService.refresh()
        }
        .onHover { hovering in
            onHoverChanged(hovering)
        }
    }

    private var windows: [WindowInfo] {
        windowService.windows(for: app)
    }

    private var previewWindows: [WindowInfo] {
        Array(windows.prefix(WindowPreviewGridLayout.maximumItemCount))
    }
}

private struct WindowPreviewGrid: View {
    var windows: [WindowInfo]
    @ObservedObject var windowService: WindowService

    var body: some View {
        GeometryReader { geometry in
            let metrics = WindowPreviewGridLayout.metrics(
                itemCount: windows.count,
                availableSize: geometry.size
            )
            let tileHeight = tileHeight(
                availableSize: geometry.size,
                rows: metrics.rows
            )
            let tileWidth = tileWidth(
                availableSize: geometry.size,
                columns: metrics.columns
            )
            let columns = Array(
                repeating: GridItem(.fixed(tileWidth), spacing: WindowPreviewGridLayout.spacing),
                count: max(1, metrics.columns)
            )

            LazyVGrid(columns: columns, spacing: WindowPreviewGridLayout.spacing) {
                ForEach(windows.prefix(metrics.displayedItemCount)) { window in
                    Button {
                        windowService.activate(window)
                    } label: {
                        WindowPreviewTile(window: window, windowService: windowService)
                            .frame(width: tileWidth, height: tileHeight)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func tileWidth(availableSize: CGSize, columns: Int) -> CGFloat {
        guard columns > 0 else {
            return 1
        }

        let totalSpacing = CGFloat(columns - 1) * WindowPreviewGridLayout.spacing
        return max(1, (availableSize.width - totalSpacing) / CGFloat(columns))
    }

    private func tileHeight(availableSize: CGSize, rows: Int) -> CGFloat {
        guard rows > 0 else {
            return 1
        }

        let totalSpacing = CGFloat(rows - 1) * WindowPreviewGridLayout.spacing
        return max(1, (availableSize.height - totalSpacing) / CGFloat(rows))
    }
}

private struct WindowPreviewTile: View {
    var window: WindowInfo
    @ObservedObject var windowService: WindowService

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                thumbnail(size: geometry.size)

                VStack(alignment: .leading, spacing: 4) {
                    Text(window.displayTitle)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)

                    Text("\(Int(window.bounds.width)) x \(Int(window.bounds.height))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func thumbnail(size: CGSize) -> some View {
        if let image = windowService.thumbnail(for: window) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height, alignment: .center)
                .clipped()
        } else {
            Rectangle()
                .fill(.quaternary)
                .frame(width: size.width, height: size.height)
                .overlay {
                    Image(systemName: "macwindow")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                }
        }
    }
}
