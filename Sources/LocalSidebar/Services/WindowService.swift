import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
@preconcurrency import ScreenCaptureKit

enum WindowMoveResult: Sendable {
    case moved
    case accessibilityRequired
    case noWindows
    case failed
}

@MainActor
final class WindowService: ObservableObject {
    @Published private(set) var windows: [WindowInfo] = []
    @Published private var thumbnailsByWindowID: [CGWindowID: NSImage] = [:]

    private let thumbnailService = WindowThumbnailService()
    private var thumbnailTasks: [CGWindowID: Task<Void, Never>] = [:]

    func refresh() {
        windows = Self.enumerateWindows()
        pruneThumbnailCache()
    }

    func windows(for app: RunningAppInfo) -> [WindowInfo] {
        if windows.isEmpty {
            refresh()
        }

        return windows.filter { $0.ownerPID == app.processIdentifier }
    }

    func activate(_ window: WindowInfo) {
        if PermissionService.isAccessibilityTrusted,
            let match = accessibilityWindow(matching: window)
        {
            AXUIElementSetAttributeValue(
                match.appElement,
                kAXFocusedWindowAttribute as CFString,
                match.window
            )
            AXUIElementPerformAction(match.window, kAXRaiseAction as CFString)
            NSRunningApplication(processIdentifier: window.ownerPID)?.activate(options: [])
            return
        }

        NSRunningApplication(processIdentifier: window.ownerPID)?
            .activate(options: [.activateAllWindows])
    }

    func close(_ window: WindowInfo) {
        guard PermissionService.isAccessibilityTrusted,
            let match = accessibilityWindow(matching: window)
        else {
            return
        }

        var closeButton: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(match.window, kAXCloseButtonAttribute as CFString, &closeButton)
        if result == .success,
            let closeButton = axElement(from: closeButton)
        {
            AXUIElementPerformAction(closeButton, kAXPressAction as CFString)
        }
    }

    func moveVisibleWindows(of app: RunningAppInfo, to display: DisplayInfo) -> WindowMoveResult {
        guard PermissionService.isAccessibilityTrusted else {
            return .accessibilityRequired
        }

        let appWindows = Self.enumerateWindows()
            .filter { $0.ownerPID == app.processIdentifier }

        guard !appWindows.isEmpty else {
            return .noWindows
        }

        // `display.visibleFrame` is in Cocoa (bottom-left origin) coordinates, but
        // window bounds and AX positions are Quartz (top-left origin). Convert the
        // destination before relocating so windows keep their vertical placement.
        let destinationFrame = ScreenCoordinateConverter.quartzFrame(
            fromCocoa: display.visibleFrame,
            primaryDisplayHeight: Self.primaryDisplayHeight()
        )

        let relocatedFrames = WindowMoveGeometry.relocatedFrames(
            appWindows.map(\.bounds),
            to: destinationFrame
        )

        var movedWindows = 0

        var movedAccessibilityWindows: Set<CFHashCode> = []

        for (window, frame) in zip(appWindows, relocatedFrames) {
            guard
                let match = accessibilityWindow(
                    matching: window,
                    excluding: movedAccessibilityWindows
                ),
                setFrame(frame, for: match.window)
            else {
                continue
            }

            movedAccessibilityWindows.insert(CFHash(match.window))
            movedWindows += 1
        }

        return movedWindows > 0 ? .moved : .failed
    }

    func thumbnail(for window: WindowInfo) -> NSImage? {
        guard PermissionService.isScreenRecordingTrusted else {
            return nil
        }

        if let thumbnail = thumbnailsByWindowID[window.id] {
            return thumbnail
        }

        requestThumbnail(for: window)
        return nil
    }

