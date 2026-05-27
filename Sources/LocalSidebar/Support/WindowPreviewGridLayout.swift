import CoreGraphics
import Foundation

public struct WindowPreviewGridMetrics: Equatable, Sendable {
    public var displayedItemCount: Int
    public var columns: Int
    public var rows: Int

    public init(displayedItemCount: Int, columns: Int, rows: Int) {
        self.displayedItemCount = displayedItemCount
        self.columns = columns
        self.rows = rows
    }
}

public enum WindowPreviewGridLayout {
    public static let maximumItemCount = 10
    public static let spacing: CGFloat = 10

    public static func metrics(
        itemCount: Int,
        availableSize: CGSize,
        maximumItemCount: Int = Self.maximumItemCount
    ) -> WindowPreviewGridMetrics {
        let count = min(max(0, itemCount), max(0, maximumItemCount))
        guard count > 0 else {
            return WindowPreviewGridMetrics(displayedItemCount: 0, columns: 0, rows: 0)
        }

        let safeWidth = max(1, availableSize.width)
        let safeHeight = max(1, availableSize.height)
        let targetAspectRatio: CGFloat = 16.0 / 10.0

        var bestColumns = 1
        var bestRows = count
        var bestScore = CGFloat.greatestFiniteMagnitude

        for columns in 1...count {
            let rows = Int(ceil(Double(count) / Double(columns)))
            let cellWidth = (safeWidth - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            let cellHeight = (safeHeight - CGFloat(rows - 1) * spacing) / CGFloat(rows)

            guard cellWidth > 0, cellHeight > 0 else {
                continue
            }

            let aspectPenalty = abs((cellWidth / cellHeight) - targetAspectRatio)
            let emptyCellPenalty = CGFloat((columns * rows) - count) * 0.18
            let score = aspectPenalty + emptyCellPenalty

            if score < bestScore {
                bestScore = score
                bestColumns = columns
                bestRows = rows
            }
        }

        return WindowPreviewGridMetrics(
            displayedItemCount: count,
            columns: bestColumns,
            rows: bestRows
        )
    }
}
