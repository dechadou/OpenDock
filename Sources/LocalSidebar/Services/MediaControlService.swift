import AppKit
import CoreGraphics
import Foundation

enum MediaControlService {
    static let didUpdateArtworkNotification = Notification.Name("LocalSidebarMediaArtworkDidUpdate")

    enum Command {
        case previous
        case playPause
        case next
    }

    private static let artworkCache = MediaArtworkCache()

    /// Serial queue used to run the AppleScript playback queries off the main
    /// thread so periodic polling never blocks the UI.
    static let pollingQueue = DispatchQueue(
        label: "app.localsidebar.media-polling",
        qos: .userInitiated
    )

    @discardableResult
    static func send(_ command: Command) -> Bool {
        if runAppleScriptCommand(command) {
            return true
        }

        let keyCode: Int
        switch command {
        case .previous:
            keyCode = 18
        case .playPause:
            keyCode = 16
        case .next:
            keyCode = 17
        }

        return postAuxKey(keyCode)
    }

    static func currentPlaybackInfoSync() -> MediaPlaybackInfo? {
        let mediaAppNames = ["Spotify", "Music"]
        let infos = mediaAppNames.compactMap(playbackInfo(for:))

        return infos.first { $0.state == .playing }
            ?? infos.first { $0.state == .paused }
            ?? infos.first
            ?? mediaAppNames.compactMap(runningMediaAppInfo(for:)).first
    }

    @discardableResult
    private static func postAuxKey(_ keyCode: Int) -> Bool {
        let keyDown = mediaKeyEvent(keyCode: keyCode, keyDown: true)
        let keyUp = mediaKeyEvent(keyCode: keyCode, keyDown: false)

        guard let keyDownEvent = keyDown?.cgEvent,
            let keyUpEvent = keyUp?.cgEvent
        else {
            return false
        }

        keyDownEvent.post(tap: .cghidEventTap)
        keyUpEvent.post(tap: .cghidEventTap)
        return true
    }

    private static func mediaKeyEvent(keyCode: Int, keyDown: Bool) -> NSEvent? {
        let flags = keyDown ? 0xA00 : 0xB00
        let data1 = (keyCode << 16) | flags

        return NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
    }

    @discardableResult
    private static func runAppleScriptCommand(_ command: Command) -> Bool {
        let target = currentPlaybackInfoSync()?.appName ?? firstRunningMediaAppName()
        guard let target else {
            return false
        }

        return runAppleScript(command, target: target)
    }

    private static func firstRunningMediaAppName() -> String? {
        let runningNames = Set(NSWorkspace.shared.runningApplications.compactMap(\.localizedName))

        if runningNames.contains("Spotify") {
            return "Spotify"
        }

        if runningNames.contains("Music") {
            return "Music"
        }

        return nil
    }

    private static func runningMediaAppInfo(for appName: String) -> MediaPlaybackInfo? {
        guard let runningApplication = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) else {
            return nil
        }

