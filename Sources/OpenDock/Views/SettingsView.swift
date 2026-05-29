import SwiftUI

public struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var preferencesStore: PreferencesStore
    @State private var selectedCategory: SettingsCategory = .dock
    @State private var loginItemEnabled = LoginItemService.isEnabled
    @State private var loginItemError: String?
    @State private var iconSizeValue = SidebarPreferences.defaults.iconSize
    @State private var spacingValue = SidebarPreferences.defaults.spacing
    @State private var opacityValue = SidebarPreferences.defaults.opacity
    @State private var bottomRevealDelayValue = Double(SidebarPreferences.defaults.bottomRevealDelayMilliseconds)
    @State private var activeSliderIDs: Set<String> = []
    @State private var preferenceDebouncer = PreferenceDebouncer()

    public init(appModel: AppModel) {
        self.appModel = appModel
        self._preferencesStore = ObservedObject(initialValue: appModel.preferencesStore)
    }

    public var body: some View {
        NavigationSplitView {
            List {
                ForEach(SettingsCategory.allCases) { category in
                    SettingsSidebarRow(category: category, isSelected: selectedCategory == category) {
                        selectCategory(category)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    pageHeader
                    selectedContent
                }
                .frame(maxWidth: 760, alignment: .topLeading)
                .padding(.horizontal, 34)
                .padding(.vertical, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 900, minHeight: 640)
        .background {
            SettingsWindowAccessor { window in
                appModel.setSettingsWindow(window)
            }
        }
        .onAppear {
            loginItemEnabled = LoginItemService.isEnabled
            syncSliderValues(from: preferencesStore.preferences)
        }
        .onReceive(preferencesStore.$preferences) { preferences in
            syncSliderValues(from: preferences)
        }
        .onDisappear {
            preferenceDebouncer.cancelAll()
        }
    }

    private var preferences: SidebarPreferences {
        preferencesStore.preferences
    }

    private var activeCategory: SettingsCategory {
        selectedCategory
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(activeCategory.title, systemImage: activeCategory.systemImage)
                .font(.system(size: 24, weight: .semibold))

            Text(activeCategory.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch activeCategory {
        case .dock:
            dockSettings
        case .appearance:
            appearanceSettings
        case .themes:
            themeSettings
        case .customization:
            customizationSettings
        case .features:
            featureSettings
        case .permissions:
            permissionSettings
        case .about:
            AboutContentView()
        }
    }

    private var dockSettings: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsSection("Placement") {
                SettingsRow(title: "Screen edge", detail: "Choose where OpenDock attaches.") {
                    Picker("Screen edge", selection: liveBinding(\.edge)) {
                        ForEach(SidebarEdge.allCases) { edge in
                            Text(edge.displayName).tag(edge)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 360)
                }

                SettingsDivider()

                SettingsToggleRow(
                    title: "Show on all displays",
                    detail: "Create one dock on every connected display.",
                    isOn: liveBinding(\.showOnAllDisplays)
                )

                SettingsDivider()

                SettingsToggleRow(
                    title: "Auto-hide",
                    detail: "Hide OpenDock until the pointer reaches the screen edge.",
                    isOn: liveBinding(\.autoHide)
                )

                SettingsDivider()

                DebouncedSliderRow(
                    title: "Bottom reveal delay",
                    detail: "Delay before a bottom-edge dock appears.",
                    value: $bottomRevealDelayValue,
                    range: 0...250,
                    step: 10,
                    formattedValue: "\(Int(bottomRevealDelayValue.rounded())) ms",
                    onChange: { value in
                        schedulePreferenceUpdate(id: "bottomRevealDelay") { preferences in
                            preferences.bottomRevealDelayMilliseconds = Int(value.rounded())
                        }
                    },
                    onEditingChanged: { editing in
                        handleSliderEditing(
                            editing,
                            id: "bottomRevealDelay",
                            commit: { preferences in
                                preferences.bottomRevealDelayMilliseconds = Int(bottomRevealDelayValue.rounded())
                            }
                        )
                    }
                )
            }

            SettingsSection("System Dock") {
                SettingsToggleRow(
                    title: "Hide macOS Dock while running",
                    detail: "Let OpenDock own the dock edge while this app is open.",
                    isOn: liveBinding(\.hideSystemDock)
                )
            }
        }
    }

    private var appearanceSettings: some View {
        SettingsSection("Layout") {
            DebouncedSliderRow(
                title: "Icon size",
                detail: "Bigger icons are easier to target, but cost more space.",
                value: $iconSizeValue,
                range: 24...58,
                step: 1,
                formattedValue: "\(Int(iconSizeValue.rounded()))",
                onChange: { value in
                    schedulePreferenceUpdate(id: "iconSize") { preferences in
                        preferences.iconSize = value
                    }
                },
                onEditingChanged: { editing in
                    handleSliderEditing(
                        editing,
                        id: "iconSize",
                        commit: { preferences in
                            preferences.iconSize = iconSizeValue
                        }
                    )
                }
            )

            SettingsDivider()

            DebouncedSliderRow(
                title: "Spacing",
                detail: "Distance between apps, stacks, and widgets.",
                value: $spacingValue,
                range: 4...18,
                step: 1,
                formattedValue: "\(Int(spacingValue.rounded()))",
                onChange: { value in
                    schedulePreferenceUpdate(id: "spacing") { preferences in
                        preferences.spacing = value
                    }
                },
                onEditingChanged: { editing in
                    handleSliderEditing(
                        editing,
                        id: "spacing",
                        commit: { preferences in
                            preferences.spacing = spacingValue
                        }
                    )
                }
            )

            SettingsDivider()

            DebouncedSliderRow(
                title: "Panel opacity",
                detail: "Overall OpenDock window opacity.",
                value: $opacityValue,
                range: 0.65...1,
                step: 0.01,
                formattedValue: "\(Int((opacityValue * 100).rounded()))%",
                onChange: { value in
                    schedulePreferenceUpdate(id: "opacity") { preferences in
                        preferences.opacity = value
                    }
                    appModel.revealSidebarForCustomizationPreview()
                },
                onEditingChanged: { editing in
                    handleSliderEditing(
                        editing,
                        id: "opacity",
                        commit: { preferences in
                            preferences.opacity = opacityValue
                        }
                    )
                }
            )
        }
    }

    private var themeSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsSection("Current Theme") {
                HStack(spacing: 14) {
                    ThemeSwatchStrip(colors: currentThemeSwatches)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentThemeTitle)
                            .font(.headline)
                        Text(currentThemeDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(SidebarThemePresets.all) { preset in
                    ThemePresetRow(
                        preset: preset,
                        isSelected: preset.appearance == preferences.appearance
                    ) {
                        applyTheme(preset)
                    }
                }
            }
        }
    }

    private var customizationSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Colors")
                    .font(.headline)

                Spacer()

                Button("Reset All Appearance") {
                    updatePreferences { preferences in
                        preferences.appearance.resetAll()
                    }
                    appModel.revealSidebarForCustomizationPreview()
                }
            }

            ForEach(SidebarAppearanceTokenGroup.allCases) { group in
                SettingsSection(group.title) {
                    let tokens = SidebarAppearanceTokenID.allCases.filter { $0.group == group }
                    HStack {
                        Text("Restore \(group.title.lowercased()) colors to OpenDock defaults.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: 16)

                        Button("Reset Section") {
                            resetAppearanceGroup(group)
                        }
                        .disabled(isAppearanceGroupDefault(group))
                    }
                    .padding(.vertical, 8)

                    SettingsDivider()

                    ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                        AppearanceTokenRow(
                            token: token,
                            currentColor: preferences.appearance[token: token],
                            defaultColor: SidebarAppearance.defaults[token: token],
                            currentAppearance: preferences.appearance,
                            color: appearanceColorBinding(token)
                        ) {
                            resetAppearanceToken(token)
                        }
                        .onTapGesture {
                            appModel.revealSidebarForCustomizationPreview()
                        }
                        .onHover { isHovering in
                            if isHovering {
                                appModel.revealSidebarForCustomizationPreview()
                            }
                        }

                        if index < tokens.count - 1 {
                            SettingsDivider()
                        }
                    }
                }
            }
        }
    }

    private var featureSettings: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsSection("Startup") {
                SettingsToggleRow(
                    title: "Open at Login",
                    detail: "Start OpenDock automatically when you sign in.",
                    isOn: loginItemBinding
                )

                if let loginItemError {
                    SettingsDivider()
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SettingsSection("Dock Features") {
                SettingsToggleRow(title: "Stacks", detail: "Group apps, files, and folders.", isOn: liveBinding(\.stacksEnabled))
                SettingsDivider()
                SettingsToggleRow(
                    title: "Second click hides active app",
                    detail: "Clicking the frontmost app again hides it.",
                    isOn: liveBinding(\.secondClickEnabled)
                )
                SettingsDivider()
                SettingsToggleRow(title: "Window switcher", detail: "Show the windows widget and hotkey behavior.", isOn: liveBinding(\.windowSwitcherEnabled))
                SettingsDivider()
                SettingsToggleRow(title: "Window previews", detail: "Show window previews when hovering over apps.", isOn: liveBinding(\.windowPreviewsEnabled))
                SettingsDivider()
                SettingsToggleRow(title: "Folder peek", detail: "Open folder previews from pinned folders.", isOn: liveBinding(\.folderPeekEnabled))
            }

            SettingsSection("Widgets") {
                let manifests = WidgetRegistry.shared.manifests(placement: .final)
                ForEach(Array(manifests.enumerated()), id: \.element.id) { index, manifest in
                    widgetPreferenceRows(for: manifest)

                    if index < manifests.count - 1 {
                        SettingsDivider()
                    }
                }
            }
        }
    }

    private var permissionSettings: some View {
        SettingsSection("macOS Permissions") {
            PermissionRow(
                title: "Accessibility",
                status: PermissionService.isAccessibilityTrusted ? "Enabled" : "Required for precise window actions",
                buttonTitle: PermissionService.isAccessibilityTrusted ? "Open" : "Enable"
            ) {
                PermissionService.requestAccessibilityPrompt()
                PermissionService.openAccessibilitySettings()
            }

            SettingsDivider()

            PermissionRow(
                title: "Screen Recording",
                status: PermissionService.isScreenRecordingTrusted ? "Enabled" : "Required for window thumbnails",
                buttonTitle: "Open"
            ) {
                PermissionService.openScreenRecordingSettings()
            }
        }
    }

    private var currentThemeTitle: String {
        guard let preset = SidebarThemePresets.all.first(where: { $0.appearance == preferences.appearance }) else {
            return "Custom"
        }

        return preset.title
    }

    private var currentThemeDescription: String {
        guard let preset = SidebarThemePresets.all.first(where: { $0.appearance == preferences.appearance }) else {
            return "Edited from a preset or built color by color."
        }

        return preset.description
    }

    private var currentThemeSwatches: [SidebarRGBAColor] {
        SidebarThemePresets.all.first { $0.appearance == preferences.appearance }?.swatches
            ?? [
                preferences.appearance.dockSurface,
                preferences.appearance.widgetBackground,
                preferences.appearance.primaryText,
                preferences.appearance.activeIconFill,
                preferences.appearance.badgeBackground,
            ]
    }

    private func liveBinding<Value>(_ keyPath: WritableKeyPath<SidebarPreferences, Value>) -> Binding<Value> {
        Binding(
            get: {
                preferencesStore.preferences[keyPath: keyPath]
            },
            set: { value in
                updatePreferences { preferences in
                    preferences[keyPath: keyPath] = value
                }
            }
        )
    }

    @ViewBuilder
    private func widgetPreferenceRows(for manifest: WidgetManifest) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsToggleRow(
                title: manifest.title,
                detail: manifest.description,
                isOn: widgetEnabledBinding(for: manifest)
            )

            if !manifest.settings.isEmpty {
                SettingsDivider()
                    .padding(.leading, 28)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(manifest.settings.enumerated()), id: \.element.id) { index, setting in
                        widgetSettingRow(setting, manifest: manifest)

                        if index < manifest.settings.count - 1 {
                            SettingsDivider()
                        }
                    }
                }
                .padding(.leading, 28)
                .disabled(!isWidgetEnabled(manifest))
            }
        }
    }

    @ViewBuilder
    private func widgetSettingRow(_ setting: WidgetSettingDefinition, manifest: WidgetManifest) -> some View {
        switch setting.type {
        case .boolean:
            SettingsToggleRow(
                title: setting.title,
                detail: setting.detail ?? "",
                isOn: widgetBooleanSettingBinding(setting, manifest: manifest)
            )
        case .string:
            SettingsRow(title: setting.title, detail: setting.detail ?? "") {
                TextField(setting.title, text: widgetStringSettingBinding(setting, manifest: manifest))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 190)
            }
        case .integer, .number:
            SettingsRow(title: setting.title, detail: setting.detail ?? "") {
                Text("Configured in widget code")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func widgetEnabledBinding(for manifest: WidgetManifest) -> Binding<Bool> {
        Binding(
            get: {
                isWidgetEnabled(manifest)
            },
            set: { value in
                updatePreferences { preferences in
                    if manifest.id == .windows {
                        preferences.windowSwitcherEnabled = value
                    } else {
                        preferences.widgetPreferences.setEnabled(value, for: manifest.id)
                    }
                }
            }
        )
    }

    private func widgetBooleanSettingBinding(_ setting: WidgetSettingDefinition, manifest: WidgetManifest) -> Binding<Bool> {
        Binding(
            get: {
                let defaultValue = setting.defaultValue.boolValue ?? false
                return preferencesStore.preferences.widgetPreferences.boolSetting(setting.id, for: manifest.id, default: defaultValue)
            },
            set: { value in
                updatePreferences { preferences in
                    preferences.widgetPreferences.setSetting(.bool(value), for: manifest.id, settingID: setting.id)
                }
            }
        )
    }

    private func widgetStringSettingBinding(_ setting: WidgetSettingDefinition, manifest: WidgetManifest) -> Binding<String> {
        Binding(
            get: {
                let defaultValue = setting.defaultValue.stringValue ?? ""
                return preferencesStore.preferences.widgetPreferences.stringSetting(setting.id, for: manifest.id, default: defaultValue)
            },
            set: { value in
                updatePreferences { preferences in
                    preferences.widgetPreferences.setSetting(.string(value), for: manifest.id, settingID: setting.id)
                }
            }
        )
    }

    private func isWidgetEnabled(_ manifest: WidgetManifest) -> Bool {
        preferencesStore.preferences.isWidgetEnabled(manifest.id)
    }

    private func appearanceColorBinding(_ token: SidebarAppearanceTokenID) -> Binding<Color> {
        Binding(
            get: {
                preferencesStore.preferences.appearance[token: token].color
            },
            set: { color in
                updatePreferences { preferences in
                    preferences.appearance[token: token] = SidebarRGBAColor(color: color)
                }
                appModel.revealSidebarForCustomizationPreview()
            }
        )
    }

    private func updatePreferences(_ transform: (inout SidebarPreferences) -> Void) {
        preferencesStore.update(transform)
    }

    private func applyTheme(_ preset: SidebarThemePreset) {
        updatePreferences { preferences in
            preferences.appearance = preset.appearance
        }
        appModel.revealSidebarForCustomizationPreview()
    }

    private func selectCategory(_ category: SettingsCategory) {
        selectedCategory = category

        if category == .themes || category == .customization {
            appModel.revealSidebarForCustomizationPreview()
        }
    }

    private func resetAppearanceToken(_ token: SidebarAppearanceTokenID) {
        updatePreferences { preferences in
            preferences.appearance.reset(token)
        }
        appModel.revealSidebarForCustomizationPreview()
    }

    private func resetAppearanceGroup(_ group: SidebarAppearanceTokenGroup) {
        updatePreferences { preferences in
            for token in SidebarAppearanceTokenID.allCases where token.group == group {
                preferences.appearance.reset(token)
            }
        }
        appModel.revealSidebarForCustomizationPreview()
    }

    private func isAppearanceGroupDefault(_ group: SidebarAppearanceTokenGroup) -> Bool {
        SidebarAppearanceTokenID.allCases
            .filter { $0.group == group }
            .allSatisfy { preferences.appearance[token: $0] == SidebarAppearance.defaults[token: $0] }
    }

    private func schedulePreferenceUpdate(id: String, transform: @escaping (inout SidebarPreferences) -> Void) {
        activeSliderIDs.insert(id)
        preferenceDebouncer.schedule(id: id) {
            updatePreferences(transform)
        }
    }

    private func handleSliderEditing(
        _ editing: Bool,
        id: String,
        commit: @escaping (inout SidebarPreferences) -> Void
    ) {
        if editing {
            activeSliderIDs.insert(id)
        } else {
            activeSliderIDs.remove(id)
            preferenceDebouncer.flush(id: id) {
                updatePreferences(commit)
            }
        }
    }

    private func syncSliderValues(from preferences: SidebarPreferences) {
        if !activeSliderIDs.contains("iconSize") {
            iconSizeValue = preferences.iconSize
        }

        if !activeSliderIDs.contains("spacing") {
            spacingValue = preferences.spacing
        }

        if !activeSliderIDs.contains("opacity") {
            opacityValue = preferences.opacity
        }

        if !activeSliderIDs.contains("bottomRevealDelay") {
            bottomRevealDelayValue = Double(preferences.bottomRevealDelayMilliseconds)
        }
    }

    private var loginItemBinding: Binding<Bool> {
        Binding(
            get: { loginItemEnabled },
            set: { value in
                do {
                    try LoginItemService.setEnabled(value)
                    loginItemEnabled = LoginItemService.isEnabled
                    loginItemError = nil
                } catch {
                    loginItemEnabled = LoginItemService.isEnabled
                    loginItemError = error.localizedDescription
                }
            }
        )
    }
}

private enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case dock
    case appearance
    case themes
    case customization
    case features
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dock:
            return "Dock"
        case .appearance:
            return "Appearance"
        case .themes:
            return "Themes"
        case .customization:
            return "Customization"
        case .features:
            return "Features"
        case .permissions:
            return "Permissions"
        case .about:
            return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .dock:
            return "Position, reveal behavior, and the relationship with the macOS Dock."
        case .appearance:
            return "Tune the dock size and overall panel opacity."
        case .themes:
            return "Start from a proven palette, then customize individual colors."
        case .customization:
            return "Edit each OpenDock color with live preview and one-click reset."
        case .features:
            return "Choose which dock tools and widgets are visible."
        case .permissions:
            return "Review the macOS permissions needed for window control and previews."
        case .about:
            return "OpenDock project information and links."
        }
    }

    var systemImage: String {
        switch self {
        case .dock:
            return "dock.rectangle"
        case .appearance:
            return "slider.horizontal.3"
        case .themes:
            return "paintpalette"
        case .customization:
            return "eyedropper"
        case .features:
            return "switch.2"
        case .permissions:
            return "lock.shield"
        case .about:
            return "info.circle"
        }
    }
}

