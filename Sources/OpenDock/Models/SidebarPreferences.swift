import Foundation

public struct SidebarPreferences: Codable, Equatable, Sendable {
    public var edge: SidebarEdge
    public var iconSize: Double
    public var spacing: Double
    public var opacity: Double
    public var autoHide: Bool
    public var showOnAllDisplays: Bool
    public var stacksEnabled: Bool
    public var secondClickEnabled: Bool
    public var windowSwitcherEnabled: Bool
    public var windowPreviewsEnabled: Bool
    public var folderPeekEnabled: Bool
    public var trashWidgetEnabled: Bool
    public var dateTimeWidgetEnabled: Bool
    public var mediaControlsEnabled: Bool
    public var hideMediaSourceAppIcon: Bool
    public var hideSystemDock: Bool
    public var bottomRevealDelayMilliseconds: Int
    public var appearance: SidebarAppearance

    private enum CodingKeys: String, CodingKey {
        case edge
        case iconSize
        case spacing
        case opacity
        case autoHide
        case showOnAllDisplays
        case stacksEnabled
        case secondClickEnabled
        case windowSwitcherEnabled
        case windowPreviewsEnabled
        case folderPeekEnabled
        case trashWidgetEnabled
        case dateTimeWidgetEnabled
        case mediaControlsEnabled
        case hideMediaSourceAppIcon
        case hideSystemDock
        case bottomRevealDelayMilliseconds
        case appearance
    }

    public static let defaults = SidebarPreferences(
        edge: .bottom,
        iconSize: 34,
        spacing: 8,
        opacity: 0.96,
        autoHide: true,
        showOnAllDisplays: true,
        stacksEnabled: true,
        secondClickEnabled: true,
        windowSwitcherEnabled: true,
        windowPreviewsEnabled: true,
        folderPeekEnabled: true,
        trashWidgetEnabled: true,
        dateTimeWidgetEnabled: true,
        mediaControlsEnabled: true,
        hideMediaSourceAppIcon: true,
        hideSystemDock: false,
        bottomRevealDelayMilliseconds: 30,
        appearance: .defaults
    )

    public init(
        edge: SidebarEdge,
        iconSize: Double,
        spacing: Double,
        opacity: Double,
        autoHide: Bool,
        showOnAllDisplays: Bool,
        stacksEnabled: Bool = true,
        secondClickEnabled: Bool = true,
        windowSwitcherEnabled: Bool = true,
        windowPreviewsEnabled: Bool = true,
        folderPeekEnabled: Bool = true,
        trashWidgetEnabled: Bool = true,
        dateTimeWidgetEnabled: Bool = true,
        mediaControlsEnabled: Bool = true,
        hideMediaSourceAppIcon: Bool = true,
        hideSystemDock: Bool = false,
        bottomRevealDelayMilliseconds: Int = 30,
        appearance: SidebarAppearance = .defaults
    ) {
        self.edge = edge
        self.iconSize = iconSize
        self.spacing = spacing
        self.opacity = opacity
        self.autoHide = autoHide
        self.showOnAllDisplays = showOnAllDisplays
        self.stacksEnabled = stacksEnabled
        self.secondClickEnabled = secondClickEnabled
        self.windowSwitcherEnabled = windowSwitcherEnabled
        self.windowPreviewsEnabled = windowPreviewsEnabled
        self.folderPeekEnabled = folderPeekEnabled
        self.trashWidgetEnabled = trashWidgetEnabled
        self.dateTimeWidgetEnabled = dateTimeWidgetEnabled
        self.mediaControlsEnabled = mediaControlsEnabled
        self.hideMediaSourceAppIcon = hideMediaSourceAppIcon
        self.hideSystemDock = hideSystemDock
        self.bottomRevealDelayMilliseconds = bottomRevealDelayMilliseconds
        self.appearance = appearance
    }

    public var panelThickness: Double {
        max(64, iconSize + (spacing * 2) + 22)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SidebarPreferences.defaults

        self.edge = try container.decodeIfPresent(SidebarEdge.self, forKey: .edge) ?? defaults.edge
        self.iconSize = try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? defaults.iconSize
        self.spacing = try container.decodeIfPresent(Double.self, forKey: .spacing) ?? defaults.spacing
        self.opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? defaults.opacity
        self.autoHide = try container.decodeIfPresent(Bool.self, forKey: .autoHide) ?? defaults.autoHide
        self.showOnAllDisplays = try container.decodeIfPresent(Bool.self, forKey: .showOnAllDisplays) ?? defaults.showOnAllDisplays
        self.stacksEnabled = try container.decodeIfPresent(Bool.self, forKey: .stacksEnabled) ?? defaults.stacksEnabled
        self.secondClickEnabled = try container.decodeIfPresent(Bool.self, forKey: .secondClickEnabled) ?? defaults.secondClickEnabled
        self.windowSwitcherEnabled = try container.decodeIfPresent(Bool.self, forKey: .windowSwitcherEnabled) ?? defaults.windowSwitcherEnabled
        self.windowPreviewsEnabled = try container.decodeIfPresent(Bool.self, forKey: .windowPreviewsEnabled) ?? defaults.windowPreviewsEnabled
        self.folderPeekEnabled = try container.decodeIfPresent(Bool.self, forKey: .folderPeekEnabled) ?? defaults.folderPeekEnabled
        self.trashWidgetEnabled = try container.decodeIfPresent(Bool.self, forKey: .trashWidgetEnabled) ?? defaults.trashWidgetEnabled
        self.dateTimeWidgetEnabled = try container.decodeIfPresent(Bool.self, forKey: .dateTimeWidgetEnabled) ?? defaults.dateTimeWidgetEnabled
        self.mediaControlsEnabled = try container.decodeIfPresent(Bool.self, forKey: .mediaControlsEnabled) ?? defaults.mediaControlsEnabled
        self.hideMediaSourceAppIcon =
            try container.decodeIfPresent(Bool.self, forKey: .hideMediaSourceAppIcon) ?? defaults.hideMediaSourceAppIcon
        self.hideSystemDock = try container.decodeIfPresent(Bool.self, forKey: .hideSystemDock) ?? defaults.hideSystemDock
        self.bottomRevealDelayMilliseconds =
            try container.decodeIfPresent(Int.self, forKey: .bottomRevealDelayMilliseconds) ?? defaults.bottomRevealDelayMilliseconds
        self.appearance = try container.decodeIfPresent(SidebarAppearance.self, forKey: .appearance) ?? defaults.appearance
    }
}
