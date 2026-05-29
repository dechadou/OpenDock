import AppKit
import SwiftUI

struct LauncherView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var scanner: ApplicationScanner
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool
    @Environment(\.sidebarAppearance) private var appearance

    init(appModel: AppModel) {
        self.appModel = appModel
        self._scanner = ObservedObject(initialValue: appModel.applicationScanner)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(appearance.secondaryText.color)

                TextField("Search applications", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        openTopResult()
                    }

                Button {
                    scanner.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh applications")
            }
            .padding(12)

            Divider()

            List(filteredApplications) { application in
                Button {
                    appModel.openLaunchableApplication(application)
                } label: {
                    HStack(spacing: 10) {
                        Image(nsImage: AppActionService.icon(for: application))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(application.name)
                                .lineLimit(1)

                            Text(application.url.deletingLastPathComponent().path)
                                .font(.caption)
                                .foregroundStyle(appearance.secondaryText.color)
                                .lineLimit(1)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay {
                    AppContextMenuBridge(
                        menuProvider: {
                            AppContextMenuFactory.launchableApplicationMenu(
                                application: application,
                                runningApp: appModel.runningApp(for: application),
                                appModel: appModel
                            )
                        },
                        onMenuVisibilityChanged: { visible in
                            appModel.setSidebarInteractionSurface("launcher-menu-\(application.id)", visible: visible)
                        }
                    )
                }
            }
            .listStyle(.plain)
            .overlay {
                if !query.isEmpty && filteredApplications.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .foregroundStyle(appearance.primaryText.color)
        .background(appearance.popoverSurface.color)
        .onAppear {
            if scanner.applications.isEmpty {
                scanner.reload()
            }
            isSearchFocused = true
        }
    }

    private func openTopResult() {
        guard let first = filteredApplications.first else {
            return
        }

        appModel.openLaunchableApplication(first)
    }

    private var filteredApplications: [LaunchableApplication] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return scanner.applications
        }

        return scanner.applications.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.url.path.localizedCaseInsensitiveContains(trimmedQuery)
                || ($0.bundleIdentifier?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
        }
    }
}