private struct SettingsSidebarRow: View {
    var category: SettingsCategory
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(category.title, systemImage: category.systemImage)
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.clear)
        )
    }
}

private struct SettingsSection<Content: View>: View {
    var title: String
    var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct SettingsRow<Control: View>: View {
    var title: String
    var detail: String
    var control: Control

    init(title: String, detail: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 18)

            control
        }
        .padding(.vertical, 8)
    }
}

private struct SettingsToggleRow: View {
    var title: String
    var detail: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsRow(title: title, detail: detail) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
        }
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 2)
    }
}

private struct DebouncedSliderRow: View {
    var title: String
    var detail: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var formattedValue: String
    var onChange: (Double) -> Void
    var onEditingChanged: (Bool) -> Void

    var body: some View {
        SettingsRow(title: title, detail: detail) {
            HStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { value },
                        set: { nextValue in
                            value = nextValue
                            onChange(nextValue)
                        }
                    ),
                    in: range,
                    step: step,
                    onEditingChanged: onEditingChanged
                )
                .frame(width: 260)

                Text(formattedValue)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 54, alignment: .trailing)
            }
        }
    }
}

private struct ThemePresetRow: View {
    var preset: SidebarThemePreset
    var isSelected: Bool
    var onApply: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ThemeSwatchStrip(colors: preset.swatches)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(preset.title)
                        .font(.headline)

