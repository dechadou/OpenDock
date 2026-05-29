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
    public var widgetID: WidgetID?
    public var systemKind: SystemKind?
    public var children: [SidebarItem]
    public var createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case url
        case bundleIdentifier
        case widgetID
        case systemKind
        case children
        case createdAt
    }

    public init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        url: URL? = nil,
        bundleIdentifier: String? = nil,
        widgetID: WidgetID? = nil,
        systemKind: SystemKind? = nil,
        children: [SidebarItem] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.widgetID = widgetID
        self.systemKind = systemKind
        self.children = children
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let systemKind = try container.decodeIfPresent(SystemKind.self, forKey: .systemKind)

        self.id = try container.decode(UUID.self, forKey: .id)
        self.kind = try container.decode(Kind.self, forKey: .kind)
        self.title = try container.decode(String.self, forKey: .title)
        self.url = try container.decodeIfPresent(URL.self, forKey: .url)
        self.bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        self.widgetID = try container.decodeIfPresent(WidgetID.self, forKey: .widgetID) ?? systemKind?.widgetID
        self.systemKind = systemKind
        self.children = try container.decodeIfPresent([SidebarItem].self, forKey: .children) ?? []
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(bundleIdentifier, forKey: .bundleIdentifier)
        try container.encodeIfPresent(widgetID, forKey: .widgetID)
        try container.encode(children, forKey: .children)
        try container.encode(createdAt, forKey: .createdAt)
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

    public static func widget(_ widgetID: WidgetID) -> SidebarItem {
        let title = WidgetRegistry.shared.manifest(for: widgetID)?.title ?? widgetID.rawValue

        return SidebarItem(
            kind: .system,
            title: title,
            widgetID: widgetID
        )
    }

    public static func system(_ systemKind: SystemKind) -> SidebarItem {
        widget(systemKind.widgetID)
    }
}

extension SidebarItem.SystemKind {
    var widgetID: WidgetID {
        switch self {
        case .windowSwitcher:
            return .windows
        case .trash:
            return .trash
        case .dateTime:
            return .dateTime
        case .media:
            return .media
        }
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
