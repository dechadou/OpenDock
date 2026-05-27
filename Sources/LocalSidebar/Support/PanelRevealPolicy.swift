import CoreGraphics
import Foundation

public enum PanelRevealPolicy {
    public static let interactionInset: CGFloat = 12
    public static let revealDistance: CGFloat = 18

    public static func shouldHoldVisible(
        panelFrame: CGRect,
        screenFrame: CGRect,
        mouseLocation: CGPoint
    ) -> Bool {
        guard containsInclusive(screenFrame, mouseLocation) else {
            return false
        }

        return
            panelFrame
            .insetBy(dx: -interactionInset, dy: -interactionInset)
            .contains(mouseLocation)
    }

    public static func shouldRevealHidden(
        edge: SidebarEdge,
        screenFrame: CGRect,
        mouseLocation: CGPoint
    ) -> Bool {
        guard containsInclusive(screenFrame, mouseLocation) else {
            return false
        }

        switch edge {
        case .left:
            return mouseLocation.x <= screenFrame.minX + revealDistance
        case .right:
            return mouseLocation.x >= screenFrame.maxX - revealDistance
        case .top:
            return mouseLocation.y >= screenFrame.maxY - revealDistance
        case .bottom:
            return floorCoordinate(mouseLocation.y) <= floorCoordinate(screenFrame.minY)
        }
    }

    private static func containsInclusive(_ frame: CGRect, _ point: CGPoint) -> Bool {
        point.x >= frame.minX
            && point.x <= frame.maxX
            && point.y >= frame.minY
            && point.y <= frame.maxY
    }

    private static func floorCoordinate(_ value: CGFloat) -> CGFloat {
        value.rounded(.down)
    }
}
