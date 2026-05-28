import CoreGraphics
import Foundation

public enum ScreenCoordinateConverter {
    /// Converts a Cocoa (bottom-left origin) global rect into a Quartz / Core Graphics
    /// (top-left origin) global rect.
    ///
    /// `NSScreen` frames are expressed in Cocoa coordinates, while `CGWindowList`
    /// bounds and Accessibility (`kAXPosition`) values are expressed in Quartz
    /// coordinates. Mixing the two flips the Y axis, so any `NSScreen` frame must be
    /// converted before it is fed into window-positioning math.
    ///
    /// `primaryDisplayHeight` is the height of the display anchored at the Cocoa
    /// origin `(0, 0)` — the same display Quartz uses as its global origin.
    public static func quartzFrame(fromCocoa cocoaFrame: CGRect, primaryDisplayHeight: CGFloat) -> CGRect {
        CGRect(
            x: cocoaFrame.origin.x,
            y: primaryDisplayHeight - cocoaFrame.maxY,
            width: cocoaFrame.width,
            height: cocoaFrame.height
        )
    }
}
