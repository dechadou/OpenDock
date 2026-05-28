import Carbon
import Foundation

@MainActor
final class HotKeyService {
    private enum HotKeyID: UInt32 {
        case toggleSidebar = 1
        case openLauncher = 2
        case openWindowSwitcher = 3
    }

    private var eventHandler: EventHandlerRef?
    private var toggleRef: EventHotKeyRef?
    private var launcherRef: EventHotKeyRef?
    private var windowSwitcherRef: EventHotKeyRef?
    private var onToggleSidebar: (() -> Void)?
    private var onOpenLauncher: (() -> Void)?
    private var onOpenWindowSwitcher: (() -> Void)?
    private var isWindowSwitcherHotKeyEnabled = true

    func start(
        onToggleSidebar: @escaping () -> Void,
        onOpenLauncher: @escaping () -> Void,
        onOpenWindowSwitcher: @escaping () -> Void,
        windowSwitcherEnabled: Bool
    ) {
        self.onToggleSidebar = onToggleSidebar
        self.onOpenLauncher = onOpenLauncher
        self.onOpenWindowSwitcher = onOpenWindowSwitcher

        guard eventHandler == nil else {
            setWindowSwitcherEnabled(windowSwitcherEnabled)
            return
        }

        self.isWindowSwitcherHotKeyEnabled = windowSwitcherEnabled

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.handleHotKey,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        registerHotKeys()
    }

    func setWindowSwitcherEnabled(_ enabled: Bool) {
        guard isWindowSwitcherHotKeyEnabled != enabled else {
            return
        }

        isWindowSwitcherHotKeyEnabled = enabled

        guard eventHandler != nil else {
            return
        }

        if enabled {
            registerWindowSwitcherHotKey()
        } else {
            unregisterWindowSwitcherHotKey()
        }
    }

    func stop() {
        if let toggleRef {
            UnregisterEventHotKey(toggleRef)
        }

        if let launcherRef {
            UnregisterEventHotKey(launcherRef)
        }

        unregisterWindowSwitcherHotKey()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }

        toggleRef = nil
        launcherRef = nil
        windowSwitcherRef = nil
        eventHandler = nil
        onToggleSidebar = nil
        onOpenLauncher = nil
        onOpenWindowSwitcher = nil
        isWindowSwitcherHotKeyEnabled = true
    }

    private func registerHotKeys() {
        let toggleID = EventHotKeyID(signature: Self.signature, id: HotKeyID.toggleSidebar.rawValue)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            Self.modifiers,
            toggleID,
            GetApplicationEventTarget(),
            0,
            &toggleRef
        )

        let launcherID = EventHotKeyID(signature: Self.signature, id: HotKeyID.openLauncher.rawValue)
        RegisterEventHotKey(
            UInt32(kVK_Space),
            Self.modifiers,
            launcherID,
            GetApplicationEventTarget(),
            0,
            &launcherRef
        )

        if isWindowSwitcherHotKeyEnabled {
            registerWindowSwitcherHotKey()
        }
    }

    private func registerWindowSwitcherHotKey() {
        guard windowSwitcherRef == nil else {
            return
        }

        let windowSwitcherID = EventHotKeyID(signature: Self.signature, id: HotKeyID.openWindowSwitcher.rawValue)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_W),
            Self.modifiers,
            windowSwitcherID,
            GetApplicationEventTarget(),
            0,
            &windowSwitcherRef
        )
    }

    private func unregisterWindowSwitcherHotKey() {
        if let windowSwitcherRef {
            UnregisterEventHotKey(windowSwitcherRef)
        }

        windowSwitcherRef = nil
    }

    private func handle(id: UInt32) {
        switch HotKeyID(rawValue: id) {
        case .toggleSidebar:
            onToggleSidebar?()
        case .openLauncher:
            onOpenLauncher?()
        case .openWindowSwitcher:
            onOpenWindowSwitcher?()
        case nil:
            break
        }
    }

    private static let handleHotKey: EventHandlerUPP = { _, event, userData in
        guard let event,
            let userData
        else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr else {
            return status
        }

        let service = Unmanaged<HotKeyService>.fromOpaque(userData).takeUnretainedValue()

        Task { @MainActor in
            service.handle(id: hotKeyID.id)
        }

        return noErr
    }

    private static let signature = fourCharCode("LSBR")
    private static let modifiers = UInt32(cmdKey | optionKey)

    private static func fourCharCode(_ value: String) -> OSType {
        value.utf8.reduce(0) { result, character in
            (result << 8) + OSType(character)
        }
    }
}
