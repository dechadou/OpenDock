import AppKit
import Foundation
import UniformTypeIdentifiers

enum DragDropPayload: Sendable {
    case sidebarItem(UUID)
    case fileURL(URL)
}

enum DragDropService {
    static let sidebarItemType = UTType(exportedAs: "\(AppIdentity.bundleIdentifier).sidebar-item")

    static func itemProvider(for item: SidebarItem) -> NSItemProvider {
        NSItemProvider(object: item.id.uuidString as NSString)
    }

    static func itemProvider(forFileURL url: URL) -> NSItemProvider {
        NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url.absoluteString as NSString)
    }

    static func loadPayloads(from providers: [NSItemProvider], completion: @escaping ([DragDropPayload]) -> Void) -> Bool {
        let collector = DragDropPayloadCollector()
        let group = DispatchGroup()
        var accepted = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                accepted = true
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }

                    if let data = item as? Data,
                        let url = URL(dataRepresentation: data, relativeTo: nil)
                    {
                        collector.append(.fileURL(url))
                    } else if let url = item as? URL {
                        collector.append(.fileURL(url))
                    }
                }
                continue
            }

            if provider.canLoadObject(ofClass: NSString.self) {
                accepted = true
                group.enter()
                provider.loadObject(ofClass: NSString.self) { object, _ in
                    defer { group.leave() }
                    if let string = object as? String,
                        let id = UUID(uuidString: string)
                    {
                        collector.append(.sidebarItem(id))
                    }
                }
            }
        }

        group.notify(queue: .main) {
            completion(collector.allPayloads())
        }

        return accepted
    }
}

private final class DragDropPayloadCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var payloads: [DragDropPayload] = []

    func append(_ payload: DragDropPayload) {
        lock.withLock {
            payloads.append(payload)
        }
    }

    func allPayloads() -> [DragDropPayload] {
        lock.withLock {
            payloads
        }
    }
}
