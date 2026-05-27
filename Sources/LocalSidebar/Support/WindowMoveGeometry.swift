import CoreGraphics
import Foundation

public enum WindowMoveGeometry {
    public static func relocatedFrames(
        _ frames: [CGRect],
        to destinationVisibleFrame: CGRect
    ) -> [CGRect] {
        guard let sourceBounds = union(frames) else {
            return []
        }

        return frames.map { frame in
            let offset = CGPoint(
                x: frame.origin.x - sourceBounds.origin.x,
                y: frame.origin.y - sourceBounds.origin.y
            )
            let proposedOrigin = CGPoint(
                x: destinationVisibleFrame.origin.x + offset.x,
                y: destinationVisibleFrame.origin.y + offset.y
            )

            return CGRect(
                origin: clampedOrigin(
                    proposedOrigin,
                    size: frame.size,
                    inside: destinationVisibleFrame
                ),
                size: frame.size
            )
        }
    }

    private static func union(_ frames: [CGRect]) -> CGRect? {
        guard var result = frames.first else {
            return nil
        }

        for frame in frames.dropFirst() {
            result = result.union(frame)
        }

        return result
    }

    private static func clampedOrigin(
        _ origin: CGPoint,
        size: CGSize,
        inside bounds: CGRect
    ) -> CGPoint {
        CGPoint(
            x: clamp(origin.x, lower: bounds.minX, upper: max(bounds.minX, bounds.maxX - size.width)),
            y: clamp(origin.y, lower: bounds.minY, upper: max(bounds.minY, bounds.maxY - size.height))
        )
    }

    private static func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
