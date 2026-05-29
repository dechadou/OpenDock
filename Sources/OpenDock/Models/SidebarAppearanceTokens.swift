import Foundation

public enum SidebarAppearanceTokenGroup: String, CaseIterable, Identifiable, Sendable {
    case dock
    case icons
    case text
    case widgets
    case popovers

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dock:
            return "Dock"
        case .icons:
            return "Icons & Status"
        case .text:
            return "Text"
        case .widgets:
            return "Widgets"
        case .popovers:
            return "Popovers"
        }
    }
}

public enum SidebarAppearancePreviewKind: String, Sendable {
    case dockSurface
    case separator
    case text
    case iconState
    case badge
    case widget
    case calendar
    case mediaOverlay
    case popover
}

public enum SidebarAppearanceTokenID: String, CaseIterable, Identifiable, Codable, Sendable {
    case dockSurface
    case separator
    case primaryText
    case secondaryText
    case inverseText
    case activeIconFill
    case activeIconBorder
    case activeIconGlow
    case runningIndicator
    case badgeBackground
    case badgeText
    case badgeBorder
    case widgetBackground
    case widgetBorder
    case calendarHighlight
    case mediaOverlayBackground
    case popoverSurface
    case popoverBorder

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dockSurface:
            return "Dock surface"
        case .separator:
            return "Section divider"
        case .primaryText:
            return "Primary text"
        case .secondaryText:
            return "Secondary text"
        case .inverseText:
            return "Overlay text"
        case .activeIconFill:
            return "Active icon fill"
        case .activeIconBorder:
            return "Active icon border"
        case .activeIconGlow:
            return "Active icon glow"
        case .runningIndicator:
            return "Running indicator"
        case .badgeBackground:
            return "Badge background"
        case .badgeText:
            return "Badge text"
        case .badgeBorder:
            return "Badge border"
        case .widgetBackground:
            return "Widget background"
        case .widgetBorder:
            return "Widget border"
        case .calendarHighlight:
            return "Calendar highlight"
        case .mediaOverlayBackground:
            return "Media overlay"
        case .popoverSurface:
            return "Popover surface"
        case .popoverBorder:
            return "Popover border"
        }
    }

    public var affectedArea: String {
        switch self {
        case .dockSurface:
            return "The translucent panel behind dock items."
        case .separator:
            return "Dividers between stacks, pinned apps, running apps, and widgets."
        case .primaryText:
            return "Main labels in widgets, popovers, previews, and settings-adjacent surfaces."
        case .secondaryText:
            return "Subtitles, metadata, helper labels, and inactive empty states."
        case .inverseText:
            return "Text placed over dark artwork or overlay chips."
        case .activeIconFill:
            return "The fill behind the currently frontmost app icon."
        case .activeIconBorder:
            return "The outline around the currently frontmost app icon."
        case .activeIconGlow:
            return "The soft glow around the currently frontmost app icon."
        case .runningIndicator:
            return "The small status marker under running apps."
        case .badgeBackground:
            return "Notification badges on apps and Trash."
        case .badgeText:
            return "Numbers inside notification badges."
        case .badgeBorder:
            return "The outline around notification badges."
        case .widgetBackground:
            return "Calendar, stack, media controls, and thumbnail placeholders."
        case .widgetBorder:
            return "Borders around compact widgets and media controls."
        case .calendarHighlight:
            return "Today indicator inside the calendar popover."
        case .mediaOverlayBackground:
            return "The text chip over album artwork."
        case .popoverSurface:
            return "Launcher, stack, media, calendar, and window popover backgrounds."
        case .popoverBorder:
            return "Preview tile and popover content borders."
        }
    }

    public var group: SidebarAppearanceTokenGroup {
        switch self {
        case .dockSurface, .separator:
            return .dock
        case .activeIconFill, .activeIconBorder, .activeIconGlow, .runningIndicator, .badgeBackground, .badgeText, .badgeBorder:
            return .icons
        case .primaryText, .secondaryText, .inverseText:
            return .text
        case .widgetBackground, .widgetBorder, .calendarHighlight, .mediaOverlayBackground:
            return .widgets
        case .popoverSurface, .popoverBorder:
            return .popovers
        }
    }

    public var previewKind: SidebarAppearancePreviewKind {
        switch self {
        case .dockSurface:
            return .dockSurface
        case .separator:
            return .separator
        case .primaryText, .secondaryText, .inverseText:
            return .text
        case .activeIconFill, .activeIconBorder, .activeIconGlow, .runningIndicator:
            return .iconState
        case .badgeBackground, .badgeText, .badgeBorder:
            return .badge
        case .widgetBackground, .widgetBorder:
            return .widget
        case .calendarHighlight:
            return .calendar
        case .mediaOverlayBackground:
            return .mediaOverlay
        case .popoverSurface, .popoverBorder:
            return .popover
        }
    }
}

extension SidebarAppearance {
    public subscript(token token: SidebarAppearanceTokenID) -> SidebarRGBAColor {
        get {
            switch token {
            case .dockSurface:
                return dockSurface
            case .separator:
                return separator
            case .primaryText:
                return primaryText
            case .secondaryText:
                return secondaryText
            case .inverseText:
                return inverseText
            case .activeIconFill:
                return activeIconFill
            case .activeIconBorder:
                return activeIconBorder
            case .activeIconGlow:
                return activeIconGlow
            case .runningIndicator:
                return runningIndicator
            case .badgeBackground:
                return badgeBackground
            case .badgeText:
                return badgeText
            case .badgeBorder:
                return badgeBorder
            case .widgetBackground:
                return widgetBackground
            case .widgetBorder:
                return widgetBorder
            case .calendarHighlight:
                return calendarHighlight
            case .mediaOverlayBackground:
                return mediaOverlayBackground
            case .popoverSurface:
                return popoverSurface
            case .popoverBorder:
                return popoverBorder
            }
        }
        set {
            switch token {
            case .dockSurface:
                dockSurface = newValue
            case .separator:
                separator = newValue
            case .primaryText:
                primaryText = newValue
            case .secondaryText:
                secondaryText = newValue
            case .inverseText:
                inverseText = newValue
            case .activeIconFill:
                activeIconFill = newValue
            case .activeIconBorder:
                activeIconBorder = newValue
            case .activeIconGlow:
                activeIconGlow = newValue
            case .runningIndicator:
                runningIndicator = newValue
            case .badgeBackground:
                badgeBackground = newValue
            case .badgeText:
                badgeText = newValue
            case .badgeBorder:
                badgeBorder = newValue
            case .widgetBackground:
                widgetBackground = newValue
            case .widgetBorder:
                widgetBorder = newValue
            case .calendarHighlight:
                calendarHighlight = newValue
            case .mediaOverlayBackground:
                mediaOverlayBackground = newValue
            case .popoverSurface:
                popoverSurface = newValue
            case .popoverBorder:
                popoverBorder = newValue
            }
        }
    }

    public mutating func reset(_ token: SidebarAppearanceTokenID) {
        self[token: token] = SidebarAppearance.defaults[token: token]
    }

    public mutating func resetAll() {
        self = .defaults
    }

    public var isComplete: Bool {
        SidebarAppearanceTokenID.allCases.allSatisfy { self[token: $0].isValid }
    }
}
