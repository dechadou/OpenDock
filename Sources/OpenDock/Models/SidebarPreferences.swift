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
    public var widgetPreferences: WidgetPreferences
    public var hideSystemDock: Bool
    public var bottomRevealDelayMilliseconds: Int
    public var appearance: SidebarAppearance

    public var trashWidgetEnabled: Bool {
        get { isWidgetEnabled(.trash) }
        set { widgetPreferences.setEnabled(newValue, for: .trash) }
    }

    public var dateTimeWidgetEnabled: Bool {
        get { isWidgetEnabled(.dateTime) }
        set { widgetPreferences.setEnabled(newValue, for: .dateTime) }
    }

    public var mediaControlsEnabled: Bool {
        get { isWidgetEnabled(.media) }
        set { widgetPreferences.setEnabled(newValue, for: .media) }
    }

    public var hideMediaSourceAppIcon: Bool {
        get {
            widgetPreferences.boolSetting(
                WidgetSettingIDs.hideMediaSourceAppIcon,
                for: .media,
                default: true
            )
        }
        set {
            widgetPreferences.setSetting(
                .bool(newValue),
                for: .media,
                settingID: WidgetSettingIDs.hideMediaSourceAppIcon
            )
        }
    }

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
        case widgetPreferences
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
        widgetPreferences: .defaults(),
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
        widgetPreferences: WidgetPreferences? = nil,
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
        self.hideSystemDock = hideSystemDock
        self.bottomRevealDelayMilliseconds = bottomRevealDelayMilliseconds
        self.appearance = appearance

        if let widgetPreferences {
            self.widgetPreferences = widgetPreferences.fillingDefaults()
        } else {
            self.widgetPreferences = Self.legacyWidgetPreferences(
                trashWidgetEnabled: trashWidgetEnabled,
                dateTimeWidgetEnabled: dateTimeWidgetEnabled,
                mediaControlsEnabled: mediaControlsEnabled,
                hideMediaSourceAppIcon: hideMediaSourceAppIcon
            )
        }
    }

    public var panelThickness: Double {
        max(64, iconSize + (spacing * 2) + 22)
    }

    public func isWidgetEnabled(_ widgetID: WidgetID, registry: WidgetRegistry = .shared) -> Bool {
        if widgetID == .windows {
            return windowSwitcherEnabled
        }

        let defaultEnabled = registry.manifest(for: widgetID)?.defaultEnabled ?? true
        return widgetPreferences.isEnabled(widgetID, default: defaultEnabled)
    }

    public func boolWidgetSetting(_ settingID: String, for widgetID: WidgetID, default defaultValue: Bool) -> Bool {
        widgetPreferences.boolSetting(settingID, for: widgetID, default: defaultValue)
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

        if let decodedWidgetPreferences = try container.decodeIfPresent(WidgetPreferences.self, forKey: .widgetPreferences) {
            self.widgetPreferences = decodedWidgetPreferences.fillingDefaults()
        } else {
            self.widgetPreferences = Self.legacyWidgetPreferences(
                trashWidgetEnabled: try container.decodeIfPresent(Bool.self, forKey: .trashWidgetEnabled) ?? defaults.trashWidgetEnabled,
                dateTimeWidgetEnabled: try container.decodeIfPresent(Bool.self, forKey: .dateTimeWidgetEnabled) ?? defaults.dateTimeWidgetEnabled,
                mediaControlsEnabled: try container.decodeIfPresent(Bool.self, forKey: .mediaControlsEnabled) ?? defaults.mediaControlsEnabled,
                hideMediaSourceAppIcon: try container.decodeIfPresent(Bool.self, forKey: .hideMediaSourceAppIcon) ?? defaults.hideMediaSourceAppIcon
            )
        }

        self.hideSystemDock = try container.decodeIfPresent(Bool.self, forKey: .hideSystemDock) ?? defaults.hideSystemDock
        self.bottomRevealDelayMilliseconds =
            try container.decodeIfPresent(Int.self, forKey: .bottomRevealDelayMilliseconds) ?? defaults.bottomRevealDelayMilliseconds
        self.appearance = try container.decodeIfPresent(SidebarAppearance.self, forKey: .appearance) ?? defaults.appearance
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(edge, forKey: .edge)
        try container.encode(iconSize, forKey: .iconSize)
        try container.encode(spacing, forKey: .spacing)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(autoHide, forKey: .autoHide)
        try container.encode(showOnAllDisplays, forKey: .showOnAllDisplays)
        try container.encode(stacksEnabled, forKey: .stacksEnabled)
        try container.encode(secondClickEnabled, forKey: .secondClickEnabled)
        try container.encode(windowSwitcherEnabled, forKey: .windowSwitcherEnabled)
        try container.encode(windowPreviewsEnabled, forKey: .windowPreviewsEnabled)
        try container.encode(folderPeekEnabled, forKey: .folderPeekEnabled)
        try container.encode(widgetPreferences, forKey: .widgetPreferences)
        try container.encode(trashWidgetEnabled, forKey: .trashWidgetEnabled)
        try container.encode(dateTimeWidgetEnabled, forKey: .dateTimeWidgetEnabled)
        try container.encode(mediaControlsEnabled, forKey: .mediaControlsEnabled)
        try container.encode(hideMediaSourceAppIcon, forKey: .hideMediaSourceAppIcon)
        try container.encode(hideSystemDock, forKey: .hideSystemDock)
        try container.encode(bottomRevealDelayMilliseconds, forKey: .bottomRevealDelayMilliseconds)
        try container.encode(appearance, forKey: .appearance)
    }

    private static func legacyWidgetPreferences(
        trashWidgetEnabled: Bool,
        dateTimeWidgetEnabled: Bool,
        mediaControlsEnabled: Bool,
        hideMediaSourceAppIcon: Bool
    ) -> WidgetPreferences {
        var widgetPreferences = WidgetPreferences.defaults()
        widgetPreferences.setEnabled(trashWidgetEnabled, for: .trash)
        widgetPreferences.setEnabled(dateTimeWidgetEnabled, for: .dateTime)
        widgetPreferences.setEnabled(mediaControlsEnabled, for: .media)
        widgetPreferences.setSetting(
            .bool(hideMediaSourceAppIcon),
            for: .media,
            settingID: WidgetSettingIDs.hideMediaSourceAppIcon
        )
        return widgetPreferences
    }
}
