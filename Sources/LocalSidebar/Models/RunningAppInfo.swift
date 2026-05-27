import AppKit
import Foundation

struct RunningAppInfo: Identifiable, Equatable, Hashable, Sendable {
    var processIdentifier: pid_t
    var localizedName: String
    var bundleIdentifier: String?
    var bundleURL: URL?
    var isActive: Bool
    var launchDate: Date?

    var id: String {
        if let bundleIdentifier {
            return bundleIdentifier
        }

        return "pid-\(processIdentifier)"
    }

    init(app: NSRunningApplication) {
        self.processIdentifier = app.processIdentifier
        self.localizedName = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? "App"
        self.bundleIdentifier = app.bundleIdentifier
        self.bundleURL = app.bundleURL
        self.isActive = app.isActive
        self.launchDate = app.launchDate
    }
}
