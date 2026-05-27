import Foundation

public enum SidebarVisibilityPolicy {
    public static func shouldDisplay(_ item: SidebarItem, preferences: SidebarPreferences) -> Bool {
        guard item.kind == .system else {
            if item.kind == .stack {
                return preferences.stacksEnabled
            }

            return true
        }

        switch item.systemKind {
        case .windowSwitcher:
            return preferences.windowSwitcherEnabled
        case .trash:
            return preferences.trashWidgetEnabled
        case .dateTime:
            return preferences.dateTimeWidgetEnabled
        case .media:
            return preferences.mediaControlsEnabled
        case nil:
            return true
        }
    }
}
