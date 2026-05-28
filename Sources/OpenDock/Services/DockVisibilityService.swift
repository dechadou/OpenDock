import Foundation

public enum DockAutohideState: String, Codable, Equatable, Sendable {
    case enabled
    case disabled
    case missing
}

public enum DockPreferenceValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case number(Double)
    case string(String)
    case missing
}

public enum DockPreferenceKind: Sendable {
    case bool
    case number
}

public struct DockPreferenceCommand: Equatable, Sendable {
    public var executablePath: String
    public var arguments: [String]

    public init(executablePath: String, arguments: [String]) {
        self.executablePath = executablePath
        self.arguments = arguments
    }
}

public struct DockVisibilitySnapshot: Codable, Equatable, Sendable {
    public var originalAutohideState: DockAutohideState
    public var createdByProcessID: Int32
    public var createdAt: Date

    public init(
        originalAutohideState: DockAutohideState,
        createdByProcessID: Int32,
        createdAt: Date = Date()
    ) {
        self.originalAutohideState = originalAutohideState
        self.createdByProcessID = createdByProcessID
        self.createdAt = createdAt
    }

    public static func parseDefaultsOutput(_ output: String, terminationStatus: Int32) -> DockAutohideState {
        guard terminationStatus == 0 else {
            return .missing
        }

        let normalized = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "1", "true", "yes":
            return .enabled
        case "0", "false", "no":
            return .disabled
        default:
            return .missing
        }
    }
}

public struct DockVisibilitySnapshotV2: Codable, Equatable, Sendable {
    public var autohide: DockPreferenceValue
    public var autohideDelay: DockPreferenceValue
    public var autohideTimeModifier: DockPreferenceValue
    public var createdByProcessID: Int32
    public var createdAt: Date

    public init(
        autohide: DockPreferenceValue,
        autohideDelay: DockPreferenceValue,
        autohideTimeModifier: DockPreferenceValue,
        createdByProcessID: Int32,
        createdAt: Date = Date()
    ) {
        self.autohide = autohide
        self.autohideDelay = autohideDelay
        self.autohideTimeModifier = autohideTimeModifier
        self.createdByProcessID = createdByProcessID
        self.createdAt = createdAt
    }

    public init(legacy snapshot: DockVisibilitySnapshot) {
        switch snapshot.originalAutohideState {
        case .enabled:
            self.autohide = .bool(true)
        case .disabled:
            self.autohide = .bool(false)
        case .missing:
            self.autohide = .missing
        }

        self.autohideDelay = .missing
        self.autohideTimeModifier = .missing
        self.createdByProcessID = snapshot.createdByProcessID
        self.createdAt = snapshot.createdAt
    }

    public static func parseDefaultsOutput(
        _ output: String,
        terminationStatus: Int32,
        kind: DockPreferenceKind
    ) -> DockPreferenceValue {
        guard terminationStatus == 0 else {
            return .missing
        }

        let normalized = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return .missing
        }

        switch kind {
        case .bool:
            switch normalized.lowercased() {
            case "1", "true", "yes":
                return .bool(true)
            case "0", "false", "no":
                return .bool(false)
            default:
                return .missing
            }
        case .number:
            if let value = Double(normalized) {
                return .number(value)
            }

            return .string(normalized)
        }
    }

    public static func restoreCommands(for snapshot: DockVisibilitySnapshotV2) -> [DockPreferenceCommand] {
        var commands: [DockPreferenceCommand] = []
        appendRestoreCommand(&commands, key: "autohide", value: snapshot.autohide)
        appendRestoreCommand(&commands, key: "autohide-delay", value: snapshot.autohideDelay)
        appendRestoreCommand(&commands, key: "autohide-time-modifier", value: snapshot.autohideTimeModifier)
        commands.append(DockPreferenceCommand(executablePath: "/usr/bin/killall", arguments: ["Dock"]))
        return commands
    }

    public static var hideCommands: [DockPreferenceCommand] {
        [
            DockPreferenceCommand(
                executablePath: "/usr/bin/defaults",
                arguments: ["write", "com.apple.dock", "autohide", "-bool", "true"]
            ),
            DockPreferenceCommand(
                executablePath: "/usr/bin/defaults",
                arguments: ["write", "com.apple.dock", "autohide-delay", "-float", "1000"]
            ),
            DockPreferenceCommand(
                executablePath: "/usr/bin/defaults",
                arguments: ["write", "com.apple.dock", "autohide-time-modifier", "-float", "0"]
            ),
            DockPreferenceCommand(executablePath: "/usr/bin/killall", arguments: ["Dock"]),
        ]
    }

    private static func appendRestoreCommand(
        _ commands: inout [DockPreferenceCommand],
        key: String,
        value: DockPreferenceValue
    ) {
        switch value {
        case .bool(let boolValue):
            commands.append(
                DockPreferenceCommand(
                    executablePath: "/usr/bin/defaults",
                    arguments: ["write", "com.apple.dock", key, "-bool", boolValue ? "true" : "false"]
                )
            )
        case .number(let numberValue):
            commands.append(
                DockPreferenceCommand(
                    executablePath: "/usr/bin/defaults",
                    arguments: ["write", "com.apple.dock", key, "-float", "\(numberValue)"]
                )
            )
        case .string(let stringValue):
            commands.append(
                DockPreferenceCommand(
                    executablePath: "/usr/bin/defaults",
                    arguments: ["write", "com.apple.dock", key, stringValue]
                )
            )
        case .missing:
            commands.append(
                DockPreferenceCommand(
                    executablePath: "/usr/bin/defaults",
                    arguments: ["delete", "com.apple.dock", key]
                )
            )
        }
    }
}

