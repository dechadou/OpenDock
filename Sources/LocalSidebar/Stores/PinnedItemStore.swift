import Combine
import Foundation

@MainActor
public final class PinnedItemStore: ObservableObject {
    @Published public private(set) var items: [PinnedItem] = []

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            self.fileURL =
                (try? FileSystemLocations.applicationSupportDirectory()
                    .appendingPathComponent("PinnedItems.json")) ?? URL(fileURLWithPath: "/tmp/LocalSidebar-PinnedItems.json")
        }

        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        load()
    }

    public func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            items = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            items = try decoder.decode([PinnedItem].self, from: data)
        } catch {
            items = []
            NSLog("LocalSidebar: failed to load pinned items: \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func add(
        kind: PinnedItem.Kind,
        title: String,
        url: URL,
        bundleIdentifier: String? = nil
    ) -> PinnedItem {
        let item = PinnedItem(
            kind: kind,
            title: title,
            url: url,
            bundleIdentifier: bundleIdentifier
        )
        return add(item)
    }

    @discardableResult
    public func add(_ item: PinnedItem) -> PinnedItem {
        if let existing = items.first(where: { isDuplicate($0, item) }) {
            return existing
        }

        items.append(item)
        save()
        return item
    }

    public func remove(id: PinnedItem.ID) {
        items.removeAll { $0.id == id }
        save()
    }

    public func clear() {
        items = []
        save()
    }

    private func save() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("LocalSidebar: failed to save pinned items: \(error.localizedDescription)")
        }
    }

    private func isDuplicate(_ lhs: PinnedItem, _ rhs: PinnedItem) -> Bool {
        if let lhsBundle = lhs.bundleIdentifier,
            let rhsBundle = rhs.bundleIdentifier,
            !lhsBundle.isEmpty,
            lhsBundle == rhsBundle
        {
            return true
        }

        return lhs.url.standardizedFileURL == rhs.url.standardizedFileURL
    }
}
