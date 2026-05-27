import AppKit

extension NSImage {
    static func localSidebarSymbol(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSWorkspace.shared.icon(for: .application)
    }
}