                    if isSelected {
                        Text("Active")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                }

                Text(preset.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 16)

            Button(isSelected ? "Applied" : "Apply Theme") {
                onApply()
            }
            .disabled(isSelected)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ThemeSwatchStrip: View {
    var colors: [SidebarRGBAColor]

    var body: some View {
        HStack(spacing: -7) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                Circle()
                    .fill(color.color)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.primary.opacity(0.14), lineWidth: 1))
            }
        }
        .frame(width: 84, alignment: .leading)
    }
}

private struct AppearanceTokenRow: View {
    var token: SidebarAppearanceTokenID
    var currentColor: SidebarRGBAColor
    var defaultColor: SidebarRGBAColor
    var currentAppearance: SidebarAppearance
    @Binding var color: Color
    var onReset: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            AppearanceTokenPreview(token: token, appearance: currentAppearance)

            VStack(alignment: .leading, spacing: 4) {
                Text(token.title)
                    .font(.callout.weight(.medium))
                Text(token.affectedArea)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 14)

            HStack(spacing: 10) {
                LabeledSwatch(title: "Current", color: currentColor)
                LabeledSwatch(title: "Default", color: defaultColor)
            }

            ColorPicker(token.title, selection: $color, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 42)

            Button("Reset") {
                onReset()
            }
            .disabled(currentColor == defaultColor)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

private struct LabeledSwatch: View {
    var title: String
    var color: SidebarRGBAColor

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(color.color)
                .frame(width: 32, height: 22)
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(.primary.opacity(0.16), lineWidth: 1))

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AppearanceTokenPreview: View {
    var token: SidebarAppearanceTokenID
    var appearance: SidebarAppearance

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(appearance.popoverSurface.color)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(appearance.popoverBorder.color, lineWidth: 1))

