import AppKit
import Foundation
import SwiftUI

public struct SidebarRGBAColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
        self.alpha = Self.clamp(alpha)
    }

    public init(color: Color) {
        self.init(nsColor: NSColor(color))
    }

    public init(nsColor: NSColor) {
        let color = nsColor.usingColorSpace(.sRGB) ?? NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .white
        self.init(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )
    }

    public var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    public var isValid: Bool {
        [red, green, blue, alpha].allSatisfy { value in
            value >= 0 && value <= 1
        }
    }

    public static func rgba(_ red: Int, _ green: Int, _ blue: Int, alpha: Double = 1) -> SidebarRGBAColor {
        SidebarRGBAColor(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            alpha: alpha
        )
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

public struct SidebarAppearance: Codable, Equatable, Sendable {
    public var dockSurface: SidebarRGBAColor
    public var separator: SidebarRGBAColor
    public var primaryText: SidebarRGBAColor
    public var secondaryText: SidebarRGBAColor
    public var inverseText: SidebarRGBAColor
    public var activeIconFill: SidebarRGBAColor
    public var activeIconBorder: SidebarRGBAColor
    public var activeIconGlow: SidebarRGBAColor
    public var runningIndicator: SidebarRGBAColor
    public var badgeBackground: SidebarRGBAColor
    public var badgeText: SidebarRGBAColor
    public var badgeBorder: SidebarRGBAColor
    public var widgetBackground: SidebarRGBAColor
    public var widgetBorder: SidebarRGBAColor
    public var calendarHighlight: SidebarRGBAColor
    public var mediaOverlayBackground: SidebarRGBAColor
    public var popoverSurface: SidebarRGBAColor
    public var popoverBorder: SidebarRGBAColor

    private enum CodingKeys: String, CodingKey {
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
    }

    public static let defaults = SidebarAppearance()

    public init(
        dockSurface: SidebarRGBAColor = .rgba(28, 30, 34, alpha: 0.32),
        separator: SidebarRGBAColor = .rgba(255, 255, 255, alpha: 0.24),
        primaryText: SidebarRGBAColor = .rgba(242, 244, 248, alpha: 1),
        secondaryText: SidebarRGBAColor = .rgba(196, 202, 210, alpha: 0.74),
        inverseText: SidebarRGBAColor = .rgba(255, 255, 255, alpha: 1),
        activeIconFill: SidebarRGBAColor = .rgba(255, 255, 255, alpha: 0.18),
        activeIconBorder: SidebarRGBAColor = .rgba(255, 255, 255, alpha: 0.45),
        activeIconGlow: SidebarRGBAColor = .rgba(255, 255, 255, alpha: 0.16),
        runningIndicator: SidebarRGBAColor = .rgba(242, 244, 248, alpha: 0.42),
        badgeBackground: SidebarRGBAColor = .rgba(255, 69, 58, alpha: 1),
        badgeText: SidebarRGBAColor = .rgba(255, 255, 255, alpha: 1),
        badgeBorder: SidebarRGBAColor = .rgba(255, 255, 255, alpha: 0.9),
        widgetBackground: SidebarRGBAColor = .rgba(118, 118, 128, alpha: 0.22),
        widgetBorder: SidebarRGBAColor = .rgba(255, 255, 255, alpha: 0.12),
        calendarHighlight: SidebarRGBAColor = .rgba(0, 122, 255, alpha: 0.22),
        mediaOverlayBackground: SidebarRGBAColor = .rgba(0, 0, 0, alpha: 0.58),
        popoverSurface: SidebarRGBAColor = .rgba(28, 30, 34, alpha: 0.84),
        popoverBorder: SidebarRGBAColor = .rgba(255, 255, 255, alpha: 0.14)
    ) {
        self.dockSurface = dockSurface
        self.separator = separator
        self.primaryText = primaryText
        self.secondaryText = secondaryText
        self.inverseText = inverseText
        self.activeIconFill = activeIconFill
        self.activeIconBorder = activeIconBorder
        self.activeIconGlow = activeIconGlow
        self.runningIndicator = runningIndicator
        self.badgeBackground = badgeBackground
        self.badgeText = badgeText
        self.badgeBorder = badgeBorder
        self.widgetBackground = widgetBackground
        self.widgetBorder = widgetBorder
        self.calendarHighlight = calendarHighlight
        self.mediaOverlayBackground = mediaOverlayBackground
        self.popoverSurface = popoverSurface
        self.popoverBorder = popoverBorder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SidebarAppearance.defaults

        self.dockSurface = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .dockSurface) ?? defaults.dockSurface
        self.separator = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .separator) ?? defaults.separator
        self.primaryText = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .primaryText) ?? defaults.primaryText
        self.secondaryText = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .secondaryText) ?? defaults.secondaryText
        self.inverseText = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .inverseText) ?? defaults.inverseText
        self.activeIconFill = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .activeIconFill) ?? defaults.activeIconFill
        self.activeIconBorder = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .activeIconBorder) ?? defaults.activeIconBorder
        self.activeIconGlow = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .activeIconGlow) ?? defaults.activeIconGlow
        self.runningIndicator = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .runningIndicator) ?? defaults.runningIndicator
        self.badgeBackground = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .badgeBackground) ?? defaults.badgeBackground
        self.badgeText = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .badgeText) ?? defaults.badgeText
        self.badgeBorder = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .badgeBorder) ?? defaults.badgeBorder
        self.widgetBackground = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .widgetBackground) ?? defaults.widgetBackground
        self.widgetBorder = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .widgetBorder) ?? defaults.widgetBorder
        self.calendarHighlight = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .calendarHighlight) ?? defaults.calendarHighlight
        self.mediaOverlayBackground =
            try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .mediaOverlayBackground) ?? defaults.mediaOverlayBackground
        self.popoverSurface = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .popoverSurface) ?? defaults.popoverSurface
        self.popoverBorder = try container.decodeIfPresent(SidebarRGBAColor.self, forKey: .popoverBorder) ?? defaults.popoverBorder
    }
}
