import AppKit
import SwiftUI

struct FolderPeekView: View {
    var folderURL: URL
    @ObservedObject var appModel: AppModel

    private var entries: [FolderEntry] {
        FolderPeekService.entries(in: folderURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(nsImage: NSWorkspace.shared.icon(forFile: folderURL.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)

                Text(folderURL.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button {
                    NSWorkspace.shared.open(folderURL)
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.borderless)
                .help("Open in Finder")
            }
            .padding(12)

            Divider()

            if entries.isEmpty {
                ContentUnavailableView("No Items", systemImage: "folder")
            } else {
                List(entries) { entry in
                    Button {
                        NSWorkspace.shared.open(entry.url)
                    } label: {
                        HStack(spacing: 10) {
                            Image(nsImage: AppActionService.icon(for: entry))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)

                            Text(entry.title)
                                .lineLimit(1)

                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Open") {
                            NSWorkspace.shared.open(entry.url)
                        }
                        Button("Reveal in Finder") {
                            AppActionService.revealInFinder(entry.url)
                        }
                        Button("Pin to Sidebar") {
                            appModel.addURLToSidebar(entry.url)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
