import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
public final class AppModel: ObservableObject {
    let preferencesStore: PreferencesStore
    let sidebarItemStore: SidebarItemStore
    let runningAppService: RunningAppService
    let applicationScanner: ApplicationScanner
    let windowService: WindowService
    private let dockVisibilityService: DockVisibilityService
    private let dockBadgeService: DockBadgeService

    @Published var isSidebarVisible = true
    @Published var isLauncherPresented = false
    @Published var isWindowSwitcherPresented = false
    @Published private(set) var mediaPlaybackInfo: MediaPlaybackInfo?
    @Published private(set) var isSidebarHeldByInteraction = false

    private let panelController = PanelController()
    private let hotKeyService = HotKeyService()
    private var cancellables: Set<AnyCancellable> = []
    private var sidebarInteractionSurfaceIDs: Set<String> = []
    private var didStart = false

    public init() {
        self.preferencesStore = PreferencesStore()
        self.sidebarItemStore = SidebarItemStore()
        self.runningAppService = RunningAppService()
        self.applicationScanner = ApplicationScanner()
        self.windowService = WindowService()
        self.dockVisibilityService = DockVisibilityService()
        self.dockBadgeService = DockBadgeService()
    }

    init(
        preferencesStore: PreferencesStore,
        sidebarItemStore: SidebarItemStore,
        runningAppService: RunningAppService,
        applicationScanner: ApplicationScanner,
        windowService: WindowService,
        dockVisibilityService: DockVisibilityService,
        dockBadgeService: DockBadgeService
    ) {
        self.preferencesStore = preferencesStore
        self.sidebarItemStore = sidebarItemStore
        self.runningAppService = runningAppService
        self.applicationScanner = applicationScanner
        self.windowService = windowService
        self.dockVisibilityService = dockVisibilityService
        self.dockBadgeService = dockBadgeService
    }

