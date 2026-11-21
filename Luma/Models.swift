import Foundation

struct Track: Identifiable, Codable, Equatable, Sendable {
    var id: String
    var title: String
    var artist: String
    var album: String
    var style: Int
    var filename: String
    var isImported = false
    var length: TimeInterval? = nil
    var addedAt: Date? = nil
    var artworkFilename: String? = nil
    var albumArtist: String? = nil
    var genre: String? = nil
    var year: String? = nil
    var flacMetadataVersion: Int? = nil
    var trackNumber: Int? = nil
    var discNumber: Int? = nil
    var contentHash: String? = nil
    var sampleRate: Double? = nil
    var bitDepth: Int? = nil
    var channels: Int? = nil
    var replayGainTrackDB: Double? = nil
    var replayGainAlbumDB: Double? = nil
    var replayGainTrackPeak: Double? = nil
    var replayGainAlbumPeak: Double? = nil

    var albumGroupingArtist: String { albumArtist?.isEmpty == false ? albumArtist! : artist }
    var albumKey: String { albumGroupingArtist + "\u{0}" + album }
    var genres: [String] { (genre ?? "").split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
    func matches(_ query: String) -> Bool {
        query.isEmpty || [title, artist, album, albumArtist ?? "", genre ?? "", year ?? ""].joined(separator: " ").localizedCaseInsensitiveContains(query)
    }
    static func albumOrder(_ lhs: Track, _ rhs: Track) -> Bool {
        if (lhs.discNumber ?? 1) != (rhs.discNumber ?? 1) { return (lhs.discNumber ?? 1) < (rhs.discNumber ?? 1) }
        if (lhs.trackNumber ?? Int.max) != (rhs.trackNumber ?? Int.max) { return (lhs.trackNumber ?? Int.max) < (rhs.trackNumber ?? Int.max) }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }

    var url: URL? {
        isImported ? MusicPlayer.documents.appendingPathComponent(filename) : Bundle.main.url(forResource: filename, withExtension: "wav")
    }
    static let empty = Track(id: "", title: "No song selected", artist: "", album: "", style: 0, filename: "")
}

struct Playlist: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var name: String
    var description = ""
    var trackIDs: [String] = []
    var createdAt = Date()
}

struct QueueEntry: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var trackID: String
    var manuallyAdded = false
}

enum RepeatMode: String, Codable, CaseIterable {
    case off, all, one
    var symbol: String { self == .one ? "repeat.1" : "repeat" }
    var label: String {
        switch self { case .off: "Repeat off"; case .all: "Repeat all"; case .one: "Repeat one" }
    }
}

enum TrackSort: String, CaseIterable {
    case title = "Title", artist = "Artist", album = "Album", added = "Recently added"
    func apply(to tracks: [Track]) -> [Track] {
        tracks.sorted { a, b in
            switch self {
            case .title: a.title.localizedStandardCompare(b.title) == .orderedAscending
            case .artist: (a.artist + a.title).localizedStandardCompare(b.artist + b.title) == .orderedAscending
            case .album: a.albumKey == b.albumKey ? Track.albumOrder(a, b) : a.albumKey.localizedStandardCompare(b.albumKey) == .orderedAscending
            case .added: (a.addedAt ?? .distantPast) > (b.addedAt ?? .distantPast)
            }
        }
    }
}

struct LibraryState: Codable {
    var analytics: ListeningAnalytics? = nil
    var importedTracks: [Track] = []
    var favorites: Set<String> = []
    var playlists: [Playlist] = []
    var lyrics: [String: String] = [:]
    var recentIDs: [String] = []
    var currentID = ""
    var elapsed: Double = 0
    var contextIDs: [String] = []
    var contextName = "All music"
    var queue: [QueueEntry] = []
    var shuffle = false
    var repeatMode: RepeatMode = .off
    var rate: Float = 1
    var volume: Float = 1
    var replayGain: ReplayGainMode? = nil
    var gapless: Bool? = nil
}

enum ReplayGainMode: String, Codable, CaseIterable {
    case off = "Off", track = "Track", album = "Album"
    func multiplier(for song: Track, headroomDB: Double = 0) -> Float {
        guard self != .off else { return 1 }
        let db = self == .album ? (song.replayGainAlbumDB ?? song.replayGainTrackDB) : song.replayGainTrackDB
        let peak = self == .album ? (song.replayGainAlbumPeak ?? song.replayGainTrackPeak) : song.replayGainTrackPeak
        guard let db, db.isFinite else { return 1 }
        var gain = pow(10, min(30, max(-60, db - headroomDB)) / 20)
        if let peak, peak.isFinite, peak > 0 { gain = min(gain, 1 / peak) }
        // Shared headroom makes positive and negative tags relative without digital clipping.
        return Float(min(1, max(0, gain)))
    }
}

func formattedTime(_ interval: TimeInterval) -> String {
    guard interval.isFinite else { return "0:00" }
    let seconds = max(0, Int(interval))
    return "\(seconds / 60):" + String(format: "%02d", seconds % 60)
}
