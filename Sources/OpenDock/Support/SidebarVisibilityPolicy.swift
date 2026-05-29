import Foundation

public enum SidebarVisibilityPolicy {
    public static func shouldDisplay(
        _ item: SidebarItem,
        preferences: SidebarPreferences,
        registry: WidgetRegistry = .shared
    ) -> Bool {
        guard item.kind == .system else {
            if item.kind == .stack {
                return preferences.stacksEnabled
            }

            return true
        }

        guard let widgetID = item.widgetID else {
            return true
        }

        if widgetID == .windows {
            return preferences.windowSwitcherEnabled
        }

        let defaultEnabled = registry.manifest(for: widgetID)?.defaultEnabled ?? true
        return preferences.widgetPreferences.isEnabled(widgetID, default: defaultEnabled)
    }
}
