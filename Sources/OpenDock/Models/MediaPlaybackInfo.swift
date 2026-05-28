import Foundation

struct MediaPlaybackInfo: Equatable, Sendable {
    enum PlaybackState: String, Sendable {
        case playing
        case paused
        case stopped
        case unknown

        var displayName: String {
            switch self {
            case .playing:
                return "Playing"
            case .paused:
                return "Paused"
            case .stopped:
                return "Stopped"
            case .unknown:
                return "Unknown"
            }
        }
    }

    var appName: String
    var bundleIdentifier: String?
    var bundleURL: URL?
    var title: String
    var artist: String
    var album: String
    var artworkURL: URL?
    var state: PlaybackState

    var subtitle: String {
        if !artist.isEmpty {
            return artist
        }

        if !album.isEmpty {
            return album
        }

        return state.displayName
    }
}
