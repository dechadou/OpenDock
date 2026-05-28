import AppKit
import Combine
import Foundation

@MainActor
final class RunningAppService: ObservableObject {
    @Published private(set) var apps: [RunningAppInfo] = []

    private var observerTokens: [NSObjectProtocol] = []
    private var refreshTimer: Timer?
    private var stableOrderByAppID: [String: Int] = [:]
    private var nextStableOrder = 0

    func start() {
        guard observerTokens.isEmpty else {
            refresh()
            return
        }

        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
        ]

        observerTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
        }

        refresh()
        startRefreshTimer()
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        observerTokens.forEach { center.removeObserver($0) }
        observerTokens = []
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() {
        let currentBundleIdentifier = Bundle.main.bundleIdentifier

        let currentApps = NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular
                    && app.bundleURL != nil
                    && app.bundleIdentifier != currentBundleIdentifier
            }
            .map(RunningAppInfo.init(app:))

        rememberStableOrder(for: currentApps)

        let sortedApps = currentApps.sorted { lhs, rhs in
            let lhsOrder = stableOrderByAppID[lhs.id] ?? Int.max
            let rhsOrder = stableOrderByAppID[rhs.id] ?? Int.max

            if lhsOrder != rhsOrder {
                return lhsOrder < rhsOrder
            }

            return lhs.localizedName.localizedCaseInsensitiveCompare(rhs.localizedName) == .orderedAscending
        }

        if apps != sortedApps {
            apps = sortedApps
        }
    }

    func activate(_ app: RunningAppInfo) {
        guard let runningApplication = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            if let bundleURL = app.bundleURL {
                AppActionService.openApplication(at: bundleURL)
            }
            return
        }

        runningApplication.activate(options: [.activateAllWindows])
    }

    func hide(_ app: RunningAppInfo) {
        guard let runningApplication = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            return
        }

        runningApplication.hide()
        refresh()
    }

    func quit(_ app: RunningAppInfo, force: Bool = false) {
        guard let runningApplication = NSRunningApplication(processIdentifier: app.processIdentifier) else {
            return
        }

        if force {
            runningApplication.forceTerminate()
        } else {
            runningApplication.terminate()
        }
    }

    private func rememberStableOrder(for currentApps: [RunningAppInfo]) {
        let currentIDs = Set(currentApps.map(\.id))
        stableOrderByAppID = stableOrderByAppID.filter { currentIDs.contains($0.key) }

        let newApps =
            currentApps
            .filter { stableOrderByAppID[$0.id] == nil }
            .sorted { lhs, rhs in
                switch (lhs.launchDate, rhs.launchDate) {
                case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
                    return lhsDate < rhsDate
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                default:
                    return lhs.localizedName.localizedCaseInsensitiveCompare(rhs.localizedName) == .orderedAscending
                }
            }

        for app in newApps {
            stableOrderByAppID[app.id] = nextStableOrder
            nextStableOrder += 1
        }
    }

    private func startRefreshTimer() {
        guard refreshTimer == nil else {
            return
        }

        // NSWorkspace notifications already cover launch/terminate/activate/hide/
        // unhide; this is only a low-frequency safety net for missed transitions.
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }
}
