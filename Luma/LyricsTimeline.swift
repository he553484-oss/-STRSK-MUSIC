import Foundation

/// A timestamp supplied by the lyric source for a word or syllable.
struct LyricWord: Equatable {
    let text: String
    let start: TimeInterval
    let end: TimeInterval?
}

/// Lines from the current parser are either all untimed or sorted by media time.
struct LyricsTimeline: Equatable {
    let lines: [LyricLine]

    var isSynchronized: Bool { lines.first?.time != nil }
}

protocol LyricsProvider {
    func timeline(for trackID: String) async throws -> LyricsTimeline?
}

struct StoredLyricsProvider: LyricsProvider {
    let texts: [String: String]

    func timeline(for trackID: String) async -> LyricsTimeline? {
        guard let text = texts[trackID], !text.isEmpty else { return nil }
        return LyricsDocument(text).timeline
    }
}

protocol LyricsSynchronizer {
    func activeLine(in timeline: LyricsTimeline, at mediaTime: TimeInterval) -> Int?
}

struct PlaybackLyricsSynchronizer: LyricsSynchronizer {
    func activeLine(in timeline: LyricsTimeline, at mediaTime: TimeInterval) -> Int? {
        guard timeline.isSynchronized, mediaTime.isFinite else { return nil }
        var lower = timeline.lines.startIndex
        var upper = timeline.lines.endIndex
        while lower < upper {
            let mid = lower + (upper - lower) / 2
            if (timeline.lines[mid].time ?? .infinity) <= mediaTime {
                lower = mid + 1
            } else {
                upper = mid
            }
        }
        return lower > timeline.lines.startIndex ? timeline.lines[lower - 1].id : nil
    }
}
