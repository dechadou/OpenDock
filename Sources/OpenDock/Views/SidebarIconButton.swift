import AppKit
import SwiftUI

struct SidebarIconButton: View {
    var title: String
    var icon: NSImage
    var iconSize: CGFloat
    var isRunning: Bool = false
    var isFrontmost: Bool = false
    var badgeText: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            SidebarIconButtonLabel(
                icon: icon,
                iconSize: iconSize,
                isRunning: isRunning,
                isFrontmost: isFrontmost,
                badgeText: badgeText
            )
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

struct AppBadgeView: View {
    var text: String
    var iconSize: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: max(8, iconSize * 0.25), weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, text.count > 1 ? 5 : 0)
            .frame(minWidth: max(14, iconSize * 0.38), minHeight: max(14, iconSize * 0.38))
            .background(Capsule().fill(Color.red))
            .overlay(Capsule().stroke(.background, lineWidth: 1.4))
    }
}
