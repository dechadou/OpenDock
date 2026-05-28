import Foundation

public enum LoginItemService {
    public nonisolated static let label = AppIdentity.loginAgentLabel

    public static var isEnabled: Bool {
        LaunchAgentService.isInstalled(label: label)
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try LaunchAgentService.install(loginAgentDefinition())
        } else {
            try LaunchAgentService.remove(label: label)
        }
    }

    public static func refreshInstalledAgentIfNeeded() {
        guard isEnabled else {
            return
        }

        let currentDefinition = loginAgentDefinition()
        guard LaunchAgentService.installedProgramArguments(label: label) != currentDefinition.programArguments else {
            return
        }

        try? LaunchAgentService.install(currentDefinition)
    }

    public static func loginAgentDefinition(
        appBundleURL: URL = resolvedAppBundleURL()
    ) -> LaunchAgentDefinition {
        LaunchAgentDefinition(
            label: label,
            programArguments: [
                "/usr/bin/open",
                "-n",
                appBundleURL.path,
            ]
        )
    }

    public static func resolvedAppBundleURL() -> URL {
        let bundleURL = Bundle.main.bundleURL
        if bundleURL.pathExtension == "app" {
            return bundleURL
        }

        let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let stagedBundleURL =
            workingDirectory
            .appendingPathComponent("dist", isDirectory: true)
            .appendingPathComponent(AppIdentity.appBundleName, isDirectory: true)

        if FileManager.default.fileExists(atPath: stagedBundleURL.path) {
            return stagedBundleURL
        }

        return bundleURL
    }
}
