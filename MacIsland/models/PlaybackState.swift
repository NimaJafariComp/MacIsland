//
//  PlaybackState.swift
//  boringNotch
//
//  Created by Alexander on 2025-03-29.
//

import Foundation

enum RepeatMode: Int, Codable {
    case off = 1
    case one = 2
    case all = 3
}

struct PlaybackState {
    var bundleIdentifier: String
    var isPlaying: Bool = false
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var currentTime: Double = 0
    var duration: Double = 0
    var playbackRate: Double = 1
    var isShuffled: Bool = false
    var repeatMode: RepeatMode = .off
    var lastUpdated: Date = Date.distantPast
    var artwork: Data?
    var volume: Double = 0.5
    var isFavorite: Bool = false
}

enum MediaPresentationPolicy {
    static func hasTrack(_ state: PlaybackState) -> Bool {
        let title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = state.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && !artist.isEmpty && title != "Unknown" && artist != "Unknown"
    }

    static func isIdle(_ state: PlaybackState) -> Bool {
        !state.isPlaying && !hasTrack(state)
    }
}

extension PlaybackState: Equatable {
    static func == (lhs: PlaybackState, rhs: PlaybackState) -> Bool {
        return lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.isPlaying == rhs.isPlaying
            && lhs.title == rhs.title
            && lhs.artist == rhs.artist
            && lhs.album == rhs.album
            && lhs.currentTime == rhs.currentTime
            && lhs.duration == rhs.duration
            && lhs.isShuffled == rhs.isShuffled
            && lhs.repeatMode == rhs.repeatMode
            && lhs.artwork == rhs.artwork
            && lhs.isFavorite == rhs.isFavorite
    }
}
