import Combine
import Foundation

@MainActor
public final class SidebarItemStore: ObservableObject {
    @Published public private(set) var items: [SidebarItem] = []

    private let fileURL: URL
    private let legacyPinnedItemsURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL? = nil, legacyPinnedItemsURL: URL? = nil) {
        let supportDirectory = try? FileSystemLocations.applicationSupportDirectory()
        self.fileURL =
            fileURL
            ?? supportDirectory?.appendingPathComponent("SidebarItems.json")
            ?? URL(fileURLWithPath: "/tmp/\(AppIdentity.displayName)-SidebarItems.json")
        self.legacyPinnedItemsURL =
            legacyPinnedItemsURL
            ?? supportDirectory?.appendingPathComponent("PinnedItems.json")
            ?? URL(fileURLWithPath: "/tmp/\(AppIdentity.displayName)-PinnedItems.json")

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
    }

    public func load() {
        if FileManager.default.fileExists(atPath: fileURL.path),
            let loaded = try? decoder.decode([SidebarItem].self, from: Data(contentsOf: fileURL))
        {
            items = loaded
            ensureDefaultSystemItems()
            save()
            return
        }

        migrateLegacyPinnedItems()
        ensureDefaultSystemItems()
        save()
    }

    @discardableResult
    public func add(_ item: SidebarItem) -> SidebarItem {
        if let existing = items.first(where: { isDuplicate($0, item) }) {
            return existing
        }

        items.append(item)
        save()
        return item
    }

    @discardableResult
    public func add(
        kind: SidebarItem.Kind,
        title: String,
        url: URL? = nil,
        bundleIdentifier: String? = nil
    ) -> SidebarItem {
        add(SidebarItem(kind: kind, title: title, url: url, bundleIdentifier: bundleIdentifier))
    }

    @discardableResult
    public func createStack(title: String = "Stack") -> SidebarItem {
        add(SidebarItem(kind: .stack, title: title, children: []))
    }

    public func remove(id: SidebarItem.ID) {
        items.removeAll { $0.id == id }
        for index in items.indices {
            items[index].children.removeAll { $0.id == id }
        }
        save()
    }

    public func replace(_ item: SidebarItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            save()
            return
        }

        for index in items.indices {
            if let childIndex = items[index].children.firstIndex(where: { $0.id == item.id }) {
                items[index].children[childIndex] = item
                save()
                return
            }
        }
    }

    public func moveMainItem(id: SidebarItem.ID, before targetID: SidebarItem.ID?) {
        guard let sourceIndex = items.firstIndex(where: { $0.id == id }) else {
            return
        }

        let item = items.remove(at: sourceIndex)
        let insertionIndex: Int
        if let targetID, let targetIndex = items.firstIndex(where: { $0.id == targetID }) {
            insertionIndex = targetIndex
        } else {
            insertionIndex = items.count
        }

        items.insert(item, at: insertionIndex)
        save()
    }

    public func movePinnedItem(id: SidebarItem.ID, before targetID: SidebarItem.ID?) {
        guard let sourceIndex = items.firstIndex(where: { $0.id == id }),
            Self.canBePinnedItem(items[sourceIndex])
        else {
            return
        }

        let item = items.remove(at: sourceIndex)
        let insertionIndex: Int
        if let targetID,
            let targetIndex = items.firstIndex(where: { $0.id == targetID && Self.canBePinnedItem($0) })
        {
            insertionIndex = targetIndex
        } else {
            insertionIndex =
                items
                .lastIndex(where: { $0.kind == .stack || Self.canBePinnedItem($0) })
                .map { $0 + 1 }
                ?? 0
        }

        items.insert(item, at: insertionIndex)
        save()
    }

    public func addItem(_ child: SidebarItem, toStack stackID: SidebarItem.ID) {
        guard let stackIndex = items.firstIndex(where: { $0.id == stackID && $0.kind == .stack }) else {
            return
        }

        guard Self.canBeStackChild(child) else {
            return
        }

        if items[stackIndex].children.contains(where: { isDuplicate($0, child) }) {
            return
        }

        var childCopy = child
        childCopy.children = []
        items[stackIndex].children.append(childCopy)
        save()
    }

    public func moveMainItemIntoStack(itemID: SidebarItem.ID, stackID: SidebarItem.ID) {
        guard let sourceIndex = items.firstIndex(where: { $0.id == itemID }),
            let stackIndex = items.firstIndex(where: { $0.id == stackID && $0.kind == .stack }),
            itemID != stackID,
            Self.canBeStackChild(items[sourceIndex])
        else {
            return
        }

        var item = items.remove(at: sourceIndex)
        item.children = []
        let adjustedStackIndex = sourceIndex < stackIndex ? stackIndex - 1 : stackIndex
        items[adjustedStackIndex].children.append(item)
        save()
    }

    public func moveChildOutOfStack(childID: SidebarItem.ID, stackID: SidebarItem.ID) {
        guard let stackIndex = items.firstIndex(where: { $0.id == stackID && $0.kind == .stack }),
            let childIndex = items[stackIndex].children.firstIndex(where: { $0.id == childID })
        else {
            return
        }

        let item = items[stackIndex].children.remove(at: childIndex)
        items.insert(item, at: min(stackIndex + 1, items.count))
        save()
    }

    public func reorderChild(stackID: SidebarItem.ID, childID: SidebarItem.ID, before targetID: SidebarItem.ID?) {
        guard let stackIndex = items.firstIndex(where: { $0.id == stackID && $0.kind == .stack }),
            let sourceIndex = items[stackIndex].children.firstIndex(where: { $0.id == childID })
        else {
            return
        }

        let item = items[stackIndex].children.remove(at: sourceIndex)
        let insertionIndex: Int
        if let targetID, let targetIndex = items[stackIndex].children.firstIndex(where: { $0.id == targetID }) {
            insertionIndex = targetIndex
        } else {
            insertionIndex = items[stackIndex].children.count
        }

        items[stackIndex].children.insert(item, at: insertionIndex)
        save()
    }

    public func item(id: SidebarItem.ID) -> SidebarItem? {
        if let item = items.first(where: { $0.id == id }) {
            return item
        }

        return items.lazy.flatMap(\.children).first { $0.id == id }
    }

    public func containsApplication(bundleIdentifier: String?, url: URL?) -> Bool {
        items.contains { item in
            containsApplication(in: item, bundleIdentifier: bundleIdentifier, url: url)
        }
    }

    public func clear() {
        items = []
        save()
    }

    func save() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("\(AppIdentity.displayName): failed to save sidebar items: \(error.localizedDescription)")
        }
    }

    private func migrateLegacyPinnedItems() {
        guard FileManager.default.fileExists(atPath: legacyPinnedItemsURL.path),
            let data = try? Data(contentsOf: legacyPinnedItemsURL),
            let pinnedItems = try? decoder.decode([PinnedItem].self, from: data)
        else {
            items = []
            return
        }

        items = pinnedItems.map(SidebarItem.fromPinnedItem)
    }

    private func ensureDefaultSystemItems() {
        for kind in SidebarItem.SystemKind.allCases where !containsSystemItem(kind) {
            items.append(.system(kind))
        }
    }

    private func containsSystemItem(_ kind: SidebarItem.SystemKind) -> Bool {
        items.contains { $0.kind == .system && $0.systemKind == kind }
    }

    private static func canBeStackChild(_ item: SidebarItem) -> Bool {
        switch item.kind {
        case .application, .file, .folder, .url:
            return true
        case .stack, .system:
            return false
        }
    }

    private static func canBePinnedItem(_ item: SidebarItem) -> Bool {
        switch item.kind {
        case .application, .file, .folder, .url:
            return true
        case .stack, .system:
            return false
        }
    }

    private func containsApplication(in item: SidebarItem, bundleIdentifier: String?, url: URL?) -> Bool {
        if item.kind == .application {
            if let itemBundle = item.bundleIdentifier,
                let bundleIdentifier,
                !itemBundle.isEmpty,
                itemBundle == bundleIdentifier
            {
                return true
            }

            if let itemURL = item.url,
                let url,
                itemURL.standardizedFileURL == url.standardizedFileURL
            {
                return true
            }
        }

        return item.children.contains {
            containsApplication(in: $0, bundleIdentifier: bundleIdentifier, url: url)
        }
    }

    private func isDuplicate(_ lhs: SidebarItem, _ rhs: SidebarItem) -> Bool {
        if lhs.kind == .system || rhs.kind == .system {
            return lhs.systemKind == rhs.systemKind
        }

        if let lhsBundle = lhs.bundleIdentifier,
            let rhsBundle = rhs.bundleIdentifier,
            !lhsBundle.isEmpty,
            lhsBundle == rhsBundle
        {
            return true
        }

        if let lhsURL = lhs.url,
            let rhsURL = rhs.url
        {
            return lhsURL.standardizedFileURL == rhsURL.standardizedFileURL
        }

        return false
    }
}
