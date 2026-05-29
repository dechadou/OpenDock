import Foundation

public enum MenuBarActionModel {
    public static let dockActions = ["Show/Hide Dock", "Open Launcher", "Open Windows"]
    public static let createActions = ["New Stack", "Pin"]
    public static let maintenanceActions = ["Refresh Applications"]
    public static let appActions = ["Settings", "About OpenDock", "GitHub Profile", "Open Repository"]
    public static let quitActions = ["Quit OpenDock"]

    public static var topLevelGroups: [[String]] {
        [dockActions, createActions, maintenanceActions, appActions, quitActions]
    }

    public static let githubProfileURL = AppIdentity.githubProfileURL
    public static let githubRepositoryURL = AppIdentity.githubRepositoryURL
}
