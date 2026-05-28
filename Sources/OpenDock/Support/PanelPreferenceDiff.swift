import Foundation

public struct PanelPreferenceDiff: Equatable, Sendable {
    public var requiresRebuild: Bool
    public var requiresFrameUpdate: Bool
    public var requiresVisibilityUpdate: Bool
    public var requiresOpacityUpdate: Bool

    public init(oldValue: SidebarPreferences, newValue: SidebarPreferences) {
        self.requiresRebuild = oldValue.showOnAllDisplays != newValue.showOnAllDisplays
        self.requiresFrameUpdate =
            oldValue.edge != newValue.edge
            || oldValue.iconSize != newValue.iconSize
            || oldValue.spacing != newValue.spacing
            || oldValue.panelThickness != newValue.panelThickness
        self.requiresVisibilityUpdate =
            oldValue.autoHide != newValue.autoHide
            || oldValue.bottomRevealDelayMilliseconds != newValue.bottomRevealDelayMilliseconds
        self.requiresOpacityUpdate = oldValue.opacity != newValue.opacity
    }
}
