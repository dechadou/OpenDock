import Foundation
import SwiftUI

public enum SidebarEdge: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case right
    case top
    case bottom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .left:
            return "Left"
        case .right:
            return "Right"
        case .top:
            return "Top"
        case .bottom:
            return "Bottom"
        }
    }

    public var isVertical: Bool {
        self == .left || self == .right
    }

    /// The edge a popover's arrow should attach to so the popover opens toward
    /// the screen interior (away from the docked edge).
    public var popoverArrowEdge: Edge {
        switch self {
        case .left:
            return .trailing
        case .right:
            return .leading
        case .top:
            return .bottom
        case .bottom:
            return .top
        }
    }
}
