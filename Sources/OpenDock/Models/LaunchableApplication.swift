import Foundation

public struct LaunchableApplication: Identifiable, Equatable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var url: URL
    public var bundleIdentifier: String?

    public init(name: String, url: URL, bundleIdentifier: String?) {
        self.name = name
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.id = bundleIdentifier ?? url.path
    }
}