@MainActor
final class DockVisibilityService {
    private let fileManager: FileManager
    private let snapshotURL: URL
    private let recoveryAgentLabel = AppIdentity.dockRecoveryAgentLabel
    private var isApplied = false

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let directory =
            (try? FileSystemLocations.applicationSupportDirectory(fileManager: fileManager))
            ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/\(AppIdentity.applicationSupportDirectoryName)",
                isDirectory: true
            )
        self.snapshotURL =
            directory
            .appendingPathComponent("DockVisibilitySnapshot.json")
    }

    func restoreStaleSnapshotIfNeeded() {
        guard fileManager.fileExists(atPath: snapshotURL.path) else {
            return
        }

        restoreIfNeeded()
    }

    func apply(enabled: Bool) {
        if enabled {
            applyHiddenDock()
        } else {
            restoreIfNeeded()
        }
    }

    func restoreIfNeeded() {
        guard let snapshot = loadSnapshot() else {
            isApplied = false
            try? LaunchAgentService.remove(label: recoveryAgentLabel, bootout: true)
            return
        }

        restore(snapshot: snapshot)
        try? fileManager.removeItem(at: snapshotURL)
        try? LaunchAgentService.remove(label: recoveryAgentLabel, bootout: true)
        isApplied = false
    }

    private func applyHiddenDock() {
        if isApplied, loadSnapshot() != nil {
            return
        }

        let snapshot =
            loadSnapshot()
            ?? DockVisibilitySnapshotV2(
                autohide: readPreference(key: "autohide", kind: .bool),
                autohideDelay: readPreference(key: "autohide-delay", kind: .number),
                autohideTimeModifier: readPreference(key: "autohide-time-modifier", kind: .number),
                createdByProcessID: ProcessInfo.processInfo.processIdentifier
            )

        save(snapshot)
        DockVisibilitySnapshotV2.hideCommands.forEach(run)
        installRecoveryAgentIfPossible()
        isApplied = true
    }

    private func loadSnapshot() -> DockVisibilitySnapshotV2? {
        guard let data = try? Data(contentsOf: snapshotURL) else {
            return nil
        }

        if let snapshot = try? JSONDecoder().decode(DockVisibilitySnapshotV2.self, from: data) {
            return snapshot
        }

        if let legacy = try? JSONDecoder().decode(DockVisibilitySnapshot.self, from: data) {
            return DockVisibilitySnapshotV2(legacy: legacy)
        }

        return nil
    }

    private func save(_ snapshot: DockVisibilitySnapshotV2) {
        do {
            try fileManager.createDirectory(
                at: snapshotURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: snapshotURL, options: .atomic)
        } catch {
            NSLog("\(AppIdentity.displayName): failed to save Dock snapshot: \(error.localizedDescription)")
        }
    }

    private func restore(snapshot: DockVisibilitySnapshotV2) {
        DockVisibilitySnapshotV2.restoreCommands(for: snapshot).forEach(run)
    }

    private func readPreference(key: String, kind: DockPreferenceKind) -> DockPreferenceValue {
        let result = Self.runProcess(
            executablePath: "/usr/bin/defaults",
            arguments: ["read", "com.apple.dock", key]
        )
        return DockVisibilitySnapshotV2.parseDefaultsOutput(
            result.output,
            terminationStatus: result.status,
            kind: kind
        )
    }

    private func run(_ command: DockPreferenceCommand) {
        _ = Self.runProcess(executablePath: command.executablePath, arguments: command.arguments)
    }

    private func installRecoveryAgentIfPossible() {
        guard let helperURL = resolvedRestorerURL() else {
            NSLog("\(AppIdentity.displayName): Dock restorer helper was not found")
            return
        }

        let agentURL = LaunchAgentService.agentURL(label: recoveryAgentLabel)
        let definition = LaunchAgentDefinition(
            label: recoveryAgentLabel,
            programArguments: [
                helperURL.path,
                "--watch-pid",
                "\(ProcessInfo.processInfo.processIdentifier)",
                "--snapshot",
                snapshotURL.path,
                "--agent-plist",
                agentURL.path,
            ]
        )

        do {
            try LaunchAgentService.install(definition, bootstrap: true)
        } catch {
            NSLog("\(AppIdentity.displayName): failed to install Dock recovery agent: \(error.localizedDescription)")
        }
    }

    private func resolvedRestorerURL() -> URL? {
        let bundleURL = Bundle.main.bundleURL
        let bundledHelper =
            bundleURL
            .appendingPathComponent("Contents/MacOS", isDirectory: true)
            .appendingPathComponent(AppIdentity.dockRestorerExecutableName)

        if fileManager.fileExists(atPath: bundledHelper.path) {
            return bundledHelper
        }

        let executableDirectory = URL(fileURLWithPath: CommandLine.arguments.first ?? "")
            .deletingLastPathComponent()
        let siblingHelper = executableDirectory.appendingPathComponent(AppIdentity.dockRestorerExecutableName)

        if fileManager.fileExists(atPath: siblingHelper.path) {
            return siblingHelper
        }

        return nil
    }

    private static func runProcess(executablePath: String, arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (-1, error.localizedDescription)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return (process.terminationStatus, output)
    }
}