    public func start() {
        guard !didStart else {
            return
        }

        didStart = true
        LoginItemService.refreshInstalledAgentIfNeeded()
        dockVisibilityService.restoreStaleSnapshotIfNeeded()
        runningAppService.start()
        dockBadgeService.start(runningAppService: runningAppService)
        applicationScanner.reload()
        panelController.start(appModel: self, preferences: preferencesStore.preferences)
        dockVisibilityService.apply(enabled: preferencesStore.preferences.hideSystemDock)

        preferencesStore.$preferences
            .dropFirst()
            .sink { [weak self] preferences in
                guard let self else {
                    return
                }

                self.panelController.apply(preferences: preferences)
                self.panelController.setSidebarEnabled(self.isSidebarVisible)
                self.dockVisibilityService.apply(enabled: preferences.hideSystemDock)
                self.hotKeyService.setWindowSwitcherEnabled(preferences.windowSwitcherEnabled)
            }
            .store(in: &cancellables)

        dockBadgeService.$badgesByAppID
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        sidebarItemStore.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshRunningAppsAndInvalidate()
                }
            }
            .store(in: &cancellables)

        runningAppService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        preferencesStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        hotKeyService.start(
            onToggleSidebar: { [weak self] in
                self?.toggleSidebar()
            },
            onOpenLauncher: { [weak self] in
                self?.openLauncher()
            },
            onOpenWindowSwitcher: { [weak self] in
                self?.openWindowSwitcher()
            },
            windowSwitcherEnabled: preferencesStore.preferences.windowSwitcherEnabled
        )
    }

    public func stop() {
        dockVisibilityService.restoreIfNeeded()
        dockBadgeService.stop()
        hotKeyService.stop()
        runningAppService.stop()
        panelController.stop()
        cancellables.removeAll()
        didStart = false
    }

    private func refreshRunningAppsAndInvalidate() {
        runningAppService.refresh()
        objectWillChange.send()
    }

    func toggleSidebar() {
        isSidebarVisible.toggle()
        panelController.setSidebarEnabled(isSidebarVisible)
    }

    func showSidebar() {
        isSidebarVisible = true
        panelController.setSidebarEnabled(true)
    }

    func openLauncher() {
        showSidebar()
        isLauncherPresented = true
        NSApp.activate(ignoringOtherApps: true)
    }

    func openWindowSwitcher() {
        guard preferencesStore.preferences.windowSwitcherEnabled else {
            isWindowSwitcherPresented = false
            return
        }

        showSidebar()
        windowService.refresh()
        isWindowSwitcherPresented = true
        NSApp.activate(ignoringOtherApps: true)
    }

    func setSidebarInteractionSurface(_ id: String, visible: Bool) {
        if visible {
            sidebarInteractionSurfaceIDs.insert(id)
        } else {
            sidebarInteractionSurfaceIDs.remove(id)
        }

        isSidebarHeldByInteraction = !sidebarInteractionSurfaceIDs.isEmpty
    }

    var shouldHoldSidebarVisibleForInteraction: Bool {
        isSidebarHeldByInteraction || isLauncherPresented || isWindowSwitcherPresented
    }

    func handleSidebarItemClick(_ item: SidebarItem) {
        switch item.kind {
        case .application:
            if preferencesStore.preferences.secondClickEnabled,
                let runningApp = runningApp(for: item),
                runningApp.isActive
            {
                runningAppService.hide(runningApp)
                return
            }

            AppActionService.openSidebarItem(item)
        case .file, .url:
            AppActionService.openSidebarItem(item)
        case .folder:
            AppActionService.openSidebarItem(item)
        case .stack:
            break
        case .system:
            openSystemItem(item)
        }
    }

    func openSystemItem(_ item: SidebarItem) {
        switch item.systemKind {
        case .windowSwitcher:
            openWindowSwitcher()
        case .trash:
            TrashService.openTrash()
        case .dateTime:
            break
        case .media:
            openCurrentMediaApplication()
        case nil:
            break
        }
    }

    func openPinnedItem(_ item: PinnedItem) {
        AppActionService.openPinnedItem(item)
    }

    func removeSidebarItem(_ item: SidebarItem) {
        sidebarItemStore.remove(id: item.id)
        refreshRunningAppsAndInvalidate()
    }

    func openRunningApp(_ app: RunningAppInfo) {
        if preferencesStore.preferences.secondClickEnabled, app.isActive {
            runningAppService.hide(app)
        } else {
            runningAppService.activate(app)
        }
    }

    func quitRunningApp(_ app: RunningAppInfo, force: Bool = false) {
        runningAppService.quit(app, force: force)
    }

    var activeDisplays: [DisplayInfo] {
        DisplayService.activeDisplays
    }

    func moveRunningApp(_ app: RunningAppInfo, to display: DisplayInfo) {
        let result = windowService.moveVisibleWindows(of: app, to: display)

        switch result {
        case .moved:
            windowService.refresh()
        case .accessibilityRequired:
            PermissionService.requestAccessibilityPrompt()
            PermissionService.openAccessibilitySettings()
        case .noWindows:
            NSLog("LocalSidebar: no visible windows found for \(app.localizedName)")
        case .failed:
            NSLog("LocalSidebar: failed to move windows for \(app.localizedName)")
        }
    }

    func badge(for app: RunningAppInfo) -> AppNotificationBadge? {
        dockBadgeService.badgesByAppID[app.id]
    }

    func badge(for item: SidebarItem) -> AppNotificationBadge? {
        guard let runningApp = runningApp(for: item) else {
            return nil
        }

        return badge(for: runningApp)
    }

    func openLaunchableApplication(_ application: LaunchableApplication) {
        AppActionService.openApplication(application)
        isLauncherPresented = false
    }

    func pinLaunchableApplication(_ application: LaunchableApplication) {
        sidebarItemStore.add(
            kind: .application,
            title: application.name,
            url: application.url,
            bundleIdentifier: application.bundleIdentifier
        )
        refreshRunningAppsAndInvalidate()
    }

    func pinRunningApp(_ app: RunningAppInfo) {
        guard let bundleURL = app.bundleURL else {
            return
        }

        sidebarItemStore.add(
            kind: .application,
            title: app.localizedName,
            url: bundleURL,
            bundleIdentifier: app.bundleIdentifier
        )
        refreshRunningAppsAndInvalidate()
    }

    var availableStacks: [SidebarItem] {
        sidebarItemStore.items.filter { $0.kind == .stack }
    }

    var visibleRunningApps: [RunningAppInfo] {
        runningAppService.apps.filter {
            !isApplicationRepresentedInSidebar($0) && !shouldHideMediaSourceApplication($0)
        }
    }

    func isApplicationRepresentedInSidebar(_ app: RunningAppInfo) -> Bool {
        sidebarItemStore.containsApplication(
            bundleIdentifier: app.bundleIdentifier,
            url: app.bundleURL
        )
    }

    func sidebarItem(for runningApp: RunningAppInfo) -> SidebarItem? {
        guard let bundleURL = runningApp.bundleURL else {
            return nil
        }

        return SidebarItem(
            kind: .application,
            title: runningApp.localizedName,
            url: bundleURL,
            bundleIdentifier: runningApp.bundleIdentifier
        )
    }

    func addRunningApp(_ app: RunningAppInfo, toStack stackID: SidebarItem.ID) {
        guard let item = sidebarItem(for: app) else {
            return
        }

        sidebarItemStore.addItem(item, toStack: stackID)
        refreshRunningAppsAndInvalidate()
    }

    func pinFrontmostApplication() {
        guard let app = NSWorkspace.shared.frontmostApplication,
            app.bundleIdentifier != Bundle.main.bundleIdentifier,
            let bundleURL = app.bundleURL
        else {
            return
        }

        sidebarItemStore.add(
            kind: .application,
            title: app.localizedName ?? bundleURL.deletingPathExtension().lastPathComponent,
            url: bundleURL,
            bundleIdentifier: app.bundleIdentifier
        )
        refreshRunningAppsAndInvalidate()
    }

    func chooseApplicationToPin() {
        let panel = NSOpenPanel()
        panel.title = "Pin Application"
        panel.message = "Choose an application to keep in LocalSidebar."
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.applicationBundle]

        NSApp.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK else {
            return
        }

        for url in panel.urls {
            let bundle = Bundle(url: url)
            let name =
                (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent

            sidebarItemStore.add(
                kind: .application,
                title: name,
                url: url,
                bundleIdentifier: bundle?.bundleIdentifier
            )
        }
        refreshRunningAppsAndInvalidate()
    }

    func chooseFileOrFolderPins() {
        let panel = NSOpenPanel()
        panel.title = "Pin File or Folder"
        panel.message = "Choose files or folders to keep in LocalSidebar."
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true

        NSApp.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK else {
            return
        }

        for url in panel.urls {
            let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
            let kind: PinnedItem.Kind = resourceValues?.isDirectory == true ? .folder : .file

            sidebarItemStore.add(
                kind: SidebarItem.Kind(pinnedKind: kind),
                title: url.lastPathComponent,
                url: url
            )
        }
        refreshRunningAppsAndInvalidate()
    }

    func promptForURLPin() {
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        textField.placeholderString = "https://example.com"

        let alert = NSAlert()
        alert.messageText = "Pin URL"
        alert.informativeText = "Enter the web URL to keep in LocalSidebar."
        alert.accessoryView = textField
        alert.addButton(withTitle: "Pin")
        alert.addButton(withTitle: "Cancel")

        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        let rawValue = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty else {
            return
        }

        let normalized = rawValue.contains("://") ? rawValue : "https://\(rawValue)"
        guard let url = URL(string: normalized),
            let scheme = url.scheme?.lowercased(),
            ["http", "https"].contains(scheme)
        else {
            return
        }

        sidebarItemStore.add(
            kind: .url,
            title: url.host ?? normalized,
            url: url
        )
        refreshRunningAppsAndInvalidate()
    }

    func createStack() {
        sidebarItemStore.createStack(title: "Stack")
        refreshRunningAppsAndInvalidate()
    }

    func addURLToSidebar(_ url: URL) {
        let kind = sidebarItemKind(for: url)
        let title = title(for: url, kind: kind)
        let bundle = kind == .application ? Bundle(url: url) : nil
        sidebarItemStore.add(
            kind: kind,
            title: title,
            url: url,
            bundleIdentifier: bundle?.bundleIdentifier
        )
        refreshRunningAppsAndInvalidate()
    }

    func addURLToStack(_ url: URL, stackID: SidebarItem.ID) {
        let kind = sidebarItemKind(for: url)
        let title = title(for: url, kind: kind)
        let bundle = kind == .application ? Bundle(url: url) : nil
        sidebarItemStore.addItem(
            SidebarItem(
                kind: kind,
                title: title,
                url: url,
                bundleIdentifier: bundle?.bundleIdentifier
            ),
            toStack: stackID
        )
        refreshRunningAppsAndInvalidate()
    }

    func handleDrop(_ providers: [NSItemProvider], before targetID: SidebarItem.ID?) -> Bool {
        DragDropService.loadPayloads(from: providers) { [weak self] payloads in
            Task { @MainActor in
                guard let self else {
                    return
                }

                for payload in payloads {
                    switch payload {
                    case .sidebarItem(let id):
                        self.sidebarItemStore.moveMainItem(id: id, before: targetID)
                    case .fileURL(let url):
                        self.addURLToSidebar(url)
                    }
                }
                self.refreshRunningAppsAndInvalidate()
            }
        }
    }

    func handlePinnedItemDrop(_ providers: [NSItemProvider], before targetID: SidebarItem.ID?) -> Bool {
        DragDropService.loadPayloads(from: providers) { [weak self] payloads in
            Task { @MainActor in
                guard let self else {
                    return
                }

                for payload in payloads {
                    switch payload {
                    case .sidebarItem(let id):
                        self.sidebarItemStore.movePinnedItem(id: id, before: targetID)
                    case .fileURL(let url):
                        self.addURLToSidebar(url)
                    }
                }
                self.refreshRunningAppsAndInvalidate()
            }
        }
    }

    func handleDropIntoStack(_ providers: [NSItemProvider], stackID: SidebarItem.ID) -> Bool {
        DragDropService.loadPayloads(from: providers) { [weak self] payloads in
            Task { @MainActor in
                guard let self else {
                    return
                }

                for payload in payloads {
                    switch payload {
                    case .sidebarItem(let id):
                        self.sidebarItemStore.moveMainItemIntoStack(itemID: id, stackID: stackID)
                    case .fileURL(let url):
                        self.addURLToStack(url, stackID: stackID)
                    }
                }
                self.refreshRunningAppsAndInvalidate()
            }
        }
    }

    func handleDropIntoStackChildList(_ providers: [NSItemProvider], stackID: SidebarItem.ID, before targetID: SidebarItem.ID?) -> Bool {
        DragDropService.loadPayloads(from: providers) { [weak self] payloads in
            Task { @MainActor in
                guard let self else {
                    return
                }

                for payload in payloads {
                    switch payload {
                    case .sidebarItem(let id):
                        if self.sidebarItemStore.item(id: id) != nil {
                            self.sidebarItemStore.reorderChild(stackID: stackID, childID: id, before: targetID)
                        }
                    case .fileURL(let url):
                        self.addURLToStack(url, stackID: stackID)
                    }
                }
                self.refreshRunningAppsAndInvalidate()
            }
        }
    }

    func moveChildOutOfStack(childID: SidebarItem.ID, stackID: SidebarItem.ID) {
        sidebarItemStore.moveChildOutOfStack(childID: childID, stackID: stackID)
        refreshRunningAppsAndInvalidate()
    }

    func emptyTrashWithConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Empty Trash?"
        alert.informativeText = "This permanently removes items currently in your user Trash."
        alert.addButton(withTitle: "Empty Trash")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            try TrashService.emptyTrash()
        } catch {
            let failure = NSAlert(error: error)
            failure.messageText = "Could not empty Trash"
            failure.runModal()
        }
    }

    func sendMediaCommand(_ command: MediaControlService.Command) {
        MediaControlService.send(command)
    }

    func refreshMediaPlaybackInfo() {
        MediaControlService.pollingQueue.async { [weak self] in
            let info = MediaControlService.currentPlaybackInfoSync()
            Task { @MainActor in
                self?.setMediaPlaybackInfo(info)
            }
        }
    }

    func openCurrentMediaApplication() {
        if openMediaApplication(from: mediaPlaybackInfo) {
            return
        }

        MediaControlService.pollingQueue.async { [weak self] in
            let info = MediaControlService.currentPlaybackInfoSync()
            Task { @MainActor in
                guard let self else {
                    return
                }

                self.setMediaPlaybackInfo(info)
                _ = self.openMediaApplication(from: info)
            }
        }
    }

    func runningApp(for item: SidebarItem) -> RunningAppInfo? {
        guard item.kind == .application else {
            return nil
        }

        if let bundleIdentifier = item.bundleIdentifier {
            return runningAppService.apps.first { $0.bundleIdentifier == bundleIdentifier }
        }

        if let url = item.url {
            return runningAppService.apps.first { $0.bundleURL == url }
        }

        return nil
    }

    func runningApp(for application: LaunchableApplication) -> RunningAppInfo? {
        if let bundleIdentifier = application.bundleIdentifier {
            return runningAppService.apps.first { $0.bundleIdentifier == bundleIdentifier }
        }

        return runningAppService.apps.first { $0.bundleURL == application.url }
    }

    func shouldDisplay(_ item: SidebarItem) -> Bool {
        guard SidebarVisibilityPolicy.shouldDisplay(item, preferences: preferencesStore.preferences) else {
            return false
        }

        if item.kind == .application && shouldHideMediaSourceApplication(item) {
            return false
        }

        return true
    }

    private var shouldHideMediaSourceApplicationIcon: Bool {
        let preferences = preferencesStore.preferences
        return preferences.mediaControlsEnabled
            && preferences.hideMediaSourceAppIcon
            && mediaPlaybackInfo != nil
    }

    private func setMediaPlaybackInfo(_ info: MediaPlaybackInfo?) {
        guard mediaPlaybackInfo != info else {
            return
        }

        mediaPlaybackInfo = info
        objectWillChange.send()
    }

    private func shouldHideMediaSourceApplication(_ app: RunningAppInfo) -> Bool {
        guard shouldHideMediaSourceApplicationIcon else {
            return false
        }

        return matchesMediaSource(bundleIdentifier: app.bundleIdentifier, bundleURL: app.bundleURL)
    }

    private func shouldHideMediaSourceApplication(_ item: SidebarItem) -> Bool {
        guard shouldHideMediaSourceApplicationIcon else {
            return false
        }

        return matchesMediaSource(bundleIdentifier: item.bundleIdentifier, bundleURL: item.url)
    }

    private func matchesMediaSource(bundleIdentifier: String?, bundleURL: URL?) -> Bool {
        guard let mediaPlaybackInfo else {
            return false
        }

        if let bundleIdentifier, let mediaBundleIdentifier = mediaPlaybackInfo.bundleIdentifier {
            return bundleIdentifier == mediaBundleIdentifier
        }

        if let bundleURL, let mediaBundleURL = mediaPlaybackInfo.bundleURL {
            return bundleURL.standardizedFileURL == mediaBundleURL.standardizedFileURL
        }

        return false
    }

    @discardableResult
    private func openMediaApplication(from info: MediaPlaybackInfo?) -> Bool {
        guard let info else {
            return false
        }

        if let runningApp = runningAppService.apps.first(where: {
            if let bundleIdentifier = info.bundleIdentifier {
                return $0.bundleIdentifier == bundleIdentifier
            }

            return $0.bundleURL == info.bundleURL
        }) {
            runningAppService.activate(runningApp)
            return true
        }

        if let bundleURL = info.bundleURL {
            AppActionService.openApplication(at: bundleURL)
            return true
        }

        return false
    }

    private func sidebarItemKind(for url: URL) -> SidebarItem.Kind {
        if url.pathExtension == "app" {
            return .application
        }

        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true ? .folder : .file
    }

    private func title(for url: URL, kind: SidebarItem.Kind) -> String {
        if kind == .application {
            let bundle = Bundle(url: url)
            return (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
        }

        return url.lastPathComponent
    }
}
