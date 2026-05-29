import SwiftUI

public struct AboutView: View {
    public init() {}

    public var body: some View {
        AboutContentView()
            .padding(28)
            .frame(width: 460, height: 360)
    }
}

struct AboutContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "dock.rectangle")
                    .font(.system(size: 42, weight: .medium))
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppIdentity.displayName)
                        .font(.system(size: 28, weight: .semibold))

                    Text(versionText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Text("A fast, local-first macOS dock replacement built for precise app switching, stacks, widgets, window previews, and deep visual customization.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Link(destination: AppIdentity.githubProfileURL) {
                    Label("GitHub Profile", systemImage: "person.crop.circle")
                }

                Link(destination: AppIdentity.githubRepositoryURL) {
                    Label("OpenDock Repository", systemImage: "curlybraces")
                }
            }
            .buttonStyle(.link)

            Spacer(minLength: 0)
        }
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case (.some(let version), .some(let build)):
            return "Version \(version) (\(build))"
        case (.some(let version), .none):
            return "Version \(version)"
        case (.none, .some(let build)):
            return "Build \(build)"
        case (.none, .none):
            return "Development build"
        }
    }
}
