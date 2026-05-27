import AppKit
import Darwin
import Foundation

public enum TrashService {
    public static let didChangeNotification = Notification.Name("LocalSidebarTrashDidChange")

    public static var trashURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
    }

    public static func openTrash() {
        if runFinderAppleScript("tell application \"Finder\" to open trash") == nil {
            NSWorkspace.shared.open(trashURL)
        }
    }

    public static func isTrashEmpty() -> Bool {
        visibleItemCount() == 0
    }

    public static func visibleItemCount() -> Int {
        resolveVisibleItemCount(
            finderItemCount: finderTrashItemCount(),
            fallbackItemCount: fileSystemVisibleItemCount()
        )
    }

    /// Filesystem-only count that avoids sending an Apple Event to Finder. Used by
    /// the periodic widget refresh so it never blocks the main thread on automation.
    public static func fastVisibleItemCount() -> Int {
        max(0, fileSystemVisibleItemCount())
    }

    public static func resolveVisibleItemCount(finderItemCount: Int?, fallbackItemCount: Int) -> Int {
        max(0, finderItemCount ?? fallbackItemCount)
    }

    public static func emptyTrash() throws {
        let contents = try FileManager.default.contentsOfDirectory(
            at: trashURL,
            includingPropertiesForKeys: nil,
            options: []
        )

        for url in contents {
            try FileManager.default.removeItem(at: url)
        }

        NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }

    private static func finderTrashItemCount() -> Int? {
        guard let descriptor = runFinderAppleScript("tell application \"Finder\" to count every item of trash") else {
            return nil
        }

        return Int(descriptor.int32Value)
    }

    private static func runFinderAppleScript(_ source: String) -> NSAppleEventDescriptor? {
        guard let script = NSAppleScript(source: source) else {
            return nil
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        guard errorInfo == nil else {
            return nil
        }

        return descriptor
    }

    private static func fileSystemVisibleItemCount(fileManager: FileManager = .default) -> Int {
        trashCandidateURLs(fileManager: fileManager).reduce(0) { count, url in
            count + visibleItemCount(at: url, fileManager: fileManager)
        }
    }

    private static func visibleItemCount(at url: URL, fileManager: FileManager) -> Int {
        guard fileManager.fileExists(atPath: url.path) else {
            return 0
        }

        return
            (try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).count) ?? 0
    }

    private static func trashCandidateURLs(fileManager: FileManager) -> [URL] {
        let uid = String(getuid())
        var candidates = [
            trashURL,
            URL(fileURLWithPath: "/.Trashes", isDirectory: true)
                .appendingPathComponent(uid, isDirectory: true),
        ]

        let mountedVolumes =
            fileManager.mountedVolumeURLs(
                includingResourceValuesForKeys: nil,
                options: [.skipHiddenVolumes]
            ) ?? []

        for volume in mountedVolumes {
            candidates.append(
                volume
                    .appendingPathComponent(".Trashes", isDirectory: true)
                    .appendingPathComponent(uid, isDirectory: true)
            )
        }

        var seen = Set<String>()
        return candidates.filter { url in
            seen.insert(url.standardizedFileURL.path).inserted
        }
    }
}
