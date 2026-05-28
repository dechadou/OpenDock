import Foundation

public struct AppNotificationBadge: Equatable, Sendable {
    public var bundleIdentifier: String?
    public var appTitle: String?
    public var text: String

    public init(bundleIdentifier: String?, appTitle: String?, text: String) {
        self.bundleIdentifier = bundleIdentifier
        self.appTitle = appTitle
        self.text = text
    }
}
