import AppKit
import Foundation

enum AppActionService {
    static func openSidebarItem(_ item: SidebarItem) {
        switch item.kind {
        case .application:
            if let url = item.url {
                openApplication(at: url)
            }
        case .file, .folder, .url:
            if let url = item.url {
                NSWorkspace.shared.open(url)
            }
        case .stack, .system:
            break
        }
    }

    static func openPinnedItem(_ item: PinnedItem) {
        switch item.kind {
        case .application:
            openApplication(at: item.url)
        case .file, .folder, .url:
            NSWorkspace.shared.open(item.url)
        }
    }

    static func openApplication(_ application: LaunchableApplication) {
        openApplication(at: application.url)
    }

    static func openApplication(at url: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            if let error {
                NSLog("LocalSidebar: failed to open app at \(url.path): \(error.localizedDescription)")
            }
        }
    }

    static func revealInFinder(_ url: URL) {
        guard url.isFileURL else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func icon(for item: PinnedItem) -> NSImage {
        switch item.kind {
        case .application, .file, .folder:
            return NSWorkspace.shared.icon(forFile: item.url.path)
        case .url:
            return .localSidebarSymbol("globe")
        }
    }

    static func icon(for item: SidebarItem) -> NSImage {
        switch item.kind {
        case .application, .file, .folder:
            if let url = item.url {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
            return .localSidebarSymbol("app")
        case .url:
            return .localSidebarSymbol("globe")
        case .stack:
            return .localSidebarSymbol("square.stack.3d.up")
        case .system:
            return .localSidebarSymbol(item.systemKind?.symbolName ?? "gear")
        }
    }

    static func icon(for folderEntry: FolderEntry) -> NSImage {
        NSWorkspace.shared.icon(forFile: folderEntry.url.path)
    }

    static func icon(for application: LaunchableApplication) -> NSImage {
        NSWorkspace.shared.icon(forFile: application.url.path)
    }

    static func icon(for app: RunningAppInfo) -> NSImage {
        if let bundleURL = app.bundleURL {
            return NSWorkspace.shared.icon(forFile: bundleURL.path)
        }

        return .localSidebarSymbol("app")
    }
}
