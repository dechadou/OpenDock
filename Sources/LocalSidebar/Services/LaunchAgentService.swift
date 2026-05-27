import Darwin
import Foundation

public struct LaunchAgentDefinition: Sendable {
    public var label: String
    public var programArguments: [String]
    public var runAtLoad: Bool
    public var keepAlive: Bool

    public init(
        label: String,
        programArguments: [String],
        runAtLoad: Bool = true,
        keepAlive: Bool = false
    ) {
        self.label = label
        self.programArguments = programArguments
        self.runAtLoad = runAtLoad
        self.keepAlive = keepAlive
    }

    public func plistData() throws -> Data {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": programArguments,
            "RunAtLoad": runAtLoad,
            "KeepAlive": keepAlive,
        ]

        return try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
    }
}

enum LaunchAgentService {
    static let launchAgentsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents", isDirectory: true)

    static func agentURL(label: String) -> URL {
        launchAgentsDirectory.appendingPathComponent("\(label).plist")
    }

    static func isInstalled(label: String) -> Bool {
        FileManager.default.fileExists(atPath: agentURL(label: label).path)
    }

    static func installedProgramArguments(label: String) -> [String]? {
        let url = agentURL(label: label)
        guard let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any]
        else {
            return nil
        }

        return plist["ProgramArguments"] as? [String]
    }

    static func install(_ definition: LaunchAgentDefinition, bootstrap shouldBootstrap: Bool = false) throws {
        try FileManager.default.createDirectory(
            at: launchAgentsDirectory,
            withIntermediateDirectories: true
        )

        let url = agentURL(label: definition.label)
        try definition.plistData().write(to: url, options: .atomic)

        if shouldBootstrap {
            try? bootout(label: definition.label)
            try bootstrapAgent(url: url)
        }
    }

    static func remove(label: String, bootout shouldBootout: Bool = false) throws {
        if shouldBootout {
            try? bootout(label: label)
        }

        let url = agentURL(label: label)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private static func bootstrapAgent(url: URL) throws {
        try runLaunchctl(arguments: ["bootstrap", guiDomain, url.path])
    }

    private static func bootout(label: String) throws {
        try runLaunchctl(arguments: ["bootout", guiDomain, agentURL(label: label).path])
    }

    private static var guiDomain: String {
        "gui/\(getuid())"
    }

    private static func runLaunchctl(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "LocalSidebar.LaunchAgentService",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: "launchctl \(arguments.joined(separator: " ")) failed"
                ]
            )
        }
    }
}
