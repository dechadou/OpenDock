import AppKit
import Combine
import Foundation

@MainActor
public final class ApplicationScanner: ObservableObject {
    @Published public private(set) var applications: [LaunchableApplication] = []

    public func reload() {
        let directories = Self.defaultSearchDirectories()

        DispatchQueue.global(qos: .userInitiated).async {
            let applications = Self.scan(directories: directories)

            Task { @MainActor [weak self] in
                self?.applications = applications
            }
        }
    }

    public nonisolated static func defaultSearchDirectories(fileManager: FileManager = .default) -> [URL] {
        var directories = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
        ]

        directories.removeAll { !fileManager.fileExists(atPath: $0.path) }
        return directories
    }

    public nonisolated static func scan(
        directories: [URL],
        fileManager: FileManager = .default
    ) -> [LaunchableApplication] {
        var result: [LaunchableApplication] = []
        var seen = Set<String>()

        for directory in directories {
            guard
                let enumerator = fileManager.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
            else {
                continue
            }

            for case let url as URL in enumerator where url.pathExtension == "app" {
                let application = launchableApplication(at: url)
                let key = application.bundleIdentifier ?? application.url.path

                guard seen.insert(key).inserted else {
                    continue
                }

                result.append(application)
            }
        }

        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    nonisolated private static func launchableApplication(at url: URL) -> LaunchableApplication {
        let bundle = Bundle(url: url)
        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
        let name = displayName ?? bundleName ?? url.deletingPathExtension().lastPathComponent

        return LaunchableApplication(
            name: name,
            url: url,
            bundleIdentifier: bundle?.bundleIdentifier
        )
    }
}
