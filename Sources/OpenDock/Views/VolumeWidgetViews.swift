import SwiftUI

struct VolumeSidebarControl: View {
    var iconSize: CGFloat
    var edge: SidebarEdge
    @ObservedObject var appModel: AppModel
    @State private var isPopoverPresented = false
    @Environment(\.sidebarAppearance) private var appearance

    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        compactButton
            .onAppear {
                appModel.refreshVolumeState()
            }
            .onReceive(timer) { _ in
                appModel.refreshVolumeState()
            }
    }

    private var compactButton: some View {
        Button {
            setPopoverPresented(true)
        } label: {
            Image(systemName: speakerSymbolName)
                .font(.system(size: iconSize * 0.54, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(appearance.primaryText.color)
                .frame(width: iconSize + 12, height: iconSize + 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(appearance.widgetBackground.color))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(appearance.widgetBorder.color, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(helpText)
        .popover(isPresented: popoverBinding, arrowEdge: edge.popoverArrowEdge) {
            VolumePopover(appModel: appModel)
                .frame(width: 104, height: 230)
                .environment(\.sidebarAppearance, appearance)
        }
    }

    private var popoverBinding: Binding<Bool> {
        Binding(
            get: { isPopoverPresented },
            set: { setPopoverPresented($0) }
        )
    }

    private func setPopoverPresented(_ presented: Bool) {
        isPopoverPresented = presented
        appModel.setSidebarInteractionSurface("volume-controls", visible: presented)
    }

    private var speakerSymbolName: String {
        if appModel.volumeState.isMuted || appModel.volumeState.volume == 0 {
            return "speaker.slash.fill"
        }

        if appModel.volumeState.volume < 0.35 {
            return "speaker.wave.1.fill"
        }

        return "speaker.wave.2.fill"
    }

    private var helpText: String {
        if appModel.volumeState.isVolumeSettable || appModel.volumeState.isMuteSettable {
            let device = appModel.volumeState.outputDeviceName ?? "Output"
            return "\(device), \(Int((appModel.volumeState.volume * 100).rounded()))%"
        }

        return "Volume unavailable for this output device"
    }
}

private struct VolumePopover: View {
    @ObservedObject var appModel: AppModel
    @Environment(\.sidebarAppearance) private var appearance

    var body: some View {
        VStack(spacing: 12) {
            Text("\(Int((appModel.volumeState.volume * 100).rounded()))")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(appearance.secondaryText.color)
                .frame(height: 18)

            verticalSlider

            Button {
                appModel.toggleOutputMute()
            } label: {
                Image(systemName: appModel.volumeState.isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .background(Circle().fill(appearance.widgetBackground.color))
            .overlay(Circle().stroke(appearance.widgetBorder.color, lineWidth: 1))
            .disabled(!appModel.volumeState.isMuteSettable)
            .help(appModel.volumeState.isMuted ? "Unmute" : "Mute")
        }
        .padding(14)
        .foregroundStyle(appearance.primaryText.color)
        .background(appearance.popoverSurface.color)
        .onAppear {
            appModel.refreshVolumeState()
        }
    }

    private var verticalSlider: some View {
        Slider(
            value: Binding(
                get: { appModel.volumeState.volume },
                set: { appModel.setOutputVolume($0) }
            ),
            in: 0...1
        )
        .controlSize(.small)
        .frame(width: 142)
        .rotationEffect(.degrees(-90))
        .frame(width: 44, height: 142)
        .disabled(!appModel.volumeState.isVolumeSettable)
    }
}
