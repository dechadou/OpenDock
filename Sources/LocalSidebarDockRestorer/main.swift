import Foundation
import LocalSidebarCore

struct DockRestorerArguments {
    var watchPID: pid_t
    var snapshotURL: URL
    var agentPlistURL: URL?
}

let arguments = Array(CommandLine.arguments.dropFirst())

guard let parsedArguments = parse(arguments: arguments) else {
    fputs("usage: LocalSidebarDockRestorer --watch-pid <pid> --snapshot <path> [--agent-plist <path>]\n", stderr)
    exit(2)
}

while kill(parsedArguments.watchPID, 0) == 0 {
    sleep(1)
}

restoreDock(snapshotURL: parsedArguments.snapshotURL)

try? FileManager.default.removeItem(at: parsedArguments.snapshotURL)
if let agentPlistURL = parsedArguments.agentPlistURL {
    try? FileManager.default.removeItem(at: agentPlistURL)
}

func parse(arguments: [String]) -> DockRestorerArguments? {
    var watchPID: pid_t?
    var snapshotPath: String?
    var agentPlistPath: String?
    var index = 0

    while index < arguments.count {
        let key = arguments[index]
        let valueIndex = index + 1

        guard valueIndex < arguments.count else {
            return nil
        }

        switch key {
        case "--watch-pid":
            watchPID = pid_t(arguments[valueIndex])
        case "--snapshot":
            snapshotPath = arguments[valueIndex]
        case "--agent-plist":
            agentPlistPath = arguments[valueIndex]
        default:
            return nil
        }

        index += 2
    }

    guard let watchPID,
        let snapshotPath
    else {
        return nil
    }

    return DockRestorerArguments(
        watchPID: watchPID,
        snapshotURL: URL(fileURLWithPath: snapshotPath),
        agentPlistURL: agentPlistPath.map(URL.init(fileURLWithPath:))
    )
}

func restoreDock(snapshotURL: URL) {
    guard let data = try? Data(contentsOf: snapshotURL) else {
        return
    }

    let decoder = JSONDecoder()
    let snapshot: DockVisibilitySnapshotV2
    if let decoded = try? decoder.decode(DockVisibilitySnapshotV2.self, from: data) {
        snapshot = decoded
    } else if let legacy = try? decoder.decode(DockVisibilitySnapshot.self, from: data) {
        snapshot = DockVisibilitySnapshotV2(legacy: legacy)
    } else {
        return
    }

    for command in DockVisibilitySnapshotV2.restoreCommands(for: snapshot) {
        runProcess(command.executablePath, command.arguments)
    }
}

func runProcess(_ executablePath: String, _ arguments: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fputs("LocalSidebarDockRestorer: \(error.localizedDescription)\n", stderr)
    }
}
