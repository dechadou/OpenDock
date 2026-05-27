import CoreGraphics
import Foundation

struct WindowInfo: Identifiable, Equatable, Hashable, Sendable {
    var id: CGWindowID
    var ownerPID: pid_t
    var ownerName: String
    var title: String
    var bounds: CGRect

    var displayTitle: String {
        title.isEmpty ? ownerName : title
    }
}
