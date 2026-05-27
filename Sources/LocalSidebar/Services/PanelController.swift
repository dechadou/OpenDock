import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class PanelController {
    private var panels: [String: NSPanel] = [:]
    private var panelScreenFrames: [String: CGRect] = [:]
    private var bottomRevealTimers: [String: Timer] = [:]
    private var screenObserver: NSObjectProtocol?
    private var autoHideTimer: Timer?
    private weak var appModel: AppModel?
    private var preferences: SidebarPreferences = .defaults
    private var sidebarEnabled = true

    func start(appModel: AppModel, preferences: SidebarPreferences) {
        self.appModel = appModel
        self.preferences = preferences

        rebuildPanels()
        observeScreens()
        updateAutoHideVisibility()
        updateAutoHideTimerState()
    }

    func stop() {
        cancelAllBottomReveals()
        panels.values.forEach { $0.close() }
        panels = [:]
        panelScreenFrames = [:]

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }

        autoHideTimer?.invalidate()
        autoHideTimer = nil
        screenObserver = nil
        appModel = nil
    }

    func apply(preferences: SidebarPreferences) {
        let diff = PanelPreferenceDiff(oldValue: self.preferences, newValue: preferences)
        self.preferences = preferences

        if diff.requiresRebuild {
            rebuildPanels()
        } else {
            if diff.requiresFrameUpdate {
                updatePanelFrames()
            }

            if diff.requiresOpacityUpdate {
                panels.values.forEach { $0.alphaValue = preferences.opacity }
            }
        }

        if diff.requiresVisibilityUpdate {
            cancelAllBottomReveals()
        }

        updateAutoHideVisibility()
        updateAutoHideTimerState()
    }

    func setSidebarEnabled(_ enabled: Bool) {
        sidebarEnabled = enabled
        updateAutoHideVisibility()
        updateAutoHideTimerState()
    }

    private func rebuildPanels() {
        guard let appModel else {
            return
        }

        cancelAllBottomReveals()
        panels.values.forEach { $0.close() }
        panels = [:]
        panelScreenFrames = [:]

        for screen in targetScreens() {
            let id = screenID(for: screen)
            let frame = SidebarFrameCalculator.frame(
                screenFrame: screen.frame,
                edge: preferences.edge,
                thickness: CGFloat(preferences.panelThickness)
            )

            let panel = LocalSidebarPanel(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            panel.level = .statusBar
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isReleasedWhenClosed = false
            panel.alphaValue = preferences.opacity
            panel.contentView = NSHostingView(rootView: SidebarPanelView(appModel: appModel))
            panels[id] = panel
            panelScreenFrames[id] = screen.frame
        }
    }

    private func observeScreens() {
        guard screenObserver == nil else {
            return
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.rebuildPanels()
                self?.updateAutoHideVisibility()
            }
        }
    }

    private func updatePanelFrames() {
        for (id, panel) in panels {
            guard let screenFrame = screenFrame(for: id, panel: panel) else {
                continue
            }

            let frame = SidebarFrameCalculator.frame(
                screenFrame: screenFrame,
                edge: preferences.edge,
                thickness: CGFloat(preferences.panelThickness)
            )
            panel.setFrame(frame, display: true)
        }
    }

    private func updateAutoHideTimerState() {
        if sidebarEnabled && preferences.autoHide {
            startAutoHideTimer()
        } else {
            stopAutoHideTimer()
        }
    }

    private func startAutoHideTimer() {
        guard autoHideTimer == nil else {
            return
        }

        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAutoHideVisibility()
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        autoHideTimer = timer
    }

    private func stopAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    private func updateAutoHideVisibility() {
        guard sidebarEnabled else {
            cancelAllBottomReveals()
            for (id, panel) in panels {
                hide(panel, panelID: id)
            }
            return
        }

        guard preferences.autoHide else {
            cancelAllBottomReveals()
            for (id, panel) in panels {
                show(panel, panelID: id)
            }
            return
        }

        if appModel?.shouldHoldSidebarVisibleForInteraction == true {
            cancelAllBottomReveals()
            for (id, panel) in panels {
                show(panel, panelID: id)
            }
            return
        }

        let mouseLocation = NSEvent.mouseLocation

        for (id, panel) in panels {
            guard let screenFrame = screenFrame(for: id, panel: panel) else {
                continue
            }

            if panel.isVisible,
                PanelRevealPolicy.shouldHoldVisible(
                    panelFrame: panel.frame,
                    screenFrame: screenFrame,
                    mouseLocation: mouseLocation
                )
            {
                cancelBottomReveal(panelID: id)
                show(panel, panelID: id)
                continue
            }

            if PanelRevealPolicy.shouldRevealHidden(
                edge: preferences.edge,
                screenFrame: screenFrame,
                mouseLocation: mouseLocation
            ) {
                if preferences.edge == .bottom, !panel.isVisible {
                    scheduleBottomReveal(panelID: id, panel: panel, screenFrame: screenFrame)
                } else {
                    cancelBottomReveal(panelID: id)
                    show(panel, panelID: id, animated: true)
                }
            } else {
                cancelBottomReveal(panelID: id)
                hide(panel, panelID: id)
            }
        }
    }

    private func show(_ panel: NSPanel, panelID: String? = nil, animated: Bool = false) {
        // Already on screen — return early so the polling timer does not re-order
        // the window dozens of times per second.
        if panel.isVisible {
            return
        }

        panel.alphaValue = preferences.opacity

        guard animated,
            let screenFrame = screenFrame(for: panelID, panel: panel)
        else {
            if let frame = normalFrame(for: panelID, panel: panel) {
                panel.setFrame(frame, display: false)
            }

            panel.orderFrontRegardless()
            return
        }

        let finalFrame = SidebarFrameCalculator.frame(
            screenFrame: screenFrame,
            edge: preferences.edge,
            thickness: CGFloat(preferences.panelThickness)
        )

        panel.setFrame(hiddenStartFrame(from: finalFrame, screenFrame: screenFrame), display: false)
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
        }
    }

    /// Off-screen start frame for the slide-in reveal, just past the docked edge.
    private func hiddenStartFrame(from finalFrame: CGRect, screenFrame: CGRect) -> CGRect {
        let gap: CGFloat = 4
        var startFrame = finalFrame

        switch preferences.edge {
        case .left:
            startFrame.origin.x = screenFrame.minX - finalFrame.width - gap
        case .right:
            startFrame.origin.x = screenFrame.maxX + gap
        case .top:
            startFrame.origin.y = screenFrame.maxY + gap
        case .bottom:
            startFrame.origin.y = screenFrame.minY - finalFrame.height - gap
        }

        return startFrame
    }

    private func hide(_ panel: NSPanel, panelID: String? = nil) {
        guard panel.isVisible else {
            return
        }

        panel.orderOut(nil)

        if let frame = normalFrame(for: panelID, panel: panel) {
            panel.setFrame(frame, display: false)
        }
    }

    private func scheduleBottomReveal(panelID: String, panel: NSPanel, screenFrame: CGRect) {
        guard bottomRevealTimers[panelID] == nil else {
            return
        }

        let delay = TimeInterval(max(0, preferences.bottomRevealDelayMilliseconds)) / 1000
        guard delay > 0 else {
            show(panel, panelID: panelID, animated: true)
            return
        }

        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else {
                    return
                }

                self.bottomRevealTimers[panelID] = nil

                guard self.sidebarEnabled,
                    self.preferences.autoHide,
                    self.preferences.edge == .bottom,
                    let currentPanel = self.panels[panelID],
                    !currentPanel.isVisible
                else {
                    return
                }

                let currentScreenFrame = self.screenFrame(for: panelID, panel: currentPanel) ?? screenFrame
                guard
                    PanelRevealPolicy.shouldRevealHidden(
                        edge: .bottom,
                        screenFrame: currentScreenFrame,
                        mouseLocation: NSEvent.mouseLocation
                    )
                else {
                    return
                }

                self.show(currentPanel, panelID: panelID, animated: true)
            }
        }

        bottomRevealTimers[panelID] = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func cancelBottomReveal(panelID: String) {
        bottomRevealTimers.removeValue(forKey: panelID)?.invalidate()
    }

    private func cancelAllBottomReveals() {
        bottomRevealTimers.values.forEach { $0.invalidate() }
        bottomRevealTimers = [:]
    }

    private func normalFrame(for panelID: String?, panel: NSPanel) -> CGRect? {
        guard let screenFrame = screenFrame(for: panelID, panel: panel) else {
            return nil
        }

        return SidebarFrameCalculator.frame(
            screenFrame: screenFrame,
            edge: preferences.edge,
            thickness: CGFloat(preferences.panelThickness)
        )
    }

    private func screenFrame(for panelID: String?, panel: NSPanel) -> CGRect? {
        if let panelID, let screenFrame = panelScreenFrames[panelID] {
            return screenFrame
        }

        return panel.screen?.frame
    }

    private func targetScreens() -> [NSScreen] {
        if preferences.showOnAllDisplays {
            return NSScreen.screens
        }

        return [NSScreen.main ?? NSScreen.screens.first].compactMap { $0 }
    }

    private func screenID(for screen: NSScreen) -> String {
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            return number.stringValue
        }

        return "\(screen.frame.origin.x)-\(screen.frame.origin.y)-\(screen.frame.width)-\(screen.frame.height)"
    }
}

private final class LocalSidebarPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}
