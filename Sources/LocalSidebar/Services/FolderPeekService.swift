import Foundation

public enum FolderPeekService {
    public static func entries(in folderURL: URL, includeHidden: Bool = false, limit: Int = 80) -> [FolderEntry] {
        guard folderURL.isFileURL,
            let urls = try? FileManager.default.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
                options: includeHidden ? [] : [.skipsHiddenFiles]
            )
        else {
            return []
        }

        return
            urls
            .compactMap { url -> FolderEntry? in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
                if includeHidden == false && values?.isHidden == true {
                    return nil
                }

                return FolderEntry(
                    title: url.lastPathComponent,
                    url: url,
                    isDirectory: values?.isDirectory == true
                )
            }
            .sorted {
                if $0.isDirectory != $1.isDirectory {
                    return $0.isDirectory
                }

                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
}