    static func enumerateWindows() -> [WindowInfo] {
        guard
            let list = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return []
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier

        return list.compactMap { info -> WindowInfo? in
            guard let number = info[kCGWindowNumber as String] as? NSNumber,
                let ownerPID = info[kCGWindowOwnerPID as String] as? NSNumber,
                ownerPID.intValue != currentPID,
                let layer = info[kCGWindowLayer as String] as? NSNumber,
                layer.intValue == 0,
                let ownerName = info[kCGWindowOwnerName as String] as? String,
                let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary)
            else {
                return nil
            }

            guard bounds.width > 80, bounds.height > 60 else {
                return nil
            }

            let title = info[kCGWindowName as String] as? String ?? ""

            return WindowInfo(
                id: CGWindowID(number.uint32Value),
                ownerPID: pid_t(ownerPID.intValue),
                ownerName: ownerName,
                title: title,
                bounds: bounds
            )
        }
        .sorted {
            if $0.ownerName != $1.ownerName {
                return $0.ownerName.localizedCaseInsensitiveCompare($1.ownerName) == .orderedAscending
            }

            return $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending
        }
    }

    /// Height of the display anchored at the Cocoa origin (0,0), used as the
    /// reference when converting Cocoa screen frames into Quartz coordinates.
    static func primaryDisplayHeight() -> CGFloat {
        let primaryScreen =
            NSScreen.screens.first { $0.frame.origin == .zero }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        return primaryScreen?.frame.height ?? 0
    }

    private func accessibilityWindow(
        matching window: WindowInfo,
        excluding excludedWindowHashes: Set<CFHashCode> = []
    ) -> (appElement: AXUIElement, window: AXUIElement)? {
        let appElement = AXUIElementCreateApplication(window.ownerPID)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
            let axWindows = value as? [AXUIElement]
        else {
            return nil
        }

        let availableWindows = axWindows.filter { !excludedWindowHashes.contains(CFHash($0)) }

        if let exact = availableWindows.first(where: { axWindow in
            var numberValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axWindow, "AXWindowNumber" as CFString, &numberValue) == .success,
                let number = numberValue as? NSNumber
            else {
                return false
            }

            return CGWindowID(number.uint32Value) == window.id
        }) {
            return (appElement, exact)
        }

        if availableWindows.count == 1,
            let onlyWindow = availableWindows.first
        {
            return (appElement, onlyWindow)
        }

        return bestAccessibilityWindowFallback(
            for: window,
            in: availableWindows
        ).map { (appElement, $0.window) }
    }

    private func frame(for axWindow: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionValue) == .success,
            AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue) == .success,
            let positionValue,
            let sizeValue
        else {
            return nil
        }

        guard let positionAXValue = axValue(from: positionValue, type: .cgPoint),
            let sizeAXValue = axValue(from: sizeValue, type: .cgSize)
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(positionAXValue, .cgPoint, &position),
            AXValueGetValue(sizeAXValue, .cgSize, &size)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func title(for axWindow: AXUIElement) -> String {
        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue) == .success,
            let title = titleValue as? String
        else {
            return ""
        }

        return title
    }

    private func bestAccessibilityWindowFallback(
        for window: WindowInfo,
        in axWindows: [AXUIElement]
    ) -> AccessibilityWindowCandidate? {
        axWindows
            .compactMap { axWindow -> AccessibilityWindowCandidate? in
                guard let axFrame = frame(for: axWindow) else {
                    return nil
                }

                let score = fallbackMatchScore(
                    window: window,
                    axTitle: title(for: axWindow),
                    axFrame: axFrame
                )

                guard score <= 96 else {
                    return nil
                }

                return AccessibilityWindowCandidate(window: axWindow, score: score)
            }
            .min { $0.score < $1.score }
    }

    private func fallbackMatchScore(
        window: WindowInfo,
        axTitle: String,
        axFrame: CGRect
    ) -> CGFloat {
        let frameScore =
            abs(window.bounds.minX - axFrame.minX)
            + abs(window.bounds.minY - axFrame.minY)
            + abs(window.bounds.width - axFrame.width)
            + abs(window.bounds.height - axFrame.height)

        return titlesCompatible(window.title, axTitle) ? frameScore : frameScore + 24
    }

    private func titlesCompatible(_ lhs: String, _ rhs: String) -> Bool {
        let lhs = normalizedTitle(lhs)
        let rhs = normalizedTitle(rhs)

        guard !lhs.isEmpty, !rhs.isEmpty else {
            return true
        }

        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }

    private func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func requestThumbnail(for window: WindowInfo) {
        guard thumbnailTasks[window.id] == nil else {
            return
        }

        thumbnailTasks[window.id] = Task { [weak self] in
            guard let self else {
                return
            }

            let image = await self.thumbnailService.thumbnail(for: window)
            guard !Task.isCancelled else {
                return
            }

            self.thumbnailTasks[window.id] = nil
            if let image {
                self.thumbnailsByWindowID[window.id] = image
            }
        }
    }

    private func pruneThumbnailCache() {
        let activeWindowIDs = Set(windows.map(\.id))
        thumbnailsByWindowID = thumbnailsByWindowID.filter { activeWindowIDs.contains($0.key) }

        let staleWindowIDs = thumbnailTasks.keys.filter { !activeWindowIDs.contains($0) }
        for windowID in staleWindowIDs {
            thumbnailTasks[windowID]?.cancel()
            thumbnailTasks.removeValue(forKey: windowID)
        }
    }

    private func setFrame(_ frame: CGRect, for axWindow: AXUIElement) -> Bool {
        var position = frame.origin
        var size = frame.size

        guard let positionValue = AXValueCreate(.cgPoint, &position),
            let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            return false
        }

        let positionResult = AXUIElementSetAttributeValue(
            axWindow,
            kAXPositionAttribute as CFString,
            positionValue
        )
        _ = AXUIElementSetAttributeValue(
            axWindow,
            kAXSizeAttribute as CFString,
            sizeValue
        )

        return positionResult == .success
    }

    private func axElement(from value: CFTypeRef?) -> AXUIElement? {
        guard let value,
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func axValue(from value: CFTypeRef?, type: AXValueType) -> AXValue? {
        guard let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        let axValue = unsafeDowncast(value, to: AXValue.self)
        guard AXValueGetType(axValue) == type else {
            return nil
        }

        return axValue
    }
}

