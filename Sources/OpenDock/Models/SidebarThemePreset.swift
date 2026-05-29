import Foundation

public struct SidebarThemePreset: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var description: String
    public var appearance: SidebarAppearance
    public var swatches: [SidebarRGBAColor]

    public init(
        id: String,
        title: String,
        description: String,
        appearance: SidebarAppearance,
        swatches: [SidebarRGBAColor]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.appearance = appearance
        self.swatches = swatches
    }
}

public enum SidebarThemePresets {
    public static let customID = "custom"
    public static let defaultID = "opendock-default"

    public static let all: [SidebarThemePreset] = [
        preset(
            id: defaultID,
            title: "OpenDock Default",
            description: "Balanced translucent dark surface with bright status accents.",
            background: .rgba(28, 30, 34, alpha: 0.32),
            surface: .rgba(118, 118, 128, alpha: 0.22),
            popover: .rgba(28, 30, 34, alpha: 0.84),
            primary: .rgba(242, 244, 248),
            secondary: .rgba(196, 202, 210, alpha: 0.74),
            accent: .rgba(0, 122, 255, alpha: 0.24),
            alert: .rgba(255, 69, 58),
            glow: .rgba(255, 255, 255, alpha: 0.16)
        ),
        preset(
            id: "dracula",
            title: "Dracula",
            description: "High-contrast purple surfaces with pink and cyan accents.",
            background: .rgba(40, 42, 54, alpha: 0.86),
            surface: .rgba(68, 71, 90, alpha: 0.72),
            popover: .rgba(40, 42, 54, alpha: 0.94),
            primary: .rgba(248, 248, 242),
            secondary: .rgba(189, 147, 249, alpha: 0.82),
            accent: .rgba(139, 233, 253, alpha: 0.34),
            alert: .rgba(255, 85, 85),
            glow: .rgba(255, 121, 198, alpha: 0.32)
        ),
        preset(
            id: "catppuccin-mocha",
            title: "Catppuccin Mocha",
            description: "Soft warm dark base with lavender and mauve highlights.",
            background: .rgba(30, 30, 46, alpha: 0.88),
            surface: .rgba(49, 50, 68, alpha: 0.76),
            popover: .rgba(24, 24, 37, alpha: 0.94),
            primary: .rgba(205, 214, 244),
            secondary: .rgba(186, 194, 222, alpha: 0.78),
            accent: .rgba(180, 190, 254, alpha: 0.34),
            alert: .rgba(243, 139, 168),
            glow: .rgba(203, 166, 247, alpha: 0.34)
        ),
        preset(
            id: "nord",
            title: "Nord",
            description: "Cool arctic blue-gray surfaces with restrained frost accents.",
            background: .rgba(46, 52, 64, alpha: 0.86),
            surface: .rgba(67, 76, 94, alpha: 0.72),
            popover: .rgba(59, 66, 82, alpha: 0.94),
            primary: .rgba(236, 239, 244),
            secondary: .rgba(216, 222, 233, alpha: 0.76),
            accent: .rgba(136, 192, 208, alpha: 0.34),
            alert: .rgba(191, 97, 106),
            glow: .rgba(129, 161, 193, alpha: 0.28)
        ),
        preset(
            id: "gruvbox-dark",
            title: "Gruvbox Dark",
            description: "Retro low-contrast dark base with amber and green accents.",
            background: .rgba(40, 40, 40, alpha: 0.88),
            surface: .rgba(60, 56, 54, alpha: 0.78),
            popover: .rgba(29, 32, 33, alpha: 0.94),
            primary: .rgba(251, 241, 199),
            secondary: .rgba(213, 196, 161, alpha: 0.78),
            accent: .rgba(250, 189, 47, alpha: 0.34),
            alert: .rgba(251, 73, 52),
            glow: .rgba(184, 187, 38, alpha: 0.30)
        ),
        preset(
            id: "tokyo-night",
            title: "Tokyo Night",
            description: "Deep navy base with electric blue and magenta details.",
            background: .rgba(26, 27, 38, alpha: 0.90),
            surface: .rgba(41, 46, 66, alpha: 0.76),
            popover: .rgba(22, 22, 30, alpha: 0.95),
            primary: .rgba(192, 202, 245),
            secondary: .rgba(169, 177, 214, alpha: 0.78),
            accent: .rgba(122, 162, 247, alpha: 0.36),
            alert: .rgba(247, 118, 142),
            glow: .rgba(187, 154, 247, alpha: 0.32)
        ),
        preset(
            id: "rose-pine",
            title: "Rosé Pine",
            description: "Muted romantic dark palette with rose and foam accents.",
            background: .rgba(25, 23, 36, alpha: 0.90),
            surface: .rgba(38, 35, 58, alpha: 0.78),
            popover: .rgba(31, 29, 46, alpha: 0.95),
            primary: .rgba(224, 222, 244),
            secondary: .rgba(144, 140, 170, alpha: 0.86),
            accent: .rgba(235, 188, 186, alpha: 0.34),
            alert: .rgba(235, 111, 146),
            glow: .rgba(196, 167, 231, alpha: 0.32)
        ),
        preset(
            id: "solarized-dark",
            title: "Solarized Dark",
            description: "Classic low-glare blue-green base with cyan highlights.",
            background: .rgba(0, 43, 54, alpha: 0.90),
            surface: .rgba(7, 54, 66, alpha: 0.78),
            popover: .rgba(0, 43, 54, alpha: 0.96),
            primary: .rgba(238, 232, 213),
            secondary: .rgba(147, 161, 161, alpha: 0.82),
            accent: .rgba(42, 161, 152, alpha: 0.34),
            alert: .rgba(220, 50, 47),
            glow: .rgba(38, 139, 210, alpha: 0.30)
        ),
        preset(
            id: "everforest-dark",
            title: "Everforest Dark",
            description: "Natural green dark palette with calm warm contrast.",
            background: .rgba(45, 53, 59, alpha: 0.90),
            surface: .rgba(64, 73, 77, alpha: 0.78),
            popover: .rgba(39, 46, 51, alpha: 0.95),
            primary: .rgba(211, 198, 170),
            secondary: .rgba(157, 169, 160, alpha: 0.82),
            accent: .rgba(167, 192, 128, alpha: 0.34),
            alert: .rgba(230, 126, 128),
            glow: .rgba(131, 192, 146, alpha: 0.30)
        ),
        preset(
            id: "github-dark",
            title: "GitHub Dark / Primer",
            description: "Neutral GitHub-inspired dark UI with clear blue accents.",
            background: .rgba(13, 17, 23, alpha: 0.90),
            surface: .rgba(22, 27, 34, alpha: 0.82),
            popover: .rgba(13, 17, 23, alpha: 0.96),
            primary: .rgba(230, 237, 243),
            secondary: .rgba(139, 148, 158, alpha: 0.86),
            accent: .rgba(47, 129, 247, alpha: 0.34),
            alert: .rgba(248, 81, 73),
            glow: .rgba(88, 166, 255, alpha: 0.28)
        ),
    ]

