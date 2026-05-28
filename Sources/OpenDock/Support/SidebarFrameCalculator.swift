import CoreGraphics
import Foundation

public enum SidebarFrameCalculator {
    public static func frame(
        screenFrame: CGRect,
        edge: SidebarEdge,
        thickness: CGFloat,
        inset: CGFloat = 8
    ) -> CGRect {
        let safeThickness = min(max(thickness, 48), min(screenFrame.width, screenFrame.height))

        switch edge {
        case .left:
            return CGRect(
                x: screenFrame.minX + inset,
                y: screenFrame.minY + inset,
                width: safeThickness,
                height: max(1, screenFrame.height - (inset * 2))
            )
        case .right:
            return CGRect(
                x: screenFrame.maxX - safeThickness - inset,
                y: screenFrame.minY + inset,
                width: safeThickness,
                height: max(1, screenFrame.height - (inset * 2))
            )
        case .top:
            return CGRect(
                x: screenFrame.minX + inset,
                y: screenFrame.maxY - safeThickness - inset,
                width: max(1, screenFrame.width - (inset * 2)),
                height: safeThickness
            )
        case .bottom:
            return CGRect(
                x: screenFrame.minX + inset,
                y: screenFrame.minY + inset,
                width: max(1, screenFrame.width - (inset * 2)),
                height: safeThickness
            )
        }
    }
}
