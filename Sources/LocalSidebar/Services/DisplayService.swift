import AppKit
import Foundation

struct DisplayInfo: Identifiable, Equatable, Hashable, Sendable {
    var id: String
    var name: String
    var frame: CGRect
    var visibleFrame: CGRect
}

enum DisplayService {
    static var activeDisplays: [DisplayInfo] {
        NSScreen.screens.enumerated().map { index, screen in
            let id: String
            if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                id = number.stringValue
            } else {
                id = "\(screen.frame.origin.x)-\(screen.frame.origin.y)-\(screen.frame.width)-\(screen.frame.height)"
            }

            let fallbackName = index == 0 ? "Main Display" : "Display \(index + 1)"
            let name = screen.localizedName.isEmpty ? fallbackName : screen.localizedName

            return DisplayInfo(
                id: id,
                name: name,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }
    }
}