            previewContent
        }
        .frame(width: 76, height: 48)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch token.previewKind {
        case .dockSurface:
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(appearance.dockSurface.color)
                .frame(width: 54, height: 26)
        case .separator:
            HStack(spacing: 8) {
                Circle().fill(appearance.widgetBackground.color).frame(width: 18, height: 18)
                Rectangle().fill(appearance.separator.color).frame(width: 2, height: 28)
                Circle().fill(appearance.widgetBackground.color).frame(width: 18, height: 18)
            }
        case .text:
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(appearance.primaryText.color).frame(width: 46, height: 5)
                Capsule().fill(appearance.secondaryText.color).frame(width: 34, height: 4)
                Capsule().fill(appearance.inverseText.color).frame(width: 26, height: 4)
            }
        case .iconState:
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(appearance.activeIconFill.color)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(appearance.activeIconBorder.color, lineWidth: 1.5))
                    .shadow(color: appearance.activeIconGlow.color, radius: 4)
                    .frame(width: 30, height: 30)
                Capsule().fill(appearance.runningIndicator.color).frame(width: 14, height: 3).offset(y: 7)
            }
        case .badge:
            Text("3")
                .font(.caption.bold())
                .foregroundStyle(appearance.badgeText.color)
                .frame(width: 22, height: 18)
                .background(Capsule().fill(appearance.badgeBackground.color))
                .overlay(Capsule().stroke(appearance.badgeBorder.color, lineWidth: 1))
        case .widget:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(appearance.widgetBackground.color)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(appearance.widgetBorder.color, lineWidth: 1))
                .frame(width: 42, height: 28)
        case .calendar:
            Text("28")
                .font(.caption.bold())
                .foregroundStyle(appearance.primaryText.color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(appearance.calendarHighlight.color))
        case .mediaOverlay:
            Capsule()
                .fill(appearance.mediaOverlayBackground.color)
                .frame(width: 44, height: 18)
                .overlay(Capsule().fill(appearance.inverseText.color).frame(width: 24, height: 4))
        case .popover:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(appearance.popoverSurface.color)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(appearance.popoverBorder.color, lineWidth: 2))
                .frame(width: 46, height: 30)
        }
    }
}

private struct PermissionRow: View {
    var title: String
    var status: String
    var buttonTitle: String
    var action: () -> Void

    var body: some View {
        SettingsRow(title: title, detail: status) {
            Button(buttonTitle) {
                action()
            }
        }
    }
}
