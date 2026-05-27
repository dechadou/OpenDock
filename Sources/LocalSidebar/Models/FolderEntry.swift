import Foundation

public struct FolderEntry: Identifiable, Equatable, Sendable {
    public var id: URL { url }
    public var title: String
    public var url: URL
    public var isDirectory: Bool
}
