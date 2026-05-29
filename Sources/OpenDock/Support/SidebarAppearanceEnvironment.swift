import SwiftUI

private struct SidebarAppearanceKey: EnvironmentKey {
    static let defaultValue = SidebarAppearance.defaults
}

extension EnvironmentValues {
    var sidebarAppearance: SidebarAppearance {
        get { self[SidebarAppearanceKey.self] }
        set { self[SidebarAppearanceKey.self] = newValue }
    }
}