        return MediaPlaybackInfo(
            appName: appName,
            bundleIdentifier: runningApplication.bundleIdentifier,
            bundleURL: runningApplication.bundleURL,
            title: appName,
            artist: "",
            album: "",
            artworkURL: nil,
            state: .unknown
        )
    }

    @discardableResult
    private static func runAppleScript(_ command: Command, target: String) -> Bool {
        let verb: String
        switch command {
        case .previous:
            verb = "previous track"
        case .playPause:
            verb = "playpause"
        case .next:
            verb = "next track"
        }

        let source = "tell application \"\(target)\" to \(verb)"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil
    }

    private static func playbackInfo(for appName: String) -> MediaPlaybackInfo? {
        guard let runningApplication = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) else {
            return nil
        }

        let localArtworkURL = localArtworkCacheURL(for: appName)
        let source: String
        switch appName {
        case "Spotify":
            source = """
                tell application "Spotify"
                  set stateText to player state as string
                  if stateText is "stopped" then return stateText & "|||" & "" & "|||" & "" & "|||" & "" & "|||" & ""
                  set trackName to name of current track
                  set trackArtist to artist of current track
                  set trackAlbum to album of current track
                  set trackArtworkURL to ""
                  try
                    set trackArtworkURL to artwork url of current track
                  on error
                    set trackArtworkURL to ""
                  end try
                  return stateText & "|||" & trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackArtworkURL
                end tell
                """
        case "Music":
            source = """
                tell application "Music"
                  set stateText to player state as string
                  if stateText is "stopped" then return stateText & "|||" & "" & "|||" & "" & "|||" & "" & "|||" & ""
                  set trackName to name of current track
                  set trackArtist to artist of current track
                  set trackAlbum to album of current track
                  try
                    set artworkData to raw data of artwork 1 of current track
                    set artworkFile to open for access POSIX file "\(localArtworkURL.path)" with write permission
                    set eof artworkFile to 0
                    write artworkData to artworkFile
                    close access artworkFile
                  on error
                    try
                      close access POSIX file "\(localArtworkURL.path)"
                    end try
                  end try
                  return stateText & "|||" & trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & ""
                end tell
                """
        default:
            return nil
        }

        var error: NSDictionary?
        guard
            let output = NSAppleScript(source: source)?
                .executeAndReturnError(&error)
                .stringValue,
            error == nil
        else {
            return nil
        }

        let parts = output.components(separatedBy: "|||")
        let state = MediaPlaybackInfo.PlaybackState(rawValue: parts[safe: 0]?.lowercased() ?? "") ?? .unknown
        let remoteArtworkURLString = parts[safe: 4] ?? ""
        let artworkURL: URL?

        if appName == "Spotify" {
            artworkURL = cachedRemoteArtworkURL(for: appName, remoteURLString: remoteArtworkURLString)
        } else {
            artworkURL = readableLocalArtworkURL(localArtworkURL)
        }

        return MediaPlaybackInfo(
            appName: appName,
            bundleIdentifier: runningApplication.bundleIdentifier,
            bundleURL: runningApplication.bundleURL,
            title: parts[safe: 1]?.isEmpty == false ? parts[1] : appName,
            artist: parts[safe: 2] ?? "",
            album: parts[safe: 3] ?? "",
            artworkURL: artworkURL,
            state: state
        )
    }

    private static func localArtworkCacheURL(for appName: String) -> URL {
        artworkCacheDirectory().appendingPathComponent("\(appName)-artwork.bin")
    }

    private static func remoteArtworkCacheURL(for appName: String, remoteURL: URL) -> URL {
        let fileExtension = remoteURL.pathExtension.isEmpty ? "jpg" : remoteURL.pathExtension

        return artworkCacheDirectory()
            .appendingPathComponent("\(appName)-\(stableHash(remoteURL.absoluteString)).\(fileExtension)")
    }

    private static func artworkCacheDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalSidebarMediaArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func cachedRemoteArtworkURL(for appName: String, remoteURLString: String) -> URL? {
        guard let remoteURL = URL(string: remoteURLString),
            let scheme = remoteURL.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            return nil
        }

        let cacheURL = remoteArtworkCacheURL(for: appName, remoteURL: remoteURL)
        if let readableURL = readableLocalArtworkURL(cacheURL) {
            return readableURL
        }

        downloadRemoteArtwork(from: remoteURL, to: cacheURL)
        return nil
    }

    private static func readableLocalArtworkURL(_ url: URL) -> URL? {
        guard FileManager.default.fileExists(atPath: url.path),
            NSImage(contentsOf: url) != nil
        else {
            return nil
        }

        return url
    }

    private static func downloadRemoteArtwork(from remoteURL: URL, to cacheURL: URL) {
        Task {
            await artworkCache.downloadRemoteArtwork(
                from: remoteURL,
                to: cacheURL,
                notificationName: didUpdateArtworkNotification
            )
        }
    }

    private static func stableHash(_ string: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037

        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        return String(hash, radix: 16)
    }
}

private actor MediaArtworkCache {
    private var downloadsInFlight = Set<URL>()

    func downloadRemoteArtwork(
        from remoteURL: URL,
        to cacheURL: URL,
        notificationName: Notification.Name
    ) async {
        guard downloadsInFlight.insert(remoteURL).inserted else {
            return
        }
        defer {
            downloadsInFlight.remove(remoteURL)
        }

        let request = URLRequest(
            url: remoteURL,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: 10
        )

        guard let data = try? await URLSession.shared.data(for: request).0,
            !data.isEmpty
        else {
            return
        }

        try? data.write(to: cacheURL, options: .atomic)

        await MainActor.run {
            NotificationCenter.default.post(name: notificationName, object: cacheURL)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
