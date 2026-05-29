import AudioToolbox
import CoreAudio
import Foundation

public enum VolumeServiceError: Error, Equatable, CustomStringConvertible {
    case audioHardwareFailure(OSStatus)
    case unknownOutputDevice
    case volumeUnavailable
    case muteUnavailable

    public var description: String {
        switch self {
        case .audioHardwareFailure(let status):
            return "Core Audio returned \(status)."
        case .unknownOutputDevice:
            return "No default output device is available."
        case .volumeUnavailable:
            return "The default output device does not support software volume."
        case .muteUnavailable:
            return "The default output device does not support software mute."
        }
    }
}

public protocol VolumeAudioBackend: Sendable {
    func currentState() throws -> VolumeState
    func setVolume(_ volume: Double) throws
    func setMuted(_ isMuted: Bool) throws
}

public struct VolumeService<Backend: VolumeAudioBackend>: Sendable {
    public var backend: Backend

    public init(backend: Backend) {
        self.backend = backend
    }

    public func currentState() throws -> VolumeState {
        try backend.currentState()
    }

    public func setVolume(_ volume: Double) throws {
        try backend.setVolume(Self.clampedVolume(volume))
    }

    public func setMuted(_ isMuted: Bool) throws {
        try backend.setMuted(isMuted)
    }

    public func toggleMute(from state: VolumeState) throws {
        try setMuted(!state.isMuted)
    }

    public static func clampedVolume(_ volume: Double) -> Double {
        min(1, max(0, volume))
    }
}

public struct CoreAudioVolumeBackend: VolumeAudioBackend {
    public init() {}

    public func currentState() throws -> VolumeState {
        let deviceID = try defaultOutputDeviceID()
        var volumeAddress = Self.virtualMainVolumeAddress
        var muteAddress = Self.muteAddress

        let hasVolume = AudioHardwareServiceHasProperty(deviceID, &volumeAddress)
        let hasMute = AudioObjectHasProperty(deviceID, &muteAddress)

        var volumeSettable = DarwinBoolean(false)
        if hasVolume {
            _ = AudioHardwareServiceIsPropertySettable(deviceID, &volumeAddress, &volumeSettable)
        }

        var muteSettable = DarwinBoolean(false)
        if hasMute {
            _ = AudioObjectIsPropertySettable(deviceID, &muteAddress, &muteSettable)
        }

        return VolumeState(
            volume: hasVolume ? try readVolume(deviceID: deviceID) : 0,
            isMuted: hasMute ? try readMute(deviceID: deviceID) : false,
            isVolumeSettable: hasVolume && volumeSettable.boolValue,
            isMuteSettable: hasMute && muteSettable.boolValue,
            outputDeviceName: try? outputDeviceName(deviceID: deviceID)
        )
    }

    public func setVolume(_ volume: Double) throws {
        let deviceID = try defaultOutputDeviceID()
        var address = Self.virtualMainVolumeAddress
        guard AudioHardwareServiceHasProperty(deviceID, &address) else {
            throw VolumeServiceError.volumeUnavailable
        }

        var value = Float32(min(1, max(0, volume)))
        let status = AudioHardwareServiceSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &value
        )
        try check(status)
    }

    public func setMuted(_ isMuted: Bool) throws {
        let deviceID = try defaultOutputDeviceID()
        var address = Self.muteAddress
        guard AudioObjectHasProperty(deviceID, &address) else {
            throw VolumeServiceError.muteUnavailable
        }

        var value: UInt32 = isMuted ? 1 : 0
        let status = AudioObjectSetPropertyData(
            deviceID,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &value
        )
        try check(status)
    }

    private func readVolume(deviceID: AudioObjectID) throws -> Double {
        var address = Self.virtualMainVolumeAddress
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioHardwareServiceGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        try check(status)
        return Double(value)
    }

    private func readMute(deviceID: AudioObjectID) throws -> Bool {
        var address = Self.muteAddress
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        try check(status)
        return value != 0
    }

    private func defaultOutputDeviceID() throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        try check(status)

        guard deviceID != kAudioObjectUnknown else {
            throw VolumeServiceError.unknownOutputDevice
        }

        return deviceID
    }

    private func outputDeviceName(deviceID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &name) { pointer in
            AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, pointer)
        }
        try check(status)
        return name as String? ?? "Output"
    }

    private func check(_ status: OSStatus) throws {
        guard status == noErr else {
            throw VolumeServiceError.audioHardwareFailure(status)
        }
    }

    private static var virtualMainVolumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
