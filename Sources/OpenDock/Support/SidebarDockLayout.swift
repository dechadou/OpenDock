import CoreGraphics
import Foundation

public enum SidebarDockLayout {
    public struct Sections: Equatable, Sendable {
        public var userItems: [SidebarItem]
        public var finalWidgets: [SidebarItem]

        public var stacks: [SidebarItem] {
            userItems.filter { $0.kind == .stack }
        }

        public var pinnedItems: [SidebarItem] {
            userItems.filter(Self.isPinnedItem)
        }

        public var hasUserItems: Bool {
            !userItems.isEmpty
        }

        private static func isPinnedItem(_ item: SidebarItem) -> Bool {
            SidebarDockLayout.isPinnedItem(item)
        }
    }

    public static func sections(from items: [SidebarItem], registry: WidgetRegistry = .shared) -> Sections {
        Sections(
            userItems: items.filter(isUserItem),
            finalWidgets: finalWidgets(from: items, registry: registry)
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
        additionalItemLengths: [CGFloat] = [],
        contentPadding: CGFloat = 10
    ) -> CGFloat {
        let totalItemCount = itemCount + additionalItemLengths.count
        guard totalItemCount > 0 else {
            return contentPadding * 2
        }

        let itemSide = iconSize + 12
        let itemLength = CGFloat(itemCount) * itemSide
        let additionalLength = additionalItemLengths.reduce(CGFloat(0), +)
        let elementCount = totalItemCount + dividerCount
        let spacingLength = CGFloat(max(0, elementCount - 1)) * spacing
        let dividerLength = CGFloat(dividerCount) * dividerRuleLength
        return itemLength + additionalLength + spacingLength + dividerLength + (contentPadding * 2)
    }

    public static func widgetLength(
        for item: SidebarItem,
        edge: SidebarEdge,
        iconSize: CGFloat,
        registry: WidgetRegistry = .shared
    ) -> CGFloat {
        guard let widgetID = item.widgetID,
            let manifest = registry.manifest(for: widgetID)
        else {
            return iconSize + 12
        }

        return manifest.dockSize.length(edge: edge, iconSize: iconSize)
    }

    public static func sectionDividerLength(spacing: CGFloat) -> CGFloat {
        dividerRuleLength + (spacing * 2)
    }

    private static let dividerRuleLength: CGFloat = 1

    public static func isPinnedItem(_ item: SidebarItem) -> Bool {
        switch item.kind {
        case .application, .file, .folder, .url:
            return true
        case .stack, .space, .system:
            return false
        }
    }

    public static func isUserItem(_ item: SidebarItem) -> Bool {
        switch item.kind {
        case .application, .file, .folder, .url, .stack, .space:
            return true
        case .system:
            return false
        }
    }

    private static func finalWidgets(from items: [SidebarItem], registry: WidgetRegistry) -> [SidebarItem] {
        items
            .enumerated()
            .filter { _, item in
                guard item.kind == .system,
                    let widgetID = item.widgetID,
                    registry.manifest(for: widgetID)?.placement == .final
                else {
                    return false
                }

                return true
            }
            .sorted { lhs, rhs in
                let lhsManifest = lhs.element.widgetID.flatMap { registry.manifest(for: $0) }
                let rhsManifest = rhs.element.widgetID.flatMap { registry.manifest(for: $0) }
                let lhsOrder = lhsManifest?.order ?? Int.max
                let rhsOrder = rhsManifest?.order ?? Int.max

                if lhsOrder == rhsOrder {
                    return lhs.offset < rhs.offset
                }

                return lhsOrder < rhsOrder
            }
            .map(\.element)
    }

    private static func isTrash(_ item: SidebarItem) -> Bool {
        item.kind == .system && item.widgetID == .trash
    }
}
