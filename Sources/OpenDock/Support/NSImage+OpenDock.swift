import AppKit

extension NSImage {
    static func openDockSymbol(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
            ?? NSWorkspace.shared.icon(for: .application)
    }
}
