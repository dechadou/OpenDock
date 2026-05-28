import Foundation

public enum AppIdentity {
    public static let displayName = "OpenDock"
    public static let executableName = "OpenDock"
    public static let appBundleName = "\(displayName).app"
    public static let bundleIdentifier = "app.opendock"

    public static let applicationSupportDirectoryName = displayName

    public static let preferencesKey = "OpenDock.preferences"

    public static let loginAgentLabel = "app.opendock.login"

    public static let dockRecoveryAgentLabel = "app.opendock.dock-restorer"
    public static let dockRestorerExecutableName = "OpenDockDockRestorer"

    public static let mediaArtworkNotificationName = "OpenDockMediaArtworkDidUpdate"
    public static let mediaArtworkCacheDirectoryName = "OpenDockMediaArtwork"
    public static let trashNotificationName = "OpenDockTrashDidChange"
}
