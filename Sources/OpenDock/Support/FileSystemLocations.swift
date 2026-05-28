import Foundation

enum FileSystemLocations {
    static func applicationSupportDirectory(fileManager: FileManager = .default) throws -> URL {
        guard let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        let directory = baseURL.appendingPathComponent(
            AppIdentity.applicationSupportDirectoryName,
            isDirectory: true
        )

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