    public static func matchingPresetID(for appearance: SidebarAppearance) -> String? {
        all.first { $0.appearance == appearance }?.id
    }

    public static func preset(id: String) -> SidebarThemePreset? {
        all.first { $0.id == id }
    }

    private static func preset(
        id: String,
        title: String,
        description: String,
        background: SidebarRGBAColor,
        surface: SidebarRGBAColor,
        popover: SidebarRGBAColor,
        primary: SidebarRGBAColor,
        secondary: SidebarRGBAColor,
        accent: SidebarRGBAColor,
        alert: SidebarRGBAColor,
        glow: SidebarRGBAColor
    ) -> SidebarThemePreset {
        let appearance = SidebarAppearance(
            dockSurface: background,
            separator: SidebarRGBAColor(red: primary.red, green: primary.green, blue: primary.blue, alpha: 0.22),
            primaryText: primary,
            secondaryText: secondary,
            inverseText: .rgba(255, 255, 255),
            activeIconFill: accent,
            activeIconBorder: SidebarRGBAColor(red: primary.red, green: primary.green, blue: primary.blue, alpha: 0.44),
            activeIconGlow: glow,
            runningIndicator: SidebarRGBAColor(red: primary.red, green: primary.green, blue: primary.blue, alpha: 0.46),
            badgeBackground: alert,
            badgeText: .rgba(255, 255, 255),
            badgeBorder: SidebarRGBAColor(red: primary.red, green: primary.green, blue: primary.blue, alpha: 0.72),
            widgetBackground: surface,
            widgetBorder: SidebarRGBAColor(red: primary.red, green: primary.green, blue: primary.blue, alpha: 0.14),
            calendarHighlight: accent,
            mediaOverlayBackground: .rgba(0, 0, 0, alpha: 0.58),
            popoverSurface: popover,
            popoverBorder: SidebarRGBAColor(red: primary.red, green: primary.green, blue: primary.blue, alpha: 0.16)
        )

        return SidebarThemePreset(
            id: id,
            title: title,
            description: description,
            appearance: appearance,
            swatches: [background, surface, primary, accent, alert]
        )
    }
}
