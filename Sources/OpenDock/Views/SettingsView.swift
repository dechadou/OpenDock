import SwiftUI

public struct SettingsView: View {
    @ObservedObject var appModel: AppModel
    @ObservedObject private var preferencesStore: PreferencesStore
    @State private var loginItemEnabled = LoginItemService.isEnabled
    @State private var loginItemError: String?
    @State private var draftPreferences: SidebarPreferences

    public init(appModel: AppModel) {
        self.appModel = appModel
        self._preferencesStore = ObservedObject(initialValue: appModel.preferencesStore)
        self._draftPreferences = State(initialValue: appModel.preferencesStore.preferences)
    }

    public var body: some View {
        Form {
            Section("Placement") {
                Picker("Screen edge", selection: draftBinding(\.edge)) {
                    ForEach(SidebarEdge.allCases) { edge in
                        Text(edge.displayName).tag(edge)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Show on all displays", isOn: draftBinding(\.showOnAllDisplays))
                Toggle("Auto-hide", isOn: draftBinding(\.autoHide))

                LabeledContent("Bottom reveal delay") {
                    HStack {
                        Slider(value: bottomRevealDelayBinding, in: 0...250, step: 10)
                        Text("\(draftPreferences.bottomRevealDelayMilliseconds) ms")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 58, alignment: .trailing)
                    }
                }
            }

            Section("System") {
                Toggle("Open at Login", isOn: loginItemBinding)

                Toggle("Hide macOS Dock while running", isOn: draftBinding(\.hideSystemDock))

                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Appearance") {
                LabeledContent("Icon size") {
                    HStack {
                        Slider(value: draftBinding(\.iconSize), in: 24...58, step: 1)
                        Text("\(Int(draftPreferences.iconSize))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                }

                LabeledContent("Spacing") {
                    HStack {
                        Slider(value: draftBinding(\.spacing), in: 4...18, step: 1)
                        Text("\(Int(draftPreferences.spacing))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 34, alignment: .trailing)
                    }
                }

                LabeledContent("Opacity") {
                    HStack {
                        Slider(value: draftBinding(\.opacity), in: 0.65...1, step: 0.01)
                        Text("\(Int(draftPreferences.opacity * 100))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section("Features") {
                Toggle("Stacks", isOn: draftBinding(\.stacksEnabled))
                Toggle("Second click hides active app", isOn: draftBinding(\.secondClickEnabled))
                Toggle("Window switcher", isOn: draftBinding(\.windowSwitcherEnabled))
                Toggle("Window previews", isOn: draftBinding(\.windowPreviewsEnabled))
                Toggle("Folder peek", isOn: draftBinding(\.folderPeekEnabled))
                Toggle("Trash widget", isOn: draftBinding(\.trashWidgetEnabled))
                Toggle("Date & time widget", isOn: draftBinding(\.dateTimeWidgetEnabled))
                Toggle("Media controls", isOn: draftBinding(\.mediaControlsEnabled))
                Toggle("Hide controlled media app icon", isOn: draftBinding(\.hideMediaSourceAppIcon))
                    .disabled(!draftPreferences.mediaControlsEnabled)
            }

            Section("Permissions") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility")
                        Text(PermissionService.isAccessibilityTrusted ? "Enabled" : "Required for precise window actions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(PermissionService.isAccessibilityTrusted ? "Open" : "Enable") {
                        PermissionService.requestAccessibilityPrompt()
                        PermissionService.openAccessibilitySettings()
                    }
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Screen Recording")
                        Text(PermissionService.isScreenRecordingTrusted ? "Enabled" : "Required for window thumbnails")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Open") {
                        PermissionService.openScreenRecordingSettings()
                    }
                }
            }

            Section {
                HStack {
                    Button("Reset Defaults") {
                        draftPreferences = .defaults
                    }

                    Spacer()

                    Button("Revert") {
                        draftPreferences = preferencesStore.preferences
                    }
                    .disabled(!hasDraftChanges)

                    Button("Apply Changes") {
                        preferencesStore.update { preferences in
                            preferences = draftPreferences
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!hasDraftChanges)
                }
            } footer: {
                Text("Placement, appearance, and feature changes apply when you click Apply Changes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(appModel.isSidebarVisible ? "Hide Sidebar Now" : "Show Sidebar Now") {
                    appModel.toggleSidebar()
                }
            } footer: {
                Text("Shows or hides the sidebar immediately — also available from the menu bar icon (⌥⌘S).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            loginItemEnabled = LoginItemService.isEnabled
            draftPreferences = preferencesStore.preferences
        }
        .onReceive(preferencesStore.$preferences) { preferences in
            if !hasDraftChanges {
                draftPreferences = preferences
            }
        }
    }

    private var hasDraftChanges: Bool {
        draftPreferences != preferencesStore.preferences
    }

    private func draftBinding<Value>(_ keyPath: WritableKeyPath<SidebarPreferences, Value>) -> Binding<Value> {
        Binding(
            get: {
                draftPreferences[keyPath: keyPath]
            },
            set: { value in
                draftPreferences[keyPath: keyPath] = value
            }
        )
    }

    private var bottomRevealDelayBinding: Binding<Double> {
        Binding(
            get: {
                Double(draftPreferences.bottomRevealDelayMilliseconds)
            },
            set: { value in
                draftPreferences.bottomRevealDelayMilliseconds = Int(value.rounded())
            }
        )
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
