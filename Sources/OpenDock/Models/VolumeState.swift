import Foundation

public struct VolumeState: Equatable, Sendable {
    public var volume: Double
    public var isMuted: Bool
    public var isVolumeSettable: Bool
    public var isMuteSettable: Bool
    public var outputDeviceName: String?

    public init(
        volume: Double,
        isMuted: Bool,
        isVolumeSettable: Bool,
        isMuteSettable: Bool,
        outputDeviceName: String? = nil
    ) {
        self.volume = volume
        self.isMuted = isMuted
        self.isVolumeSettable = isVolumeSettable
        self.isMuteSettable = isMuteSettable
        self.outputDeviceName = outputDeviceName
    }

    public static let unavailable = VolumeState(
        volume: 0,
        isMuted: false,
        isVolumeSettable: false,
        isMuteSettable: false
    )
}