private struct AccessibilityWindowCandidate {
    var window: AXUIElement
    var score: CGFloat
}

@MainActor
private final class WindowThumbnailService {
    func thumbnail(for window: WindowInfo) async -> NSImage? {
        guard let shareableWindow = await shareableWindow(matching: window) else {
            return nil
        }

        let filter = SCContentFilter(desktopIndependentWindow: shareableWindow)
        let configuration = SCScreenshotConfiguration()
        let backingScale = backingScale(for: window)
        configuration.showsCursor = false
        configuration.ignoreShadows = true
        configuration.includeChildWindows = true
        configuration.dynamicRange = .sdr
        configuration.width = max(1, Int(window.bounds.width * backingScale))
        configuration.height = max(1, Int(window.bounds.height * backingScale))

        do {
            let output = try await SCScreenshotManager.captureScreenshot(
                contentFilter: filter,
                configuration: configuration
            )
            guard let image = output.sdrImage else {
                return nil
            }

            return NSImage(cgImage: image, size: window.bounds.size)
        } catch {
            return nil
        }
    }

    private func shareableWindow(matching window: WindowInfo) async -> SCWindow? {
        do {
            let content = try await SCShareableContent.current
            return content.windows.first { $0.windowID == window.id }
        } catch {
            return nil
        }
    }

    private func backingScale(for window: WindowInfo) -> CGFloat {
        // `window.bounds` is in Quartz coordinates; convert each Cocoa screen frame
        // to Quartz before testing intersection so the correct display is picked.
        let primaryHeight = WindowService.primaryDisplayHeight()
        let matchingScreen = NSScreen.screens.first { screen in
            ScreenCoordinateConverter
                .quartzFrame(fromCocoa: screen.frame, primaryDisplayHeight: primaryHeight)
                .intersects(window.bounds)
        }

        return matchingScreen?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
    }
}
