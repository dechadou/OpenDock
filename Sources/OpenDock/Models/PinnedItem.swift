import Foundation

public struct PinnedItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case application
        case file
        case folder
        case url
    }

    public var id: UUID
    public var kind: Kind
    public var title: String
    public var url: URL
    public var bundleIdentifier: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        url: URL,
        bundleIdentifier: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.createdAt = createdAt
    }
}
