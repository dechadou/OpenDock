import AppKit
import ApplicationServices
import Combine
import Foundation
import OSLog

@MainActor
final class DockBadgeService: ObservableObject {
    @Published private(set) var badgesByAppID: [String: AppNotificationBadge] = [:]

    private static let debugBadgesEnabled = ProcessInfo.processInfo.environment["LOCALSIDEBAR_DEBUG_BADGES"] == "1"
    private let badgeLogger = Logger(subsystem: "app.localsidebar", category: "badges")
    private weak var runningAppService: RunningAppService?
    private var timer: Timer?

    func start(runningAppService: RunningAppService) {
        self.runningAppService = runningAppService
        refresh()

        guard timer == nil else {
            return
        }

        let timer = Timer(timeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        runningAppService = nil
        badgesByAppID = [:]
    }

    func refresh() {
        guard PermissionService.isAccessibilityTrusted,
            let runningAppService
        else {
            debugLog("Dock badge refresh skipped: Accessibility is not trusted or running app service is unavailable")
            badgesByAppID = [:]
            return
        }

        let groups = dockItemTextGroups()
        debugLog("Dock badge refresh scanning \(runningAppService.apps.count) running apps against \(groups.count) Dock text groups")
        var nextBadges: [String: AppNotificationBadge] = [:]

        for app in runningAppService.apps {
            guard
                let text = DockBadgeParser.extractBadgeText(
                    for: app.localizedName,
                    from: groups
                )
            else {
                continue
            }

            nextBadges[app.id] = AppNotificationBadge(
                bundleIdentifier: app.bundleIdentifier,
                appTitle: app.localizedName,
                text: text
            )
            debugLog("Dock badge matched app=\(app.localizedName) badge=\(text)")
        }

        debugLog("Dock badge refresh found \(nextBadges.count) badges")
        badgesByAppID = nextBadges
    }

    private func dockItemTextGroups() -> [[String]] {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            debugLog("Dock badge scan skipped: Dock process was not found")
            return []
        }

        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        let dockItems = dockItemElements(in: dockElement, depth: 0)
        debugLog("Dock badge scan found \(dockItems.count) AXDockItem elements")

        guard !dockItems.isEmpty else {
            let fallbackTexts = texts(in: dockElement, depth: 0)
            debugLog("Dock badge scan using Dock root fallback texts=\(fallbackTexts.sorted().joined(separator: " | "))")
            return [fallbackTexts]
        }

        return dockItems.enumerated().map { index, item in
            let role = textAttribute(in: item, name: kAXRoleAttribute as String) ?? "unknown"
            let attributes = textAttributePairs(in: item)
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: " | ")
            let collectedTexts = texts(in: item, depth: 0)
            debugLog(
                "Dock item \(index) role=\(role) attributes=\(attributes) texts=\(collectedTexts.sorted().joined(separator: " | "))"
            )
            return collectedTexts
        }
    }

    private func dockItemElements(in element: AXUIElement, depth: Int) -> [AXUIElement] {
        guard depth <= 6 else {
            return []
        }

        if textAttribute(in: element, name: kAXRoleAttribute as String) == "AXDockItem" {
            return [element]
        }

        return axArrayAttribute(element, name: kAXChildrenAttribute as String)
            .flatMap { dockItemElements(in: $0, depth: depth + 1) }
    }

    private func texts(in element: AXUIElement, depth: Int) -> [String] {
        guard depth <= 3 else {
            return []
        }

        var result = textAttributes(in: element)
        for child in axArrayAttribute(element, name: kAXChildrenAttribute as String) {
            result.append(contentsOf: texts(in: child, depth: depth + 1))
        }

        return Array(Set(result))
    }

    private func textAttributes(in element: AXUIElement) -> [String] {
        textAttributePairs(in: element).map(\.value)
    }

    private func textAttributePairs(in element: AXUIElement) -> [(name: String, value: String)] {
        let names = [
            kAXTitleAttribute as String,
            kAXDescriptionAttribute as String,
            kAXValueAttribute as String,
            "AXStatusLabel",
            "AXLabel",
            "AXHelp",
        ]

        return names.compactMap { name in
            guard let value = textAttribute(in: element, name: name) else {
                return nil
            }

            return (name: name, value: value)
        }
    }

    private func textAttribute(in element: AXUIElement, name: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
            let value
        else {
            return nil
        }

        if let string = value as? String {
            return string
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        return nil
    }

    private func axArrayAttribute(_ element: AXUIElement, name: String) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
            let array = value as? [AXUIElement]
        else {
            return []
        }

        return array
    }

    private func debugLog(_ message: String) {
        guard Self.debugBadgesEnabled else {
            return
        }

        badgeLogger.info("\(message, privacy: .public)")
    }
}

public enum DockBadgeParser {
    public static func extractBadgeText(for appName: String, from groups: [[String]]) -> String? {
        groups
            .first { group in
                group.contains { text in
                    text.localizedCaseInsensitiveContains(appName)
                }
            }
            .flatMap { extractBadgeText(from: $0, appName: appName) }
    }

    public static func extractBadgeText(from texts: [String], appName: String) -> String? {
        let trimmedTexts =
            texts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let appNameLowercased = appName.lowercased()

        for text in trimmedTexts where text.range(of: #"^\d{1,4}\+?$"#, options: .regularExpression) != nil {
            return text
        }

        for text in trimmedTexts {
            let lowercased = text.lowercased()
            let hasBadgeContext =
                lowercased.contains(appNameLowercased)
                || lowercased.contains("notification")
                || lowercased.contains("unread")
                || lowercased.contains("badge")
                || lowercased.contains("new")

            guard hasBadgeContext else {
                continue
            }

            if let range = text.range(of: #"\d{1,4}\+?"#, options: .regularExpression) {
                return String(text[range])
            }
        }

        return nil
    }
}
