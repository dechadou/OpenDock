import CoreGraphics
import Foundation

public enum SidebarDockLayout {
    public struct Sections: Equatable, Sendable {
        public var stacks: [SidebarItem]
        public var pinnedItems: [SidebarItem]
        public var finalSystemItems: [SidebarItem]

        public var hasUserItems: Bool {
            !stacks.isEmpty || !pinnedItems.isEmpty
        }
    }

    public static let finalSystemItemOrder: [SidebarItem.SystemKind] = [
        .windowSwitcher,
        .dateTime,
        .media,
        .trash,
    ]

    public static func sections(from items: [SidebarItem]) -> Sections {
        Sections(
            stacks: items.filter { $0.kind == .stack },
            pinnedItems: items.filter(isPinnedItem),
            finalSystemItems: finalSystemItems(from: items)
        )
    }

    public static func primaryItems(from items: [SidebarItem]) -> [SidebarItem] {
        items.filter { !isTrash($0) }
    }

    public static func trashItem(from items: [SidebarItem]) -> SidebarItem? {
        items.first(where: isTrash)
    }

    public static func estimatedLength(
        itemCount: Int,
        dividerCount: Int,
        iconSize: CGFloat,
        spacing: CGFloat,
        mediaControlCount: Int = 0,
        mediaUsesInlineLength: Bool = false,
        contentPadding: CGFloat = 10
    ) -> CGFloat {
        let totalItemCount = itemCount + mediaControlCount
        guard totalItemCount > 0 else {
            return contentPadding * 2
        }

        let itemSide = iconSize + 12
        let itemLength = CGFloat(itemCount) * itemSide
        let mediaLength = CGFloat(mediaControlCount) * (mediaUsesInlineLength ? mediaControlLength(iconSize: iconSize) : itemSide)
        let elementCount = totalItemCount + dividerCount
        let spacingLength = CGFloat(max(0, elementCount - 1)) * spacing
        let dividerLength = CGFloat(dividerCount) * dividerRuleLength
        return itemLength + mediaLength + spacingLength + dividerLength + (contentPadding * 2)
    }

    public static func mediaControlLength(iconSize: CGFloat) -> CGFloat {
        max(290, iconSize * 5.5)
    }

    public static func sectionDividerLength(spacing: CGFloat) -> CGFloat {
        dividerRuleLength + (spacing * 2)
    }

    private static let dividerRuleLength: CGFloat = 1

    public static func isPinnedItem(_ item: SidebarItem) -> Bool {
        switch item.kind {
        case .application, .file, .folder, .url:
            return true
        case .stack, .system:
            return false
        }
    }

    private static func finalSystemItems(from items: [SidebarItem]) -> [SidebarItem] {
        finalSystemItemOrder.compactMap { systemKind in
            items.first { $0.kind == .system && $0.systemKind == systemKind }
        }
    }

    private static func isTrash(_ item: SidebarItem) -> Bool {
        item.kind == .system && item.systemKind == .trash
    }
}
