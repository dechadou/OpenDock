import AppKit
import SwiftUI

struct MediaSidebarPill: View {
    var iconSize: CGFloat
    var edge: SidebarEdge
    @ObservedObject var appModel: AppModel

    @State private var isPresented = false
    @State private var openTask: DispatchWorkItem?
    @State private var closeTask: DispatchWorkItem?
    @State private var isPillHovered = false
    @State private var isPopoverHovered = false
    @Environment(\.sidebarAppearance) private var appearance

    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .leading) {
            if edge.isVertical {
                compactButtonStrip
            } else {
                inlinePill
            }
        }
        .frame(width: pillWidth, height: iconSize + 12, alignment: .leading)
        .clipped()
        .onHover { hovering in
            isPillHovered = hovering
            if hovering {
                scheduleOpen()
            } else {
                scheduleClose()
            }
        }
        .popover(isPresented: presentationBinding, arrowEdge: arrowEdge) {
            MediaControlsPopover(
                appModel: appModel,
                onHoverChanged: { hovering in
                    isPopoverHovered = hovering
                    if hovering {
                        closeTask?.cancel()
                    } else {
                        scheduleClose()
                    }
                }
            )
            .frame(width: 300, height: 340)
            .environment(\.sidebarAppearance, appearance)
        }
        .onAppear {
            loadPlaybackInfo()
        }
        .onReceive(timer) { _ in
            loadPlaybackInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: MediaControlService.didUpdateArtworkNotification)) { _ in
            loadPlaybackInfo()
        }
        .onDisappear {
            openTask?.cancel()
            closeTask?.cancel()
            setPresented(false)
        }
    }

    private func loadPlaybackInfo() {
        appModel.refreshMediaPlaybackInfo()
    }

    private var pillWidth: CGFloat {
        WidgetRegistry.shared.manifest(for: .media)?.dockSize.length(edge: edge, iconSize: iconSize)
            ?? (edge.isVertical ? iconSize + 12 : max(290, iconSize * 5.5))
    }

    private var playbackInfo: MediaPlaybackInfo? {
        appModel.mediaPlaybackInfo
    }

    private var inlinePill: some View {
        let appSide = max(26, min(34, iconSize * 0.76))
        let buttonSide = max(22, min(32, iconSize * 0.58))
        let metadataWidth = max(112, pillWidth - appSide - (buttonSide * 3) - 64)

        return HStack(spacing: 10) {
            openAppButton(side: appSide)
            metadataButton(width: metadataWidth)
            commandButton(.previous, systemName: "backward.fill", help: "Previous", side: buttonSide)
            commandButton(.playPause, systemName: playPauseSystemName, help: playPauseHelp, side: buttonSide)
            commandButton(.next, systemName: "forward.fill", help: "Next", side: buttonSide)
        }
        .padding(.horizontal, 10)
        .frame(width: pillWidth, height: iconSize + 12)
        .background(Capsule().fill(appearance.widgetBackground.color))
        .overlay(Capsule().stroke(appearance.widgetBorder.color, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private var compactButtonStrip: some View {
        let appSide = max(16, min(24, iconSize * 0.56))
        let buttonSide = max(10, min(15, iconSize * 0.34))

        return VStack(spacing: 3) {
            openAppButton(side: appSide)
            HStack(spacing: 2) {
                commandButton(.previous, systemName: "backward.fill", help: "Previous", side: buttonSide)
                commandButton(.playPause, systemName: playPauseSystemName, help: playPauseHelp, side: buttonSide)
                commandButton(.next, systemName: "forward.fill", help: "Next", side: buttonSide)
            }
        }
        .frame(width: iconSize + 12, height: iconSize + 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(appearance.widgetBackground.color))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(appearance.widgetBorder.color, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private func openAppButton(side: CGFloat) -> some View {
        Button {
            appModel.openCurrentMediaApplication()
        } label: {
            Image(nsImage: mediaAppIconImage(for: playbackInfo))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: max(4, side * 0.22), style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Open \(playbackInfo?.appName ?? "media app")")
    }

    private func metadataButton(width: CGFloat) -> some View {
        Button {
            appModel.openCurrentMediaApplication()
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(playbackInfo?.title ?? "No media")
                    .font(.system(size: max(11, iconSize * 0.24), weight: .semibold))
                    .foregroundStyle(appearance.primaryText.color)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(playbackInfo?.subtitle ?? "Spotify/Music")
                    .font(.system(size: max(10, iconSize * 0.21)))
                    .foregroundStyle(appearance.secondaryText.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open \(playbackInfo?.appName ?? "media app")")
    }

    private func commandButton(_ command: MediaControlService.Command, systemName: String, help: String, side: CGFloat) -> some View {
        Button {
            appModel.sendMediaCommand(command)
            refreshSoon()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: max(9, side * 0.54), weight: .semibold))
                .foregroundStyle(appearance.primaryText.color)
                .frame(width: side, height: side)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var playPauseSystemName: String {
        playbackInfo?.state == .playing ? "pause.fill" : "play.fill"
    }

    private var playPauseHelp: String {
        playbackInfo?.state == .playing ? "Pause" : "Play"
    }

    private func scheduleOpen() {
        closeTask?.cancel()
        openTask?.cancel()

        let task = DispatchWorkItem {
            openDetails()
        }
        openTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: task)
    }

    private func openDetails() {
        openTask?.cancel()
        closeTask?.cancel()
        loadPlaybackInfo()
        setPresented(true)
    }

    private func scheduleClose() {
        openTask?.cancel()
        closeTask?.cancel()

        let task = DispatchWorkItem {
            if !isPillHovered && !isPopoverHovered {
                setPresented(false)
            }
        }
        closeTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: task)
    }

    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            loadPlaybackInfo()
        }
    }

    private var arrowEdge: Edge {
        edge.popoverArrowEdge
    }

    private var presentationBinding: Binding<Bool> {
        Binding(
            get: { isPresented },
            set: { setPresented($0) }
        )
    }

    private func setPresented(_ presented: Bool) {
        isPresented = presented
        appModel.setSidebarInteractionSurface("media-controls", visible: presented)
    }
}

struct MediaControlsPopover: View {
    @ObservedObject var appModel: AppModel
    var onHoverChanged: (Bool) -> Void = { _ in }
    @Environment(\.sidebarAppearance) private var appearance

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            appHeader

            HStack {
                Spacer(minLength: 0)
                artworkBox
                Spacer(minLength: 0)
            }

            VStack(spacing: 3) {
                Text(playbackInfo?.subtitle ?? "Spotify/Music not detected")
                    .font(.caption)
                    .foregroundStyle(appearance.secondaryText.color)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            controlRow
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .onAppear {
            loadPlaybackInfo()
        }
        .onReceive(timer) { _ in
            loadPlaybackInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: MediaControlService.didUpdateArtworkNotification)) { _ in
            loadPlaybackInfo()
        }
        .onHover(perform: onHoverChanged)
        .foregroundStyle(appearance.primaryText.color)
        .background(appearance.popoverSurface.color)
    }

    private var playbackInfo: MediaPlaybackInfo? {
        appModel.mediaPlaybackInfo
    }

    private var appHeader: some View {
        Button {
            appModel.openCurrentMediaApplication()
        } label: {
            HStack(spacing: 8) {
                Image(nsImage: mediaAppIconImage(for: playbackInfo))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Text(playbackInfo?.appName ?? "Media")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .help("Open \(playbackInfo?.appName ?? "media app")")
    }

    private var artworkBox: some View {
        let side: CGFloat = 174

        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(appearance.widgetBackground.color)

            if let artwork = artworkImage {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: side, height: side)
            } else {
                Image(nsImage: mediaAppIconImage(for: playbackInfo))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: side * 0.42, height: side * 0.42)
                    .opacity(0.82)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(appearance.widgetBorder.color, lineWidth: 1))
        .overlay(alignment: .bottom) {
            Text(playbackInfo?.title ?? "No media")
                .font(.headline.weight(.semibold))
                .foregroundStyle(appearance.inverseText.color)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: side - 20, alignment: .leading)
                .background(appearance.mediaOverlayBackground.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(10)
        }
    }

    private var controlRow: some View {
        HStack(spacing: 18) {
            commandButton(.previous, systemName: "backward.fill", help: "Previous", side: buttonSide)
            commandButton(.playPause, systemName: playPauseSystemName, help: playPauseHelp, side: 42)
            commandButton(.next, systemName: "forward.fill", help: "Next", side: buttonSide)
        }
    }

    private func commandButton(_ command: MediaControlService.Command, systemName: String, help: String, side: CGFloat) -> some View {
        Button {
            appModel.sendMediaCommand(command)
            refreshSoon()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: side == 42 ? 20 : 16, weight: .semibold))
                .foregroundStyle(appearance.primaryText.color)
                .frame(width: side, height: side)
                .background(Circle().fill(appearance.widgetBackground.color))
                .overlay(Circle().stroke(appearance.widgetBorder.color, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func refreshSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            loadPlaybackInfo()
        }
    }

    private func loadPlaybackInfo() {
        appModel.refreshMediaPlaybackInfo()
    }

    private var buttonSide: CGFloat {
        36
    }

    private var playPauseSystemName: String {
        playbackInfo?.state == .playing ? "pause.fill" : "play.fill"
    }

    private var playPauseHelp: String {
        playbackInfo?.state == .playing ? "Pause" : "Play"
    }

    private var artworkImage: NSImage? {
        guard let artworkURL = playbackInfo?.artworkURL else {
            return nil
        }

        return NSImage(contentsOf: artworkURL)
    }
}

private func mediaAppIconImage(for playbackInfo: MediaPlaybackInfo?) -> NSImage {
    if let bundleURL = playbackInfo?.bundleURL {
        return NSWorkspace.shared.icon(forFile: bundleURL.path)
    }

    return .openDockSymbol("playpause")
}
