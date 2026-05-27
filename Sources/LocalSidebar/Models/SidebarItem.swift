import Foundation

public struct SidebarItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case application
        case file
        case folder
        case url
        case stack
        case system
    }

    public enum SystemKind: String, Codable, CaseIterable, Sendable {
        case windowSwitcher
        case trash
        case dateTime
        case media
    }

    public var id: UUID
    public var kind: Kind
    public var title: String
    public var url: URL?
    public var bundleIdentifier: String?
    public var systemKind: SystemKind?
    public var children: [SidebarItem]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        url: URL? = nil,
        bundleIdentifier: String? = nil,
        systemKind: SystemKind? = nil,
        children: [SidebarItem] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.systemKind = systemKind
        self.children = children
        self.createdAt = createdAt
    }

    public static func fromPinnedItem(_ item: PinnedItem) -> SidebarItem {
        SidebarItem(
            id: item.id,
            kind: SidebarItem.Kind(pinnedKind: item.kind),
            title: item.title,
            url: item.url,
            bundleIdentifier: item.bundleIdentifier,
            createdAt: item.createdAt
        )
    }

    public static func system(_ systemKind: SystemKind) -> SidebarItem {
        SidebarItem(
            kind: .system,
            title: systemKind.displayName,
            systemKind: systemKind
        )
    }
}

extension SidebarItem.Kind {
    init(pinnedKind: PinnedItem.Kind) {
        switch pinnedKind {
        case .application:
            self = .application
        case .file:
            self = .file
        case .folder:
            self = .folder
        case .url:
            self = .url
        }
    }
}

extension SidebarItem.SystemKind {
    var displayName: String {
        switch self {
        case .windowSwitcher:
            return "Windows"
        case .trash:
            return "Trash"
        case .dateTime:
            return "Date & Time"
        case .media:
            return "Media"
        }
    }

    var symbolName: String {
        switch self {
        case .windowSwitcher:
            return "rectangle.on.rectangle"
        case .trash:
            return "trash"
        case .dateTime:
            return "calendar"
        case .media:
            return "playpause"
        }
    }
}
